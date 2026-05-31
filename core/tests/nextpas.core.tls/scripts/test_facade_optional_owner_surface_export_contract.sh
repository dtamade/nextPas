#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if grep -Fq -- "$expected" "$file"; then
    pass "$name"
  else
    fail "$name" "expected text not found in $file: $expected"
  fi
}

facade="src/nextpas.core.tls.pas"
api_ref="docs/reference/API_REFERENCE.md"
contract_src="tests/contract/test_facade_optional_owner_surface_entry.pas"
build_root="tmp/test_facade_optional_owner_surface_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_facade_optional_owner_surface_entry"

printf '[TEST] facade optional owner surface export contract\n'

require_fixed "$facade" "ISSLConnectionControl = nextpas.core.tls.base.ISSLConnectionControl;" \
  "main facade re-exports ISSLConnectionControl"
require_fixed "$facade" "ISSLConnectionTextIO = nextpas.core.tls.base.ISSLConnectionTextIO;" \
  "main facade re-exports ISSLConnectionTextIO"
require_fixed "$facade" "TSSLHealthStatus = nextpas.core.tls.base.TSSLHealthStatus;" \
  "main facade re-exports TSSLHealthStatus"
require_fixed "$facade" "TSSLPerformanceMetrics = nextpas.core.tls.base.TSSLPerformanceMetrics;" \
  "main facade re-exports TSSLPerformanceMetrics"
require_fixed "$facade" "TSSLDiagnosticInfo = nextpas.core.tls.base.TSSLDiagnosticInfo;" \
  "main facade re-exports TSSLDiagnosticInfo"
require_fixed "$facade" "TSSLCertificateArray = nextpas.core.tls.base.TSSLCertificateArray;" \
  "main facade re-exports TSSLCertificateArray"
require_fixed "$facade" "ISSLConnectionInfo = nextpas.core.tls.base.ISSLConnectionInfo;" \
  "main facade re-exports ISSLConnectionInfo"
require_fixed "$facade" "ISSLDiagnostics = nextpas.core.tls.base.ISSLDiagnostics;" \
  "main facade re-exports ISSLDiagnostics"
require_fixed "$facade" "ISSLSessionResumption = nextpas.core.tls.base.ISSLSessionResumption;" \
  "main facade re-exports ISSLSessionResumption"
require_fixed "$facade" "ISSLCertificateVerification = nextpas.core.tls.base.ISSLCertificateVerification;" \
  "main facade re-exports ISSLCertificateVerification"
require_fixed "$facade" "ISSLOCSPStapling = nextpas.core.tls.base.ISSLOCSPStapling;" \
  "main facade re-exports ISSLOCSPStapling"
require_fixed "$facade" "ISSLCertificateTransparency = nextpas.core.tls.base.ISSLCertificateTransparency;" \
  "main facade re-exports ISSLCertificateTransparency"
require_fixed "$facade" "ISSLCertificateTransparencyValidation = nextpas.core.tls.base.ISSLCertificateTransparencyValidation;" \
  "main facade re-exports ISSLCertificateTransparencyValidation"
require_fixed "$api_ref" '主门面 `fafafa.ssl` 当前也 re-export `ISSLConnectionControl` / `ISSLConnectionInfo` / `ISSLDiagnostics` 等 connection-side owner interfaces；普通调用方不需要回退 `nextpas.core.tls.base`。' \
  "API reference records main-facade owner-interface re-export truth"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ -x "$binary" ]]; then
  pass "facade-only contract source compiles via uses fafafa.ssl"
else
  fail "facade-only contract source compiles via uses fafafa.ssl" "expected binary missing: $binary"
fi

printf '[PASS] facade optional owner surface export contract passed\n'
