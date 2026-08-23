#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

require_file() {
  local file="$1"
  local message="$2"
  if [[ ! -f "$file" ]]; then
    echo "[FAIL] $message"
    echo "  missing: $file"
    exit 1
  fi
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local message="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "[FAIL] $message"
    echo "  file: $file"
    echo "  expected: $expected"
    exit 1
  fi
}


if grep -Fq -- "不代表默认路径已经持久化" "README.md"; then
  echo "[FAIL] README.md must stop contradicting the durable default replay-store truth"
  exit 1
fi







require_fixed "core/src/nextpas.core.tls.freepascal.context.pas" \
  "TFreePascalDefaultPersistentEarlyDataReplayLedger.Create(" \
  "FreePascal server context must still default to the persistent replay ledger"
require_fixed "core/src/nextpas.core.tls.freepascal.lib.pas" \
  "a local persistent anti-replay replay-store path" \
  "FreePascal capability KnownIssues must keep the durable default replay-store wording"

echo "[PASS] FreePascal early-data public opt-in docs contract passed"
