#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

test_file="tests/test_capability_matrix_v12.pas"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local pattern="$1"
  local message="$2"
  if ! rg -F -n --quiet -- "$pattern" "$test_file"; then
    fail "$message"
  fi
}

echo "[TEST] capability matrix v1.2 session/publication hardening contract"

require_fixed "RecordContract('OpenSSL session tickets support is stable'" \
  "Capability matrix regression must lock OpenSSL session-ticket publication truth"
require_fixed "RecordContract(ABackendName + ' session-cache feature matches SessionCacheSupport'" \
  "Capability matrix regression must lock shared session-cache feature/capability parity"
require_fixed "RecordContract(ABackendName + ' session-tickets feature matches SessionTicketsSupport'" \
  "Capability matrix regression must lock shared session-ticket feature/capability parity"
require_fixed "RecordContract('OpenSSL PKCS12 support is published'" \
  "Capability matrix regression must lock OpenSSL PKCS12 publication truth"
require_fixed "RecordContract('OpenSSL custom cipher suites are published'" \
  "Capability matrix regression must lock OpenSSL custom-cipher publication truth"
require_fixed "RecordContract('OpenSSL callbacks are published'" \
  "Capability matrix regression must lock OpenSSL callback publication truth"
require_fixed "RecordContract('FreePascal session cache support is experimental'" \
  "Capability matrix regression must lock FreePascal session-cache support-level truth"
require_fixed "RecordContract('FreePascal 0-RTT support is experimental'" \
  "Capability matrix regression must lock FreePascal 0-RTT support-level truth"
require_fixed "WriteLn('  SessionCacheSupport: ', Ord(Caps.SessionCacheSupport));" \
  "Capability matrix diagnostics must keep printing SessionCacheSupport"
require_fixed "WriteLn('  ZeroRTTSupport: ', Ord(Caps.ZeroRTTSupport));" \
  "Capability matrix diagnostics must keep printing ZeroRTTSupport"
require_fixed "WriteLn('  EarlyDataSupport: ', Ord(Caps.EarlyDataSupport));" \
  "Capability matrix diagnostics must keep printing EarlyDataSupport"

echo "[PASS] capability matrix v1.2 session/publication hardening anchors present"
