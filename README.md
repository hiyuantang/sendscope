# SendScope for macOS

A SwiftUI utility for actively inspecting outgoing HTTP and HTTPS requests from selected processes. It shows destinations, request-body sizes, HTTP results, and filenames reported in multipart uploads. Inspection runs locally through mitmproxy 12.2.3.

## Run

Requires macOS 14+, Xcode or its Swift toolchain, and `uv` for engine installation.

```sh
git clone https://github.com/hiyuantang/sendscope.git
cd sendscope
./script/setup_engine.sh
./script/build_and_run.sh
```

The Codex Run action uses the same build script. The script stages `dist/SendScope.app` with the generated icon. This development bundle references the project-local `.runtime` environment; it is not a standalone signed/notarized distribution. Keep the project in place when running it. No login item is installed.

## Start inspecting

1. Open **HTTPS setup**. Generate a unique local certificate.
2. Open that certificate in Keychain Access, add it to the login keychain, and enable SSL trust in its Trust section. Its certificate name is `mitmproxy`; compare the SHA-256 fingerprint shown in SendScope. Trust is a deliberate user action; SendScope never installs trust silently.
3. Check trust, select a running process (or enter a process name), and choose **Inspect**. Approve the official mitmproxy capture extension if macOS requests it. A selected PID covers that process, not every helper in an application bundle. Restart connections if necessary.
4. Choose a request for its evidence details. **Stop** terminates the engine.

**Manual proxy** mode listens only on `127.0.0.1:8877`. Configure a compatible client to use that HTTP/HTTPS proxy. SendScope does not change system proxy settings. CLI clients can trust only this connection by passing the certificate via `--cacert`, without modifying system trust.

## What the evidence means

- **Outgoing data** counts request-body bytes observed by the inspector, not total wire bytes or confirmed server storage.
- **Reported filenames** come from multipart headers in the first 16 KB of a request. They are app-provided names, not verified local paths. At most eight names are shown; later multipart parts may be missed.
- **HTTP response** means a response was received. It does not establish that the server retained a file.
- App-encrypted archives remain opaque after HTTPS inspection. Certificate pinning can prevent inspection entirely.
- This version does not correlate local file access, block transfers, decrypt arbitrary protocols, or attribute WebSocket payloads. Unselected processes and traffic bypassing the inspector are outside coverage. The UI displays coverage warnings when capture metadata is dropped.
- The process label records the user's capture selection. Manual proxy traffic does not claim verified app attribution.

## Energy and privacy

- The inspector process exists only while inspection or certificate generation is active. It exits on Stop or app quit, with a parent watchdog for unexpected GUI termination.
- Request and response bodies stream through without full buffering. Only a 16 KB multipart prefix is temporarily retained per tracked request. A maximum of 256 concurrent requests is tracked; excess traffic is forwarded without metadata and a coverage warning is emitted.
- The GUI batches updates once per second during inspection, with a bounded event queue and up to 500 retained requests. No activity timer runs while stopped.
- Serious or critical thermal pressure stops inspection. Low Power Mode pauses inspection by default. These conditions also prevent starting an ordinary inspection session.
- Request bodies, full URLs, cookies, and authorization headers are never written to SendScope's activity history. Traffic is not sent to an analytics service. Temporary in-memory processing is required to inspect HTTPS.
- History is off by default. Enabling it saves bounded metadata on stop/quit in `~/Library/Application Support/SendScope/history.json` with owner-only permissions. Hostnames and reported filenames can themselves be sensitive.
- The inspection CA private key is held in `~/Library/Application Support/SendScope/certificates/`. Protect it. To remove SendScope fully, stop it, remove its exact certificate from Keychain Access using the recorded fingerprint, and remove the app and its support directory. Do not remove other tools' certificates just because they also use the name `mitmproxy`.

## Validation

```sh
swift test
PYTHONPATH=engine .runtime/bin/python -m unittest discover -s engine/tests -v
.runtime/bin/python script/integration_test.py
```

The integration test uses a loopback HTTPS server, a test-only CA, and per-command client trust. It verifies multipart filename detection, a 64 MiB transfer's byte count and SHA-256 at the receiver, omission of secret sentinels, and a short idle engine resource sample. It does not install system trust or change proxy settings.

See `docs/validation.md` for measured results and remaining validation limits.

## Layout

`Sources/SendScope` contains the SwiftUI app, service lifecycle, and bounded event reader. `Sources/SendScopeCore` contains the request model and validation rules. `engine/sendscope_addon.py` is the streaming observer. `engine/requirements.lock` pins the local engine dependencies. `assets/SendScope.png` is the generated master icon, `assets/SendScope.icns` is the packaged icon, and `assets/icon-prompt.txt` records the built-in image-generation prompts.

## Technical references

- [mitmproxy local capture](https://docs.mitmproxy.org/stable/concepts/modes/#local-capture)
- [Certificate trust and pinning](https://docs.mitmproxy.org/stable/concepts/certificates/)
- [Streaming addon examples](https://docs.mitmproxy.org/stable/addons/examples/)

## License

SendScope is released under the [MIT License](LICENSE). Third-party dependencies retain their own licenses; see [THIRD_PARTY.md](THIRD_PARTY.md).
