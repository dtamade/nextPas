#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
best_practices="$repo_root/docs/guides/WINSSL_BEST_PRACTICES.md"
winssl_matrix="${WINSSL_MATRIX_DOC:-$repo_root/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md}"
store_guide="$repo_root/docs/guides/STORE_USAGE_GUIDE.md"

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

require_fixed "$store_guide" "LStore := OpenSystemStore(SSL_STORE_MY);" \
  "Store usage guide must keep the WinSSL helper example for opening a named Windows system store"

forbid_fixed "$best_practices" "LStore.Open(SSL_STORE_MY);" \
  "WinSSL best practices must not call concrete Open(...) on an ISSLCertificateStore variable"
require_fixed "$best_practices" "LStore := OpenSystemStore(SSL_STORE_MY);" \
  "WinSSL best practices must use OpenSystemStore(...) for the Windows certificate store helper path"

forbid_fixed "$winssl_matrix" "TWinSSLCertStore.Open('MY')" \
  "WinSSL backend matrix must not reference the nonexistent TWinSSLCertStore class"
forbid_fixed "$winssl_matrix" "Store.Certificates" \
  "WinSSL backend matrix must not teach a non-public Certificates property on ISSLCertificateStore"
forbid_fixed "$winssl_matrix" "Cert.Subject" \
  "WinSSL backend matrix must not teach property-style Subject access on ISSLCertificate"
forbid_fixed "$winssl_matrix" "uses nextpas.core.tls.base;" \
  "WinSSL backend matrix must stop teaching nextpas.core.tls.base in the active backend identifier example"
forbid_fixed "$winssl_matrix" "  nextpas.core.tls.base," \
  "WinSSL backend matrix must stop teaching nextpas.core.tls.base in the active certificate-store example"

require_fixed "$winssl_matrix" "Store := OpenSystemStore(SSL_STORE_MY);" \
  "WinSSL backend matrix must use the shipped OpenSystemStore(...) helper"
require_fixed "$winssl_matrix" "for I := 0 to Store.GetCount - 1 do" \
  "WinSSL backend matrix must enumerate certificates through the public GetCount API"
require_fixed "$winssl_matrix" "Cert := Store.GetCertificate(I);" \
  "WinSSL backend matrix must enumerate certificates through the public GetCertificate API"
require_fixed "$winssl_matrix" "WriteLn(Cert.GetSubject);" \
  "WinSSL backend matrix must read certificate subjects through GetSubject"
require_fixed "$winssl_matrix" "  nextpas.core.tls.context.builder;" \
  "WinSSL backend matrix must import the current builder entry when using TSSLContextBuilder"
require_fixed "$winssl_matrix" "  fafafa.ssl," \
  "WinSSL backend matrix must use the current public facade unit in the active certificate-store example"

echo "[PASS] WinSSL store active docs truth contract is satisfied."
