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

mbedtls_conn="src/nextpas.core.tls.mbedtls.connection.pas"
backend_matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
mbedtls_matrix="docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md"
mbedtls_guide="docs/guides/MBEDTLS_USER_GUIDE.md"
api_reference="docs/reference/API_REFERENCE.md"
api_documentation="docs/reference/API_DOCUMENTATION.md"
perf_guide="docs/guides/PERFORMANCE_OPTIMIZATION_GUIDE.md"
perf_profile="docs/guides/PERFORMANCE_PROFILING_GUIDE.md"

echo "[TEST] MbedTLS session resumption doc truth contract"

require_fixed "$mbedtls_conn" "FSessionReused := False;" \
  "MbedTLS source must keep configured session separate from observed reuse"
require_fixed "$mbedtls_conn" "Result := FSessionReused;" \
  "MbedTLS source must keep IsSessionReused wired to the conservative owner truth"

require_fixed "$backend_matrix" "| **Session Resumption**       | ⚠️         | ✅      | ⚠️     | ⚠️      | ✅      |" \
  "Top-level backend matrix must classify MbedTLS session resumption as bounded truth instead of unconditional support"
require_fixed "$backend_matrix" '- `MbedTLS`: public surface 已发布 `GetSession / SetSession / Serialize / Deserialize` 与 cache/ticket 候选路径，但当前 local source/header truth 只有 `mbedtls_ssl_set_session` / `mbedtls_ssl_get_session` / `mbedtls_ssl_session_load/save`，没有对称的 public reused getter；因此当前不把 `SetSession(...)` 自动解释成 observed resumed-handshake' \
  "Top-level backend matrix must record the current MbedTLS session-resumption boundary"

require_fixed "$mbedtls_matrix" '| Session 复用 | ⚠️ 当前 public surface 已发布 | 当前 backend 已发布 `GetSession / SetSession` 与 session serialize / deserialize / cache candidate path；但 local source/header truth 只有 `mbedtls_ssl_set_session` / `mbedtls_ssl_get_session` / `mbedtls_ssl_session_load/save`，没有像 `SSL_session_reused` / `wolfSSL_session_reused` 那样的 public reused getter，因此当前不把 `SetSession(...)` 自动解释成 observed resumed-handshake |' \
  "MbedTLS dedicated matrix must describe session resumption as bounded by the current observed-reuse truth gap"
require_fixed "$mbedtls_matrix" '当前 `Session Ticket` / `Session Cache` 这两行描述的是 fafafa.ssl 已发布的候选 surface；它们不单独构成“当前连接已经命中 resumed handshake”的 runtime proof。' \
  "MbedTLS dedicated matrix must separate candidate cache/ticket surface from observed reuse proof"
require_absent "$mbedtls_matrix" "| Session 复用 | ✅ 支持 | 完整支持 |" \
  "MbedTLS dedicated matrix must stop claiming unconditional session-resumption support"

require_fixed "$mbedtls_guide" '当前会话恢复 public surface 已发布 `GetSession / SetSession`、session serialize / deserialize 与 cache/ticket candidate path。' \
  "MbedTLS guide must record the published candidate session surface"
require_fixed "$mbedtls_guide" '但当前 local source/header truth 只有 `mbedtls_ssl_set_session` / `mbedtls_ssl_get_session` / `mbedtls_ssl_session_load/save`；没有像 `SSL_session_reused` / `wolfSSL_session_reused` 那样的 public reused getter。' \
  "MbedTLS guide must record the missing public reused getter boundary"
require_fixed "$mbedtls_guide" '因此 `SetSession(...)` 当前只表示“为下一次握手配置候选 session”；`IsSessionReused` / `GetConnectionInfo.IsResumed` 不应被写成已有通用 resumed-handshake runtime proof。' \
  "MbedTLS guide must stop equating configured session with observed reuse"

require_fixed "$api_reference" '> MbedTLS 当前边界：已发布 `GetSession / SetSession` 与 session serialize / deserialize path，但 local source/header truth 只有 `mbedtls_ssl_set_session` / `mbedtls_ssl_get_session` / `mbedtls_ssl_session_load/save`，没有像 `SSL_session_reused` / `wolfSSL_session_reused` 那样的 public reused getter。' \
  "API reference must record the current MbedTLS session-resumption boundary"
require_fixed "$api_reference" '> 因此当前 MbedTLS source/contract truth 只稳定证明“configured session 不会被误报成 observed resumed handshake”；不要把 `SetSession(...)` 自动读成 runtime reuse proof。' \
  "API reference must keep configured-session truth separate from observed reuse proof"

require_fixed "$api_documentation" '会话缓存允许调用方保存并重新注入 TLS 会话候选，但是否真的避免了完整握手，仍取决于 backend、目标站点、上下文复用和 native observed-reuse truth。' \
  "API documentation must describe session cache as candidate reuse input instead of unconditional performance proof"
require_fixed "$api_documentation" "WriteLn('已为下一次握手配置会话候选');" \
  "API documentation example must stop claiming SetSession alone equals successful reuse"
require_fixed "$api_documentation" '> 对 `MbedTLS` 而言，当前 public surface 已发布 session save/load 与 `SetSession(...)` candidate path，但 local source/header truth 只有 `mbedtls_ssl_set_session` / `mbedtls_ssl_get_session` / `mbedtls_ssl_session_load/save`；没有 public reused getter。' \
  "API documentation must record the current MbedTLS candidate-path boundary"

require_fixed "$perf_guide" '- `MbedTLS`: 当前 public surface 可以保存并注入 session candidate，但由于没有与 `SSL_session_reused` / `wolfSSL_session_reused` 对称的 public reused getter，当前 contract truth 只证明“configured session 不会被误报成 observed reuse”；不要把一次 `SetSession(...)` 直接读成通用 runtime 收益。' \
  "Performance optimization guide must record the current MbedTLS session boundary"
require_fixed "$perf_profile" '当前 MbedTLS session public surface 已能保存/注入 session candidate，但 local source/header truth 仍缺少与 `SSL_session_reused` / `wolfSSL_session_reused` 对称的 public reused getter；因此 profiling 时不要把 `SetSession(...)` 本身当成已稳定命中的 resumed-handshake 证据。' \
  "Performance profiling guide must record the current MbedTLS session boundary"

echo "[PASS] MbedTLS session resumption doc truth contract passed"

