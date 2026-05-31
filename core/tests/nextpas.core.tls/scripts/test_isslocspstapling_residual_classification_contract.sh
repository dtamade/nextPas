#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

compare_file_list() {
  local label="$1"
  local actual="$2"
  local expected="$3"

  if [[ "$actual" != "$expected" ]]; then
    echo "[FAIL] $label mismatch"
    echo "[expected]"
    printf '%s\n' "$expected"
    echo "[actual]"
    printf '%s\n' "$actual"
    exit 1
  fi
}

require_pattern() {
  local file="$1"
  local pattern="$2"

  if ! grep -F -q -- "$pattern" "$file"; then
    echo "[FAIL] missing pattern in $file :: $pattern"
    exit 1
  fi
}

base_file="src/nextpas.core.tls.base.pas"
conn_base_file="src/nextpas.core.tls.connection.base.pas"
api_reference_file="docs/reference/API_REFERENCE.md"

declare -a required_base_patterns=(
  "@preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPStaplingEnabled 获取"
  "@owner-note 默认 owner 为 ISSLOCSPStapling.GetOCSPStaplingEnabled；此入口仅兼容保留"
  "@preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPResponse 获取"
  "@preferred-access 新代码优先通过 ISSLOCSPStapling.IsOCSPResponseVerified 获取"
  "@preferred-access 新代码优先通过 ISSLOCSPStapling.GetOCSPResponseStatus 获取"
)

for pattern in "${required_base_patterns[@]}"; do
  require_pattern "$base_file" "$pattern"
done

declare -a required_conn_base_patterns=(
  "\`GetOCSPStaplingEnabled\` / \`GetOCSPResponse\` / \`IsOCSPResponseVerified\` /"
  "\`GetOCSPResponseStatus\` 当前共享同一组基类 bridge/stub 实现；ordinary guidance"
  "已转向 \`ISSLOCSPStapling\` owner path，direct core \`GetOCSP*\` 当前只剩"
  "\`MbedTLS\` capability/runtime residual、\`OpenSSL\` runtime/contract residual"
  "与 \`WolfSSL\` runtime residual。"
)

for pattern in "${required_conn_base_patterns[@]}"; do
  require_pattern "$conn_base_file" "$pattern"
done

require_pattern "$api_reference_file" "\`GetOCSPStaplingEnabled\` / \`GetOCSPResponse\` / \`IsOCSPResponseVerified\` / \`GetOCSPResponseStatus\` 在 \`ISSLConnection\` 上当前也只作为 \`v1.x\` compatibility-core mirrors 保留；当前源码声明已经是编译期 \`deprecated\`，需要 stapled OCSP runtime state 时，新代码优先通过 \`ISSLOCSPStapling\` owner surface 访问。"

expected_hits="$(cat <<'EOF'
tests/mbedtls/test_mbedtls_ocsp_capability.pas
tests/openssl/test_ocsp_connection_verification_regression.pas
tests/test_openssl_connection_ocsp_storectx_issuer_contract.pas
tests/test_wolfssl_ocsp_stapling_contract.pas
EOF
)"

actual_hits="$(rg -l '\b(?:LConn|Conn|Connection)\.(GetOCSPStaplingEnabled|GetOCSPResponse|IsOCSPResponseVerified|GetOCSPResponseStatus)\b' tests --glob '!tests/scripts/**' | sort || true)"
compare_file_list "direct-core OCSP residual file set" "$actual_hits" "$expected_hits"

declare -a residual_files=(
  "tests/mbedtls/test_mbedtls_ocsp_capability.pas"
  "tests/openssl/test_ocsp_connection_verification_regression.pas"
  "tests/test_openssl_connection_ocsp_storectx_issuer_contract.pas"
  "tests/test_wolfssl_ocsp_stapling_contract.pas"
)

declare -a required_comment_patterns=(
  "INTENTIONAL_OCSP_CORE_SURFACE:"
  "intentionally keeps direct core OCSP compatibility-surface coverage"
  "Ordinary"
  "ISSLOCSPStapling owner-path guidance is frozen elsewhere."
)

for file in "${residual_files[@]}"; do
  for pattern in "${required_comment_patterns[@]}"; do
    require_pattern "$file" "$pattern"
  done
done

echo "[PASS] ISSLOCSPStapling residual direct-core surface stays intentionally frozen"
