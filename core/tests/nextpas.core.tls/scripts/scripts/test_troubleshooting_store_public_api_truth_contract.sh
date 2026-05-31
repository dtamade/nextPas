#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
source_file="$repo_root/src/nextpas.core.tls.base.pas"
doc_file="$repo_root/docs/guides/TROUBLESHOOTING.md"

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

forbid_fixed "$doc_file" "LStore.Open(SSL_STORE_ROOT);" \
  "Troubleshooting guide must not teach concrete Open(SSL_STORE_ROOT) on ISSLCertificateStore"
forbid_fixed "$doc_file" "SSL_STORE_ROOT" \
  "Troubleshooting guide must not mix WinSSL concrete store constants into the generic public-store snippet"

require_fixed "$doc_file" "if not LStore.LoadSystemStore then" \
  "Troubleshooting guide must use LoadSystemStore for the generic public ISSLCertificateStore flow"
require_fixed "$doc_file" "if not LStore.AddCertificate(LCert) then" \
  "Troubleshooting guide must show AddCertificate on the injected verification store"
require_fixed "$doc_file" "当前进程里注入的验证 store" \
  "Troubleshooting guide must explain that the code path augments the current process verification store"

echo "[PASS] troubleshooting store public API truth contract is satisfied."
