#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

winssl_lib="src/nextpas.core.tls.winssl.lib.pas"
winssl_ctx="src/nextpas.core.tls.winssl.context.pas"
api_reference="docs/reference/API_REFERENCE.md"
winssl_matrix="docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
winssl_design="docs/reference/WINSSL_DESIGN.md"
winssl_quickstart="docs/guides/WINSSL_QUICKSTART.md"
winssl_best_practices="docs/guides/WINSSL_BEST_PRACTICES.md"
winssl_user_guide="docs/guides/WINSSL_USER_GUIDE.md"

echo "[TEST] WinSSL private-key format truth contract"

require_fixed "$winssl_lib" "Result.SupportsDERPrivateKey := False;" \
  "WinSSL must not publish bare DER private-key loading as supported"
require_fixed "$winssl_lib" "Result.SupportsPKCS8PrivateKey := False;" \
  "WinSSL must not publish bare PKCS#8 private-key loading as supported"
require_fixed "$winssl_lib" "Result.SupportsPKCS12 := True;" \
  "WinSSL must keep published PKCS#12/PFX private-key support"
require_absent "$winssl_lib" "或先转换为 DER 格式" \
  "WinSSL source comments must stop implying direct DER private-key loading is published"

require_pcre "$winssl_ctx" "procedure TWinSSLContext\\.LoadPrivateKey\\(AStream: TStream; const APassword: string\\);.*?if AStream = nil then.*?raise ESSLInvalidArgument\\.CreateWithContext\\(.*?'TWinSSLContext\\.LoadPrivateKey'.*?if PFXStore <> nil then.*?else\\s+begin\\s+raise ESSLConfigurationException\\.CreateWithContext\\(\\s+'WinSSL backend only supports PFX/P12 format for private key loading\\. '\\s*\\+\\s*'Bare PEM/DER/PKCS#8 private keys are unsupported; please merge certificate and key into a PFX file\\.',\\s+sslErrUnsupported,\\s+'TWinSSLContext\\.LoadPrivateKey'" \
  "WinSSL stream private-key loader must fail-closed on non-PFX input"

require_fixed "$api_reference" "当前 WinSSL 仅发布 password-protected PFX/P12 import path；PEM private-key password path 仍为 unsupported。" \
  "API reference must keep current WinSSL password-protected key truth"
require_fixed "$api_reference" "当前 WinSSL 不发布 bare DER / PKCS#8 private-key load surface；如需这类输入，请改用 PFX/P12 或切换 OpenSSL backend。" \
  "API reference must record current WinSSL DER/PKCS#8 truth"

require_fixed "$winssl_matrix" "| Password-protected private keys | ⚠️ 部分                   | 当前仅 password-protected PFX/P12 import path 已发布；PEM private-key password path 仍为 unsupported" \
  "WinSSL matrix must keep the password-protected key partial-publication row"
require_fixed "$winssl_matrix" "| DER / PKCS#8 private keys       | ❌ 当前 capability 不发布 | 目前没有 shipped bare DER / PKCS#8 private-key load path；请改用 PFX/P12 或 OpenSSL backend" \
  "WinSSL matrix must record the current DER/PKCS#8 private-key truth"

require_fixed "$winssl_design" "- 当前 password-protected private key surface = PFX/P12 import；PEM private-key password path 仍未发布" \
  "WinSSL design doc must keep current password-protected key truth"
require_fixed "$winssl_design" "- 当前 bare DER / PKCS#8 private-key load surface 仍未发布；如需裸私钥导入，请改用 OpenSSL backend 或先封装为 PFX/P12" \
  "WinSSL design doc must record current DER/PKCS#8 truth"

require_fixed "$winssl_quickstart" "Ctx.LoadPrivateKey('client.pfx', 'pfx-password');" \
  "WinSSL quickstart must use PFX/P12 private-key examples"
require_absent "$winssl_quickstart" "Ctx.LoadPrivateKey('client.key');" \
  "WinSSL quickstart must stop suggesting bare key files"

require_fixed "$winssl_best_practices" "LContext.LoadPrivateKey('server.pfx', 'pfx-password');" \
  "WinSSL best practices must use PFX/P12 private-key examples"
require_absent "$winssl_best_practices" "LContext.LoadPrivateKey('server.key', 'password');" \
  "WinSSL best practices must stop suggesting bare key/password loading"

require_fixed "$winssl_user_guide" "- ✅ LoadPrivateKey（支持密码保护的 PFX/P12）" \
  "WinSSL user guide must state that private-key loading is PFX/P12-only"
require_fixed "$winssl_user_guide" "- ❌ bare DER / PKCS#8 private key loading（当前 capability 不发布）" \
  "WinSSL user guide must state that bare DER/PKCS#8 private-key loading is unpublished"

echo "[PASS] WinSSL private-key format truth contract passed"
