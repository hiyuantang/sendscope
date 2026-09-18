"""Loopback-only HTTPS upload test; does not alter system trust or proxy settings."""
import hashlib
import http.server
import ipaddress
import json
import os
from pathlib import Path
import queue
import socket
import ssl
import subprocess
import threading
import time
from datetime import datetime, timedelta, timezone

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID

ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / "work" / "integration"
WORK.mkdir(parents=True, exist_ok=True)
os.chmod(WORK, 0o700)


def free_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, "SendScope local test")])
cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key())
        .serial_number(x509.random_serial_number()).not_valid_before(datetime.now(timezone.utc) - timedelta(minutes=1))
        .not_valid_after(datetime.now(timezone.utc) + timedelta(days=1))
        .add_extension(x509.SubjectAlternativeName([x509.DNSName("localhost"), x509.IPAddress(ipaddress.ip_address("127.0.0.1"))]), False)
        .add_extension(x509.BasicConstraints(ca=True, path_length=None), True)
        .sign(key, hashes.SHA256()))
(WORK / "server.pem").write_bytes(cert.public_bytes(serialization.Encoding.PEM))
(WORK / "server.key").write_bytes(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
os.chmod(WORK / "server.key", 0o600)
received = []


class Receiver(http.server.BaseHTTPRequestHandler):
    def log_message(self, *_): pass
    def do_POST(self):
        remaining = int(self.headers.get("Content-Length", "0"))
        count = 0
        digest = hashlib.sha256()
        while remaining:
            chunk = self.rfile.read(min(65536, remaining))
            if not chunk: break
            digest.update(chunk); remaining -= len(chunk); count += len(chunk)
        received.append({"bytes": count, "sha256": digest.hexdigest()})
        body = b'{"received":true}'
        self.send_response(200)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers(); self.wfile.write(body)


server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Receiver)
tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
tls.load_cert_chain(WORK / "server.pem", WORK / "server.key")
server.socket = tls.wrap_socket(server.socket, server_side=True)
threading.Thread(target=server.serve_forever, daemon=True).start()
port = free_port()
conf = WORK / "certificates"
env = {k: v for k, v in os.environ.items() if k.lower() not in ["http_proxy", "https_proxy", "all_proxy", "no_proxy"]}
env["PYTHONUNBUFFERED"] = "1"
events = []
ready = threading.Event()
errors = []
command = [str(ROOT / ".runtime/bin/mitmdump"), "--mode", f"regular@127.0.0.1:{port}",
           "--set", f"confdir={conf}", "--set", f"ssl_verify_upstream_trusted_ca={WORK / 'server.pem'}",
           "--set", "flow_detail=0", "--set", "connection_strategy=lazy",
           "-s", str(ROOT / "engine/sendscope_addon.py"), "-q"]
process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, env=env)


def read_events():
    for line in process.stdout:
        if line.startswith("SENDSCOPE "):
            event = json.loads(line[10:])
            events.append(event)
            if event["kind"] == "ready": ready.set()


def read_errors():
    for line in process.stderr:
        errors.append(line[:300])


threading.Thread(target=read_events, daemon=True).start()
threading.Thread(target=read_errors, daemon=True).start()


def cpu_rss(pid):
    result = subprocess.check_output(["/bin/ps", "-p", str(pid), "-o", "time=,rss="], text=True).split()
    parts = result[0].split(":")
    seconds = float(parts[-1]) + int(parts[-2]) * 60
    if len(parts) == 3: seconds += int(parts[0]) * 3600
    return seconds, int(result[1])


try:
    assert ready.wait(20), f"Engine startup failed: {''.join(errors)}"
    start_cpu, start_rss = cpu_rss(process.pid)
    idle_start = time.monotonic()
    time.sleep(20)
    idle_seconds = time.monotonic() - idle_start
    end_cpu, end_rss = cpu_rss(process.pid)

    fixture = WORK / "sample-upload.txt"
    fixture.write_bytes(b"SENDSCOPE_TEST_PAYLOAD_NOT_TO_BE_LOGGED\n" * 128)
    url = f"https://localhost:{server.server_port}/private-path?token=DO_NOT_STORE"
    common = ["/usr/bin/curl", "--silent", "--show-error", "--fail", "--max-time", "30", "--noproxy", "",
              "--proxy", f"http://127.0.0.1:{port}", "--cacert", str(conf / "mitmproxy-ca-cert.pem"),
              "-H", "Authorization: Bearer DO_NOT_STORE"]
    subprocess.run(common + ["-F", f"file=@{fixture}", url], env=env, check=True, capture_output=True)
    deadline = time.monotonic() + 3
    while not any(e.get("statusCode") == 200 for e in events) and time.monotonic() < deadline: time.sleep(0.05)
    first = [e for e in events if e.get("statusCode") == 200][-1]
    assert first["files"] == [fixture.name], first
    assert first["tls"] is True
    assert first["bytes"] == received[0]["bytes"]

    large = WORK / "archive.tar.gz.enc"
    chunk = b"x" * (1024 * 1024)
    source_hash = hashlib.sha256()
    with large.open("wb") as f:
        for _ in range(64): f.write(chunk); source_hash.update(chunk)
    transfer_start = time.monotonic()
    subprocess.run(common + ["-H", "Content-Type: application/octet-stream", "--data-binary", f"@{large}", url], env=env, check=True, capture_output=True)
    transfer_seconds = time.monotonic() - transfer_start
    time.sleep(0.3)
    last = [e for e in events if e.get("statusCode") == 200][-1]
    assert last["bytes"] == 64 * 1024 * 1024, last
    assert last["files"] == [], "Raw encrypted archive must not claim a filename or source folder"
    assert received[-1]["sha256"] == source_hash.hexdigest(), "Proxy modified transmitted bytes"
    _, final_rss = cpu_rss(process.pid)
    serialized = json.dumps(events)
    assert "DO_NOT_STORE" not in serialized
    assert "SENDSCOPE_TEST_PAYLOAD_NOT_TO_BE_LOGGED" not in serialized
    assert "private-path" not in serialized
    result = {
        "result": "passed", "https_decryption": True,
        "multipart_filename_identified": first["files"], "byte_counts_match_receiver": True,
        "large_upload_bytes": last["bytes"], "large_upload_sha256_matches": True,
        "sensitive_fields_absent": True, "system_trust_modified": False,
        "idle_sample_seconds": round(idle_seconds, 2),
        "engine_idle_cpu_percent_one_core": round((end_cpu - start_cpu) / idle_seconds * 100, 3),
        "engine_idle_rss_mib": round(end_rss / 1024, 1),
        "engine_after_64mib_rss_mib": round(final_rss / 1024, 1),
        "local_64mib_transfer_seconds": round(transfer_seconds, 2),
        "limits": "Short loopback smoke measurement, not battery-life or temperature validation. Proxy mode tested; selected-process system extension needs user approval."
    }
    (WORK / "result.json").write_text(json.dumps(result, indent=2) + "\n")
    print(json.dumps(result, indent=2))
finally:
    process.terminate()
    try: process.wait(timeout=5)
    except subprocess.TimeoutExpired: process.kill(); process.wait()
    server.shutdown(); server.server_close()
