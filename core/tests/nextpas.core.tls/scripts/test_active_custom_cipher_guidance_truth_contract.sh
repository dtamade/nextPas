#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
readme_file="$repo_root/README.md"
api_reference="$repo_root/docs/reference/API_REFERENCE.md"
api_documentation="$repo_root/docs/reference/API_DOCUMENTATION.md"
user_guide="$repo_root/docs/guides/USER_GUIDE.md"
troubleshooting="$repo_root/docs/guides/TROUBLESHOOTING.md"
security_guide="$repo_root/docs/guides/SECURITY_GUIDE.md"
security_best="$repo_root/docs/guides/security-best-practices.md"
security_audit="$repo_root/docs/guides/SECURITY_AUDIT.md"

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
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed "$user_guide" '普通跨后端新代码优先使用 builder / default-context 的 shipped baseline；只有在 `SupportsCustomCipherSuites=True` 的 backend（当前 OpenSSL 与 FreePascal 显式 allowlist 路径）上，才传入 custom non-default cipher override。' \
  "User guide must distinguish cross-backend baseline guidance from backend-gated custom cipher tuning"
require_pcre "$user_guide" "if LLib\\.GetCapabilities\\.SupportsCustomCipherSuites then\\s*begin\\s*LContext\\.SetCipherSuites\\('TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256'\\);\\s*LContext\\.SetCipherList\\('ECDHE\\+AESGCM:ECDHE\\+CHACHA20:DHE\\+AESGCM:DHE\\+CHACHA20:!aNULL:!MD5:!DSS'\\);" \
  "User guide custom cipher example must stay gated behind SupportsCustomCipherSuites"
require_pcre "$user_guide" "if LLib\\.GetCapabilities\\.SupportsCustomCipherSuites then\\s*LContext\\.SetCipherSuites\\('TLS_AES_128_GCM_SHA256'\\);" \
  "User guide performance tuning example must stay gated behind SupportsCustomCipherSuites"

forbid_fixed "$troubleshooting" "LContext.SetCipherSuites('TLS_AES_128_GCM_SHA256');  // 硬件加速" \
  "Troubleshooting guide must not present direct cipher-suite tuning as a generic handshake optimization"
forbid_fixed "$troubleshooting" "LContext.SetCipherList('ECDHE+AESGCM');" \
  "Troubleshooting guide must not present direct cipher-list tuning as a generic handshake optimization"
require_fixed "$troubleshooting" '如果你明确锁定的是 `SupportsCustomCipherSuites=True` 的 backend（当前 OpenSSL 与 FreePascal 显式 allowlist 路径），才继续调 custom cipher；否则优先保留 shipped baseline defaults。' \
  "Troubleshooting guide must gate custom cipher tuning behind backend capability truth"

forbid_fixed "$security_guide" "LContext.SetCipherSuites(" \
  "Security guide must not present custom cipher suites as a generic security baseline recipe"
forbid_fixed "$security_guide" "LContext.SetCipherList('ECDHE+AESGCM:DHE+AESGCM:!RSA');" \
  "Security guide must not present custom cipher lists as a generic PFS recipe"
forbid_fixed "$security_guide" "LContext.SetCipherList('!CBC');" \
  "Security guide must not present generic denylist cipher tuning for all backends"
require_fixed "$security_guide" '普通跨后端路径优先收紧 TLS 版本并使用 `WithSafeDefaults`；custom cipher allowlist / denylist 只应在 `SupportsCustomCipherSuites=True` 的 backend 上配置。' \
  "Security guide must distinguish generic protocol guidance from backend-gated custom cipher tuning"

require_fixed "$security_best" '只有在 `ISSLLibrary.GetCapabilities.SupportsCustomCipherSuites=True` 的 backend（当前 OpenSSL 与 FreePascal 显式 allowlist 路径）上，才追加 `WithCipherList(...)` / `WithTLS13Ciphersuites(...)`。' \
  "Security best-practices guide must gate fine-grained builder cipher tuning behind backend capability truth"

forbid_fixed "$readme_file" "Ctx.SetCipherList('TLS_AES_256_GCM_SHA384');  // 可选" \
  "README must not present direct cipher-list tuning as a generic low-level core-surface option"
require_fixed "$readme_file" '如果你明确锁定的是支持 custom cipher override 的 backend（当前 OpenSSL 与 FreePascal 显式 allowlist 路径），再在 capability check 之后调用 `SetCipherList(...)` / `SetCipherSuites(...)`。' \
  "README must classify direct custom cipher tuning as backend-gated advanced usage"

forbid_fixed "$api_documentation" ".WithCipherList('HIGH:!aNULL:!MD5'); // 强密码套件" \
  "API documentation must not present custom builder cipher tuning as a generic server example"
require_fixed "$api_documentation" '如需 custom cipher allowlist，请只在 `SupportsCustomCipherSuites=True` 的 backend（当前 OpenSSL 与 FreePascal 显式 allowlist 路径）上追加这类 builder 配置。' \
  "API documentation must gate builder custom cipher tuning behind backend capability truth"

require_fixed "$api_reference" 'custom non-default `CipherList` / `CipherSuites` 仍是 backend-gated surface；对 `SupportsCustomCipherSuites=False` 的 backend 会 fail-fast reject。' \
  "API reference must record direct-library custom cipher backend gating"

require_fixed "$security_audit" '如果你明确锁定的是 `OpenSSL` 这类支持 custom cipher override 的 backend，才考虑这类 allowlist。' \
  "Security audit guide must classify custom cipher allowlists as backend-specific tuning"

echo "[PASS] Active custom cipher guidance truth contract is satisfied."
