#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
winssl_context="$repo_root/src/nextpas.core.tls.winssl.context.pas"
auto_loading="$repo_root/docs/CA_CERTIFICATE_AUTO_LOADING.md"
troubleshooting="$repo_root/docs/guides/TROUBLESHOOTING.md"
best_practices="$repo_root/docs/guides/WINSSL_BEST_PRACTICES.md"
api_reference="$repo_root/docs/reference/API_REFERENCE.md"
winssl_matrix="$repo_root/docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
zh_faq="$repo_root/docs/zh/FAQ.md"

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

require_fixed "$winssl_context" "LoadCAPath is not supported on Windows." \
  "WinSSL runtime must keep the explicit CAPath unsupported exception text"

forbid_fixed "$auto_loading" 'both compose cleanly with `.WithCAFile`, `.WithCAPath`, or `SetCertificateStore(...)`' \
  "CA auto-loading guide must not describe CAPath as a portable cross-backend compose rule"
require_fixed "$auto_loading" 'WinSSL rejects non-empty `CAPath` because Schannel uses the Windows certificate store.' \
  "CA auto-loading guide must document WinSSL non-empty CAPath rejection"

require_fixed "$troubleshooting" 'WinSSL / Windows: non-empty `LoadCAPath(...)` is unsupported; prefer `.WithSystemRoots`, `TSSLConfig.UseSystemRoots := True`, or explicit `LoadCAFile(...)`.' \
  "Troubleshooting guide must call out the WinSSL CAPath unsupported caveat"

forbid_fixed "$best_practices" "LContext.LoadCAPath('/etc/ssl/certs');  // Linux" \
  "WinSSL best practices must not teach Linux CAPath loading inside the WinSSL-specific guidance"
require_fixed "$best_practices" 'WinSSL 当前不支持 non-empty `LoadCAPath(...)`；Windows trust roots 请优先走系统证书存储。' \
  "WinSSL best practices must document the non-empty CAPath unsupported truth"

require_fixed "$api_reference" '字段会被消费，不代表每个 backend 都接受相同的 runtime 语义。' \
  "API reference must distinguish field-consumption parity from runtime-semantics parity"
require_fixed "$api_reference" 'WinSSL 对非空 `CAPath` 会 fail-fast reject；Windows 上请优先使用 `UseSystemRoots` 或显式 `CAFile`。' \
  "API reference must document WinSSL non-empty CAPath fail-fast behavior"

require_fixed "$winssl_matrix" '非空 `LoadCAPath(...)` / `TSSLConfig.CAPath` 在 WinSSL 上会 fail-fast unsupported；Windows trust roots 应优先走系统证书存储或显式 `CAFile`。' \
  "WinSSL capability matrix must list CAPath unsupported truth"

require_fixed "$zh_faq" 'Windows / WinSSL 不支持非空 `LoadCAPath(...)`；普通新代码请优先走 `.WithSystemRoots`，需要额外私有 CA 时再显式 `LoadCAFile(...)`。' \
  "Chinese FAQ must document the WinSSL CAPath caveat"

echo "[PASS] WinSSL CAPath unsupported active docs truth contract is satisfied."
