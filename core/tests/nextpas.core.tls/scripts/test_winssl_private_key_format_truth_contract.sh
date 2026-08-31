#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_pcre() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! python3 - "$file" "$pattern" <<'PY' >/dev/null; then
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pattern = sys.argv[2]
sys.exit(0 if re.search(pattern, text, re.S) else 1)
PY
    fail "$message"
  fi
}

winssl_lib="core/src/nextpas.core.tls.winssl.lib.pas"
winssl_ctx="core/src/nextpas.core.tls.winssl.context.pas"

echo "[TEST] WinSSL private-key format truth contract"

require_fixed "$winssl_lib" "Result.SupportsDERPrivateKey := False;" \
  "WinSSL must not publish bare DER private-key loading as supported"
require_fixed "$winssl_lib" "Result.SupportsPKCS8PrivateKey := False;" \
  "WinSSL must not publish bare PKCS#8 private-key loading as supported"
require_fixed "$winssl_lib" "Result.SupportsPKCS12 := True;" \
  "WinSSL must keep published PKCS#12/PFX private-key support"
require_absent "$winssl_lib" "或先转换为 DER 格式" \
  "WinSSL source comments must stop implying direct DER private-key loading is published"

require_pcre "$winssl_ctx" "procedure TWinSSLContext\\.LoadPrivateKey\\(AStream: IStream; const APassword: string\\);.*?if AStream = nil then.*?raise ESSLInvalidArgument\\.CreateWithContext\\(.*?'TWinSSLContext\\.LoadPrivateKey'.*?if PFXStore <> nil then.*?else\\s+begin\\s+raise ESSLConfigurationException\\.CreateWithContext\\(\\s+'WinSSL backend only supports PFX/P12 format for private key loading\\. '\\s*\\+\\s*'Bare PEM/DER/PKCS#8 private keys are unsupported; please merge certificate and key into a PFX file\\.',\\s+sslErrUnsupported,\\s+'TWinSSLContext\\.LoadPrivateKey'" \
  "WinSSL stream private-key loader must fail-closed on non-PFX input"







echo "[PASS] WinSSL private-key format truth contract passed"
