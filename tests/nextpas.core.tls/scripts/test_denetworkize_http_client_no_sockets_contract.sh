#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

target="src/nextpas.core.tls.http.client.pas"
if [[ ! -f "$target" ]]; then
  echo "[FAIL] missing $target"
  exit 1
fi

patterns=(
  "\\bSockets\\b"
  "\\bfpSocket\\b"
  "\\bfpConnect\\b"
  "\\bfpRecv\\b"
  "\\bfpSend\\b"
  "\\bCloseSocket\\b"
  "\\bStrToNetAddr\\b"
  "\\bTInetSockAddr\\b"
)

for pat in "${patterns[@]}"; do
  if rg -n -S "$pat" "$target" >/dev/null 2>&1; then
    echo "[FAIL] $target must not depend on sockets/network primitives (matched: $pat)"
    rg -n -S "$pat" "$target" || true
    exit 1
  fi
done

echo "[PASS] $target has no sockets/network primitives"

