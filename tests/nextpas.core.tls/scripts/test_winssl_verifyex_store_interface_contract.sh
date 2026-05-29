#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

source_file="tests/winssl/test_winssl_cert_verify_ex.pas"

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

require_line() {
  local pattern="$1"
  local label="$2"
  if rg -n --fixed-strings "$pattern" "$source_file" >/dev/null; then
    pass "$label"
  else
    fail "$label" "pattern not found in $source_file: $pattern"
  fi
}

require_absent() {
  local pattern="$1"
  local label="$2"
  if rg -n --fixed-strings "$pattern" "$source_file" >/dev/null; then
    fail "$label" "unexpected pattern still present in $source_file: $pattern"
  else
    pass "$label"
  fi
}

printf '[TEST] WinSSL VerifyEx store interface contract\n'

require_line 'function CreateMemoryBackedStore: ISSLCertificateStore;' \
  'factory helper returns ISSLCertificateStore'
require_line '  AStore: ISSLCertificateStore;' \
  'VerifyEx trace helper accepts ISSLCertificateStore'
require_line '  LStore: ISSLCertificateStore;' \
  'reused LStore variables stay interface-held'
require_line '  LEmptyStore: ISSLCertificateStore;' \
  'empty store variable stays interface-held'

require_absent 'function CreateMemoryBackedStore: TWinSSLCertificateStore;' \
  'factory helper does not regress to concrete store return type'
require_absent '  LStore: TWinSSLCertificateStore;' \
  'reused LStore variables do not regress to concrete store ownership'
require_absent '  LEmptyStore: TWinSSLCertificateStore;' \
  'empty store variable does not regress to concrete store ownership'

printf '[PASS] WinSSL VerifyEx store interface contract passed\n'
