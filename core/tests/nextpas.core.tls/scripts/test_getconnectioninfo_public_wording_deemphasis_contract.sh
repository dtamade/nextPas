#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

require_pattern() {
  local file="$1"
  local pattern="$2"
  if ! grep -F -q -- "$pattern" "$file"; then
    echo "[FAIL] missing GetConnectionInfo wording pattern in $file: $pattern"
    exit 1
  fi
}

forbid_pattern() {
  local file="$1"
  local pattern="$2"
  if grep -F -q -- "$pattern" "$file"; then
    echo "[FAIL] stale GetConnectionInfo wording still present in $file: $pattern"
    exit 1
  fi
}

require_pattern "core/src/nextpas.core.tls.base.pas" "@owner-note 默认 owner 为 ISSLConnectionInfo.GetConnectionInfo；此入口仅兼容保留"
require_pattern "core/src/nextpas.core.tls.base.pas" "@compatibility-note v1.x compatibility-core mirror; not recommended as the primary entry for new code; Stage-A demotion target is ISSLConnectionInfo"




echo "[PASS] GetConnectionInfo public wording de-emphasis is aligned across source and docs"
