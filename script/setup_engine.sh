#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
export UV_CACHE_DIR="$ROOT_DIR/.cache/uv"
uv venv --python 3.12 .runtime
uv pip sync --python .runtime/bin/python engine/requirements.lock
echo "Inspection engine is ready. Run ./script/build_and_run.sh"
