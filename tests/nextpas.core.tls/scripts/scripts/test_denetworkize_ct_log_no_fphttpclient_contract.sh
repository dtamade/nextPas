#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

target="src/nextpas.core.tls.ct.log.pas"
if [[ ! -f "$target" ]]; then
  echo "[FAIL] missing $target"
  exit 1
fi

patterns=(
  "\\bfphttpclient\\b"
  "\\bTFPHTTPClient\\b"
  "\\bssockets\\b"
  "\\bsslsockets\\b"
  "\\bopensslsockets\\b"
)

for pat in "${patterns[@]}"; do
  if rg -n -S "$pat" "$target" >/dev/null 2>&1; then
    echo "[FAIL] $target must not depend on fphttpclient/ssockets (matched: $pat)"
    rg -n -S "$pat" "$target" || true
    exit 1
  fi
done

echo "[PASS] $target has no fphttpclient/ssockets dependencies"

