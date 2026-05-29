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

audit="docs/test_reports/INTERFACE_DESIGN_AUDIT_V1.5.0.md"
backend_matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
api_reference="docs/reference/API_REFERENCE.md"
base_unit="src/nextpas.core.tls.base.pas"
migration_guide="docs/MIGRATION_GUIDE_V1.1.md"

echo "[TEST] interface audit capability current truth contract"

require_fixed "$base_unit" "paired capability truth follows the support-level fields; legacy Supports* booleans are compatibility projections normalized via NormalizeLegacyCapabilityBooleans(...)" \
  "base unit must keep the support-level-first capability truth note"
require_fixed "$backend_matrix" '本表对 SNI / ALPN / OCSP stapling / Certificate Transparency / Session Tickets 统一按 `*Support` 支持级别字段汇总；legacy `Supports*` 布尔值仅作为兼容投影。' \
  "backend capability matrix must keep the support-level-first public truth"
require_fixed "$api_reference" '当 `SNISupport` / `ALPNSupport` / `OCSPStaplingSupport` / `CertTransparencySupport` / `SessionTicketsSupport` / `SessionCacheSupport` 出现时，它们是当前 source/runtime truth；legacy `SupportsSNI` / `SupportsALPN` / `SupportsOCSPStapling` / `SupportsCertificateTransparency` / `SupportsSessionTickets` 仅作为兼容投影。' \
  "API reference must keep the support-level-first precedence rule"
require_fixed "$migration_guide" '对于 paired feature（如 ALPN / SNI / OCSP Stapling / CT / Session Tickets）请优先读取 `*Support` 字段；legacy `Supports*` 仅用于兼容旧调用代码。' \
  "migration guide must keep the support-level-first paired-feature rule"

require_fixed "$audit" "capability public surface 的 runtime/source truth 已经不再是未分类的双真相冲突。" \
  "audit must explicitly state that capability runtime/source truth is no longer an unresolved dual-truth conflict"
require_fixed "$audit" 'paired feature 当前已经收敛到 support-level-first；legacy `Supports*` 更接近 compatibility projection baggage。' \
  "audit must classify legacy capability booleans as compatibility baggage"
require_fixed "$audit" "serializer / diff / selector / 活跃文档入口 当前都已经按 support-level-first 收平。" \
  "audit must record that the capability control-plane has already converged to support-level-first"

require_absent "$audit" "### 5. 能力矩阵存在双真相" \
  "audit must stop presenting capability as a live dual-truth section"
require_absent "$audit" "API 使用者不知道该信哪一套。" \
  "audit must stop claiming the public capability truth is still undecided"
require_absent "$audit" "过渡期里至少在 serializer 和 selector 里明确 precedence。" \
  "audit must stop describing support-level precedence as still unfinished work"

echo "[PASS] interface audit capability current truth contract passed"
