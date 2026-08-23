#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
source_file="$repo_root/core/src/nextpas.core.tls.base.pas"

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if ! grep -F -q "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

forbid_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -F -q "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed "$source_file" "function LoadSystemStore: Boolean;" \
  "ISSLCertificateStore must continue exposing LoadSystemStore in the public interface"



echo "[PASS] troubleshooting store public API truth contract is satisfied."
