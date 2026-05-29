#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

test_file="tests/test_capability_matrix_v12.pas"

require_fixed() {
  local pattern="$1"
  local message="$2"
  if ! rg -F -n --quiet -- "$pattern" "$test_file"; then
    echo "[FAIL] $message" >&2
    exit 1
  fi
}

echo "[TEST] capability matrix v1.2 runtime-truth contract"

require_fixed "procedure RecordProjectionContracts" \
  "Capability matrix regression must keep shared projection contracts"
require_fixed "RecordContract(ABackendName + ' SupportsSNI matches SNISupport'" \
  "Capability matrix regression must assert the SNI support-level projection"
require_fixed "RecordContract(ABackendName + ' SupportsALPN matches ALPNSupport'" \
  "Capability matrix regression must assert the ALPN support-level projection"
require_fixed "RecordContract(ABackendName + ' SupportsOCSPStapling matches OCSPStaplingSupport'" \
  "Capability matrix regression must assert the OCSP support-level projection"
require_fixed "RecordContract(ABackendName + ' SupportsCertificateTransparency matches CertTransparencySupport'" \
  "Capability matrix regression must assert the CT support-level projection"
require_fixed "RecordContract(ABackendName + ' SupportsSessionTickets matches SessionTicketsSupport'" \
  "Capability matrix regression must assert the session-ticket support-level projection"

require_fixed "RecordContract('OpenSSL backend impl is C library'" \
  "Capability matrix regression must lock OpenSSL implementation-type truth"
require_fixed "RecordContract('OpenSSL CT support is unpublished'" \
  "Capability matrix regression must lock OpenSSL CT publication truth"
require_fixed "RecordContract('FreePascal backend impl is native'" \
  "Capability matrix regression must lock FreePascal implementation-type truth"
require_fixed "RecordContract('FreePascal early-data support is experimental'" \
  "Capability matrix regression must lock FreePascal early-data support truth"
require_fixed "RecordContract('FreePascal verify callback is published'" \
  "Capability matrix regression must lock FreePascal callback publication truth"

echo "[PASS] capability matrix v1.2 runtime-truth anchors are present"
