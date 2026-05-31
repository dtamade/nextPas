#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

backend_guide="docs/BACKEND_SELECTION_GUIDE.md"
pkcs11_guide="docs/guides/PKCS11_USER_GUIDE.md"
error_guide="docs/guides/ERROR_HANDLING_BEST_PRACTICES.md"
api_doc="docs/reference/API_DOCUMENTATION.md"
pkcs11_arch="docs/reference/PKCS11_ARCHITECTURE.md"
builder_src="src/nextpas.core.tls.context.builder.pas"

printf '[TEST] active server example verify-intent truth contract\n'

require_fixed "$builder_src" 'Result := WithAutoBackendSelection(CreatePerformanceFirstRequirements);' \
  "WithPerformanceFirst source truth must remain backend-selection-only"
require_fixed "$builder_src" 'Result := WithAutoBackendSelection(CreateSecurityFirstRequirements);' \
  "WithSecurityFirst source truth must remain backend-selection-only"
require_fixed "$builder_src" 'Result := WithAutoBackendSelection(CreateCompatibilityFirstRequirements);' \
  "WithCompatibilityFirst source truth must remain backend-selection-only"

require_fixed "$backend_guide" '这些快捷方法只负责 backend requirement / auto-selection，不会替 client/server 决定 VerifyMode。' \
  "backend selection guide must explain that quick selection methods do not choose verify mode"
require_fixed "$backend_guide" '.WithVerifyNone  // 普通单向 TLS server；如需 mTLS 改用 WithMutualTLS(...)' \
  "backend selection guide server scenario must make verify intent explicit"

require_fixed "$pkcs11_guide" '.WithVerifyNone  // 普通单向 TLS server；如需 mTLS 改用 WithMutualTLS(...)' \
  "PKCS11 server examples must make verify intent explicit"
require_fixed "$pkcs11_arch" '.WithVerifyNone  // 普通单向 TLS server；如需 mTLS 改用 WithMutualTLS(...)' \
  "PKCS11 architecture reference must make verify intent explicit"

require_fixed "$error_guide" '如果这里只是普通单向 TLS server，请显式加 `.WithVerifyNone`；如果要做 mTLS，请改成 `.WithMutualTLS(...)` 或等价 direct-context 配置。' \
  "error handling guide must explain server verify intent around BuildServer examples"

require_fixed "$api_doc" '如果这个 server context 只是普通单向 TLS，请在 builder 上显式加 `.WithVerifyNone`；如果要做 mTLS，请改成 `.WithMutualTLS(...)`。' \
  "API documentation must explain explicit server verify intent for BuildServer examples"

printf '[PASS] active server example verify-intent truth contract passed\n'
