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

require_file() {
  local file="$1"
  local name="$2"
  if [[ -f "$file" ]]; then
    pass "$name"
  else
    fail "$name" "missing file: $file"
  fi
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

require_match() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

require_absent_glob() {
  local pattern="$1"
  local name="$2"
  if rg -n --glob 'src/fafafa.ssl*.pas' --multiline --multiline-dotall "$pattern" src/fafafa.ssl*.pas >/dev/null 2>&1; then
    fail "$name" "unexpected placeholder marker still present in active Pascal sources"
  else
    pass "$name"
  fi
}

printf '[TEST] v1.5.0 static Pascal audit contract\n'

require_file "docs/test_reports/STATIC_AUDIT_V1.5.0.md" "static audit report exists"
require_file "docs/test_reports/RELEASE_READINESS_V1.5.0.md" "release readiness report exists"

read -r source_count compile_count skipped_count <<EOF
$(python3 - <<'PY'
from pathlib import Path
src = Path('src')
all_files = sorted(src.glob('fafafa.ssl*.pas'))
patterns = ('nextpas.core.tls.winssl', 'rand_old.pas', 'nextpas.core.tls.http.simple')
compile_files = [f for f in all_files if not any(p in f.name for p in patterns)]
skipped = [f for f in all_files if any(p in f.name for p in patterns)]
print(len(all_files), len(compile_files), len(skipped))
PY
)
EOF

if [[ "$source_count" == "237" ]]; then
  pass "source inventory contains 237 Pascal units"
else
  fail "source inventory contains 237 Pascal units" \
    "expected 237 src/fafafa.ssl*.pas files, found $source_count"
fi

if [[ "$compile_count" == "225" ]]; then
  pass "Linux compile sieve contains 225 Pascal units"
else
  fail "Linux compile sieve contains 225 Pascal units" \
    "expected 225 Linux-compilable src/fafafa.ssl*.pas files, found $compile_count"
fi

if [[ "$skipped_count" == "12" ]]; then
  pass "Linux compile sieve skip inventory stays at 12 WinSSL-only units"
else
  fail "Linux compile sieve skip inventory stays at 12 WinSSL-only units" \
    "expected 12 intentionally skipped src/fafafa.ssl*.pas files, found $skipped_count"
fi

skeleton_count="$(find tests/winssl -maxdepth 1 -name '*skeleton*.pas' | wc -l | tr -d ' ')"
if [[ "$skeleton_count" == "2" ]]; then
  pass "WinSSL skeleton harness inventory is explicit"
else
  fail "WinSSL skeleton harness inventory is explicit" \
    "expected 2 Windows-only skeleton harnesses, found $skeleton_count"
fi

require_fixed "docs/test_reports/STATIC_AUDIT_V1.5.0.md" 'Status: `PASS`' \
  "static audit report records PASS"
require_fixed "docs/test_reports/STATIC_AUDIT_V1.5.0.md" "237 tracked \`src/*.pas\` files" \
  "static audit report records the current total source inventory"
require_fixed "docs/test_reports/STATIC_AUDIT_V1.5.0.md" "225 core modules" \
  "static audit report records the current Linux compile inventory"
require_fixed "docs/test_reports/STATIC_AUDIT_V1.5.0.md" "src/nextpas.core.tls.context.config.pas" \
  "static audit report records the post-release added Pascal unit"
require_fixed "docs/test_reports/STATIC_AUDIT_V1.5.0.md" "TSSLFactory" \
  "static audit report mentions the public facade"
require_fixed "docs/test_reports/STATIC_AUDIT_V1.5.0.md" "WinSSL skeleton harnesses" \
  "static audit report documents the Windows-only skeleton tests"
require_fixed "docs/test_reports/RELEASE_READINESS_V1.5.0.md" 'Status: `RELEASED`' \
  "release readiness records released status"
require_fixed "docs/test_reports/RELEASE_READINESS_V1.5.0.md" "Static Audit" \
  "release readiness references the static audit"
require_fixed "docs/test_reports/RELEASE_READINESS_V1.5.0.md" 'Release-control status: `RELEASED`.' \
  "release readiness records released control-plane status"

require_fixed "RELEASE_NOTES_V1.5.0.md" "GitHub Actions cross-platform runtime evidence is already green on the current head" \
  "release notes describe the current cross-platform runtime truth"
require_fixed "RELEASE_NOTES_V1.5.0.md" "TSSLHelper class remains available" \
  "release notes clarify TSSLHelper remains public"
require_fixed "RELEASE_NOTES_V1.5.0.md" "GitHub Actions Windows runtime proof is green on the current head" \
  "release notes record the current WinSSL runtime proof"

require_fixed "src/nextpas.core.tls.pas" "TSSLFactory = nextpas.core.tls.factory.TSSLFactory;" \
  "main facade re-exports TSSLFactory"
require_fixed "src/nextpas.core.tls.pas" "TSSLHelper = nextpas.core.tls.factory.TSSLHelper;" \
  "main facade re-exports TSSLHelper"
require_fixed "src/nextpas.core.tls.pas" "ISSLEarlyDataContext = nextpas.core.tls.base.ISSLEarlyDataContext;" \
  "main facade re-exports ISSLEarlyDataContext"
require_fixed "src/nextpas.core.tls.pas" "ISSLServerOCSPStaplingContext = nextpas.core.tls.base.ISSLServerOCSPStaplingContext;" \
  "main facade re-exports ISSLServerOCSPStaplingContext"
require_fixed "src/nextpas.core.tls.factory.pas" "class function CreateContext(" \
  "factory keeps CreateContext"
require_fixed "src/nextpas.core.tls.factory.pas" "class function CreateCertificate(" \
  "factory keeps CreateCertificate"
require_fixed "src/nextpas.core.tls.factory.pas" "class function CreateCertificateStore(" \
  "factory keeps CreateCertificateStore"
require_fixed "src/nextpas.core.tls.factory.pas" "class function CreateServerContext(" \
  "factory keeps CreateServerContext"
require_fixed "src/nextpas.core.tls.factory.pas" "class function GetLibraryInstance(" \
  "factory keeps GetLibraryInstance"
require_fixed "src/nextpas.core.tls.factory.pas" "class function SupportsEarlyDataContext(" \
  "factory keeps early-data helper surface"
require_fixed "src/nextpas.core.tls.factory.pas" "class function SupportsEarlyDataConnection(" \
  "factory keeps early-data connection helper surface"
require_fixed "src/nextpas.core.tls.factory.pas" "class function ConfigureClientEarlyData(" \
  "factory keeps early-data client helper surface"
require_fixed "src/nextpas.core.tls.factory.pas" "class function ConfigureServerEarlyData(" \
  "factory keeps early-data server helper surface"
require_fixed "src/nextpas.core.tls.factory.pas" "class function GetEarlyDataStatus(" \
  "factory keeps early-data status helper surface"
require_fixed "src/nextpas.core.tls.factory.pas" "class function GetEarlyDataLimit(" \
  "factory keeps early-data limit helper surface"

require_fixed "tests/winssl/test_winssl_mtls_skeleton.pas" '{$IFDEF WINDOWS}' \
  "WinSSL mTLS skeleton remains Windows-only"
require_fixed "tests/winssl/test_winssl_mtls_skeleton.pas" "Skip('证书存储访问', '仅 Windows 平台')" \
  "WinSSL mTLS skeleton skips outside Windows"
require_fixed "tests/winssl/test_winssl_ocsp_crl_skeleton.pas" '{$IFDEF WINDOWS}' \
  "WinSSL OCSP/CRL skeleton remains Windows-only"
require_fixed "tests/winssl/test_winssl_ocsp_crl_skeleton.pas" "Skip('OCSP 在线测试', '仅 Windows 平台')" \
  "WinSSL OCSP/CRL skeleton skips outside Windows"

if rg -n --glob 'src/fafafa.ssl*.pas' --multiline --multiline-dotall '\b(TODO|FIXME|skeleton|placeholder)\b' src/fafafa.ssl*.pas >/dev/null; then
  fail "active Pascal sources must not contain placeholder markers" \
    "placeholder marker found in active src/fafafa.ssl*.pas"
else
  pass "active Pascal sources contain no placeholder markers"
fi

printf '[PASS] v1.5.0 static Pascal audit contract passed\n'
