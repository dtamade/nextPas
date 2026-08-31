#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
winssl_context="$repo_root/core/src/nextpas.core.tls.winssl.context.pas"

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

require_fixed "$winssl_context" "LoadCAPath is not supported on Windows." \
  "WinSSL runtime must keep the explicit CAPath unsupported exception text"







echo "[PASS] WinSSL CAPath unsupported active docs truth contract is satisfied."
