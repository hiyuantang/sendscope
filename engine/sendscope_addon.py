"""Streaming HTTPS metadata observer. Never emits bodies, URLs, cookies or tokens."""
import asyncio
import json
import os
import re
import time
from collections import OrderedDict
from urllib.parse import unquote

from mitmproxy import ctx, http

PREFIX_LIMIT = 16 * 1024
MAX_ACTIVE = 256
MAX_FILES = 8
MARKER = "SENDSCOPE "


def reported_filenames(prefix: bytes, content_type: str) -> list[str]:
    # Only multipart part headers carry meaningful upload filename metadata.
    # This intentionally scans a bounded prefix, not arbitrarily large file bodies.
    if not content_type.lower().startswith("multipart/form-data"):
        return []
    text = prefix.decode("latin-1", errors="replace")
    names = []
    for line in text.split("\r\n"):
        if not line.lower().startswith("content-disposition:"):
            continue
        match = re.search(r'(?:^|;)\s*filename\*?=(?:"([^"\r\n]{1,512})"|([^;\r\n]{1,512}))', line, re.I)
        if match:
            raw = match.group(1) or match.group(2).strip()
            if raw.lower().startswith("utf-8''"):
                raw = unquote(raw[7:])
            name = raw.replace("\\", "/").split("/")[-1]
            name = "".join(c for c in name if c.isprintable())[:160]
            if name and name not in names:
                names.append(name)
    return names[:MAX_FILES]


class SendScope:
    def __init__(self):
        self.active = OrderedDict()
        self.parent = os.getppid()
        self.watchdog = None

    def emit(self, event):
        print(MARKER + json.dumps(event, ensure_ascii=True), flush=True)

    def running(self):
        self.emit({"kind": "ready"})
        self.watchdog = asyncio.create_task(self.watch_parent())

    async def watch_parent(self):
        # Prevent an orphan inspector if the GUI crashes or is force-quit.
        while True:
            await asyncio.sleep(2)
            if os.getppid() != self.parent:
                ctx.master.shutdown()
                return

    def done(self):
        if self.watchdog:
            self.watchdog.cancel()

    def requestheaders(self, flow: http.HTTPFlow):
        if len(self.active) >= MAX_ACTIVE:
            # Never interrupt traffic because our metadata budget is exhausted.
            flow.request.stream = True
            self.emit({"kind": "coverage", "message": "Concurrent request limit reached; some requests were not recorded."})
            return
        mime = flow.request.headers.get("content-type", "").split(";", 1)[0].strip()[:100]
        state = {
            "kind": "flow", "id": flow.id, "started": time.time(),
            "host": flow.request.host[:253], "method": flow.request.method[:16],
            "scheme": flow.request.scheme, "contentType": mime,
            "bytes": 0, "responseBytes": 0, "status": "Inspecting",
            "files": [], "tls": flow.request.scheme == "https",
            "_prefix": bytearray(), "_last": 0.0,
        }
        self.active[flow.id] = state

        def stream(chunk):
            state["bytes"] += len(chunk)
            if mime == "multipart/form-data" and len(state["_prefix"]) < PREFIX_LIMIT:
                state["_prefix"].extend(chunk[:PREFIX_LIMIT - len(state["_prefix"])])
            now = time.monotonic()
            if now - state["_last"] >= 1 or not chunk:
                state["files"] = reported_filenames(bytes(state["_prefix"]), mime)
                self.publish(state)
            return chunk

        flow.request.stream = stream
        self.publish(state)

    def publish(self, state):
        state["_last"] = time.monotonic()
        self.emit({k: v for k, v in state.items() if not k.startswith("_")})

    def request(self, flow: http.HTTPFlow):
        state = self.active.get(flow.id)
        if state:
            state["status"] = "Awaiting response"
            self.publish(state)
            state["_prefix"].clear()

    def responseheaders(self, flow: http.HTTPFlow):
        state = self.active.get(flow.id)
        def stream(chunk):
            if state:
                state["responseBytes"] += len(chunk)
            return chunk
        flow.response.stream = stream

    def response(self, flow: http.HTTPFlow):
        state = self.active.pop(flow.id, None)
        if state:
            state["status"] = "Response received"
            state["statusCode"] = flow.response.status_code
            self.publish(state)

    def error(self, flow: http.HTTPFlow):
        state = self.active.pop(flow.id, None)
        if state:
            state["status"] = "Connection failed"
            self.publish(state)

    def tls_failed_client(self, data):
        # No raw error string: it can include private endpoints or request data.
        self.emit({"kind": "coverage", "message": "An app rejected HTTPS inspection. Check certificate trust; certificate pinning may prevent inspection."})

    def websocket_message(self, flow):
        # WebSockets aren't file-upload-attributed in this MVP. Clear retained
        # messages so long-running sockets cannot build an unbounded capture.
        if flow.websocket:
            flow.websocket.messages.clear()


addons = [SendScope()]
