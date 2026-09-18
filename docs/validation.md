# Validation record

Date: September 18, 2026. Local Apple Silicon Mac; Swift 6.4 toolchain. Development build, not a production certification.

## Automated results

- Swift app compilation and `.app` launch: passed.
- Swift unit tests: 2 passed. Capture-target validation rejects empty targets and selector operators that could expand capture; the retained-request ledger updates without double counting and evicts at its bound.
- Python observer tests: 4 passed. Streamed bytes remain unchanged, multipart names are reduced to basenames, secrets and full paths do not enter events, and the active-request budget forwards traffic when full.
- Real HTTPS loopback integration: passed. The observer identified `sample-upload.txt` from multipart headers. Observed byte counts matched the receiver.
- A 64 MiB raw request passed through without body retention or a claimed filename. Its receiver SHA-256 matched the source exactly.
- Authorization, query-token, path, and body sentinels were absent from emitted activity records.
- No system certificate trust or system proxy setting was changed by the integration test.

## Initial engine resource sample

The regular-proxy engine averaged approximately **0.35% of one CPU core over a 20-second idle sample**. Resident memory at the end of that sample was about **100.3 MiB**. Resident memory after the 64 MiB streaming upload was about **73.6 MiB**; Python allocation and garbage collection mean these are snapshots, not peak-memory measurements. The loopback transfer took about 0.68 seconds.

These measurements do not establish battery consumption, temperature stability, sustained-transfer CPU cost, or selected-process capture-extension overhead. Real internet traffic, parallel requests, and TLS handshakes can increase CPU use. A longer test on battery with a representative workload is still required before making a battery-life claim.

Raw test results are stored locally in `work/integration/result.json` (ignored by Git).

## Coverage still requiring user setup

The selected-process mode uses mitmproxy's official macOS capture extension. First use may require macOS approval and certificate trust. The HTTPS integration validates regular proxy mode; it does not certify system-extension installation, certificate-pinned applications, or every application's helper-process behavior. The app should be left stopped until the user chooses a capture target and finishes setup.

## Window layout verification

The rebuilt app was visually checked at approximately 1160 × 768 and 985 × 703 with the request inspector open and closed. A compact unified toolbar with its background hidden removes the offset titlebar/sidebar junction. At narrower widths, capture controls wrap to two rows, metrics use compact labels, and the empty-state decoration yields space to the setup button. The process-name field and setup action remained visible in the compact inspector layout. Inspection was left off.
