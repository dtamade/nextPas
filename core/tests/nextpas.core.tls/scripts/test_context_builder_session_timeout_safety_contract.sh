#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

builder="core/src/nextpas.core.tls.context.builder.pas"

printf '[TEST] context builder session-timeout safety contract\n'

require_fixed "$builder" "function WithSessionTimeout(ASeconds: Integer): ISSLContextBuilder; overload;" \
  "context builder must keep legacy integer session-timeout overload"
require_fixed "$builder" "function WithSessionTimeout(const ATimeout: TTimeoutDuration): ISSLContextBuilder; overload;" \
  "context builder must export TTimeoutDuration session-timeout overload"
require_fixed "$builder" "Infinite timeout is not valid for session lifetime" \
  "context builder must reject infinite timeout for session lifetime"
require_fixed "$builder" "Session timeout must be a whole number of seconds" \
  "context builder must reject non-whole-second timeout values"


printf '[PASS] context builder session-timeout safety contract passed\n'
