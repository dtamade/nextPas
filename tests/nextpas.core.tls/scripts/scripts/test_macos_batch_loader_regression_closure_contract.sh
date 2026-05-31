#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

pass() {
  echo "[PASS] $1"
}

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_match() {
  local pattern="$1"
  local file="$2"
  local message="$3"
  if rg -n -U -P "$pattern" "$file" >/dev/null; then
    pass "$message"
  else
    fail "$message ($file)"
  fi
}

require_literal() {
  local needle="$1"
  local file="$2"
  local message="$3"
  if rg -n -F "$needle" "$file" >/dev/null; then
    pass "$message"
  else
    fail "$message ($file)"
  fi
}

require_match 'var\s+EVP_BINDINGS:\s+array\[0\.\.98\]\s+of\s+TFunctionBinding\s*=\s*\(' \
  src/nextpas.core.tls.openssl.api.evp.pas \
  'EVP batch bindings use runtime storage'

require_match 'var\s+PEM_FUNCTION_BINDINGS:\s+array\[0\.\.61\]\s+of\s+TFunctionBinding\s*=\s*\(' \
  src/nextpas.core.tls.openssl.api.pem.pas \
  'PEM batch bindings use runtime storage'

require_match 'var\s+PKCS12_BINDINGS:\s+array\[0\.\.47\]\s+of\s+TFunctionBinding\s*=\s*\(' \
  src/nextpas.core.tls.openssl.api.pkcs12.pas \
  'PKCS12 batch bindings use runtime storage'

require_match 'var\s+CMS_FUNCTION_BINDINGS:\s+array\[0\.\.88\]\s+of\s+TFunctionBinding\s*=\s*\(' \
  src/nextpas.core.tls.openssl.api.cms.pas \
  'CMS batch bindings use runtime storage'

require_match 'var\s+OCSPBindings:\s+array\[0\.\.83\]\s+of\s+TFunctionBinding\s*=\s*\(' \
  src/nextpas.core.tls.openssl.api.ocsp.pas \
  'OCSP batch bindings use runtime storage'

require_match 'SetModuleLoaded\(osmPEM,\s*Assigned\(PEM_read_bio_X509\)\s*and\s*Assigned\(PEM_read_bio_PrivateKey\)\s*\);' \
  src/nextpas.core.tls.openssl.api.pem.pas \
  'PEM loaded state follows the read surface that certificate/key helpers actually use'

require_literal 'class function GetLastLoadFunctionsLoadedCount: Integer;' \
  src/nextpas.core.tls.openssl.loader.pas \
  'Loader exposes last batch-load hit count'

require_literal 'class function GetLastLoadFunctionsMissingRequired: string;' \
  src/nextpas.core.tls.openssl.loader.pas \
  'Loader exposes last missing required-binding list'

require_literal 'load_functions_loaded_count' \
  tests/diagnostic/test_macos_openssl_loader_symbol_probe.pas \
  'macOS loader probe records per-module batch-load counts'

require_literal 'missing_required_bindings' \
  tests/diagnostic/test_macos_openssl_loader_symbol_probe.pas \
  'macOS loader probe records per-module missing required bindings'

require_literal 'EVP_CIPHER_CTX_new' \
  tests/diagnostic/test_macos_openssl_loader_symbol_probe.pas \
  'macOS loader probe records EVP cipher-context direct symbol truth'

require_literal 'PEM_write_bio_X509' \
  tests/diagnostic/test_macos_openssl_loader_symbol_probe.pas \
  'macOS loader probe records PEM write-symbol truth'

require_literal 'PKCS12_parse' \
  tests/diagnostic/test_macos_openssl_loader_symbol_probe.pas \
  'macOS loader probe records PKCS12 parse direct symbol truth'
