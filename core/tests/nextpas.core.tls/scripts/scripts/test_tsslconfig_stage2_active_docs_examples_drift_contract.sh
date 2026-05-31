#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

integration="docs/INTEGRATION_GUIDE.md"
getting_started="docs/guides/GETTING_STARTED.md"
factory_example="examples/example_factory_usage.pas"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    echo "  file: $file"
    echo "  expected: $needle"
    exit 1
  fi
}

reject_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    rg -F -n -- "$needle" "$file" || true
    exit 1
  fi
}

# INTEGRATION_GUIDE: replay-store example must prefer TSSLContextConfig or label TSSLConfig as legacy
require_fixed 'TSSLContextConfig' "$integration" \
  "INTEGRATION_GUIDE must mention TSSLContextConfig as the preferred replay-store config path"
require_fixed 'v1.x' "$integration" \
  "INTEGRATION_GUIDE must label TSSLConfig replay-store example as v1.x compatibility"

# GETTING_STARTED: TSSLConfig alternative must be labeled as legacy/compatibility
require_fixed 'v1.x 兼容' "$getting_started" \
  "GETTING_STARTED must label the TSSLConfig factory alternative as v1.x compatibility"
reject_fixed '如果你不用 builder，而是走' "$getting_started" \
  "GETTING_STARTED must not present TSSLConfig as an unlabeled alternative without compatibility note"

# example_factory_usage: DemoConfiguration must note builder is preferred for new code
require_fixed '推荐' "$factory_example" \
  "example_factory_usage DemoConfiguration must note that builder is the preferred path for new code"
require_fixed 'v1.x' "$factory_example" \
  "example_factory_usage DemoConfiguration must label TSSLConfig usage as v1.x compatibility"

echo "[PASS] Stage 2 active docs/examples no longer teach TSSLConfig as recommended new path"
