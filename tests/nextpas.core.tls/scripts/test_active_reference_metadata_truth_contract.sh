#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
API_DESIGN_DOC="${API_DESIGN_DOC:-$ROOT_DIR/docs/reference/API_DESIGN_GUIDE.md}"
ERROR_GUIDE_DOC="${ERROR_GUIDE_DOC:-$ROOT_DIR/docs/guides/ERROR_HANDLING_BEST_PRACTICES.md}"
CODING_DOC="${CODING_DOC:-$ROOT_DIR/docs/guides/CODING_STANDARDS.md}"

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

echo "[TEST] active reference metadata truth contract"

require_fixed "$API_DESIGN_DOC" "> **版本**: v1.5.0" \
  "API_DESIGN_GUIDE must refresh the active version header"
require_fixed "$API_DESIGN_DOC" "> **最后更新**: 2026-05-21" \
  "API_DESIGN_GUIDE must refresh the active update date"
require_fixed "$API_DESIGN_DOC" "> **定位**: 设计原则参考；当前 shipped public surface 以 \`src/nextpas.core.tls.base.pas\`、\`src/nextpas.core.tls.pas\` 与 [API_REFERENCE.md](API_REFERENCE.md) 为准。" \
  "API_DESIGN_GUIDE must declare its design-principles reference scope"
require_absent "$API_DESIGN_DOC" "**版本**: 1.0.0" \
  "API_DESIGN_GUIDE must stop advertising stale 1.0.0 metadata"

require_fixed "$ERROR_GUIDE_DOC" "**版本**: v1.5.0" \
  "ERROR_HANDLING_BEST_PRACTICES must refresh the active version header"
require_fixed "$ERROR_GUIDE_DOC" "**最后更新**: 2026-05-21" \
  "ERROR_HANDLING_BEST_PRACTICES must refresh the active update date"
require_fixed "$ERROR_GUIDE_DOC" "**定位**: 当前 v1.5.0 错误处理模式与示例指南（具体 public API 以 API_REFERENCE 为准）" \
  "ERROR_HANDLING_BEST_PRACTICES must declare its current active scope"
require_absent "$ERROR_GUIDE_DOC" "**版本**: 1.0" \
  "ERROR_HANDLING_BEST_PRACTICES must stop advertising stale 1.0 metadata"
require_absent "$ERROR_GUIDE_DOC" "**最后更新**: 2025-01-18" \
  "ERROR_HANDLING_BEST_PRACTICES must stop advertising stale 2025-01-18 metadata"

require_fixed "$CODING_DOC" "**版本**: v1.5.0" \
  "CODING_STANDARDS must refresh the active version header"
require_fixed "$CODING_DOC" "**最后更新**: 2026-05-21" \
  "CODING_STANDARDS must refresh the active update date"
require_fixed "$CODING_DOC" "**适用范围**: fafafa.ssl 当前仓库活跃代码、测试与文档示例" \
  "CODING_STANDARDS must declare its current active applicability scope"
require_absent "$CODING_DOC" "**版本**: 1.0.0" \
  "CODING_STANDARDS must stop advertising stale 1.0.0 metadata"
require_absent "$CODING_DOC" "**日期**: 2025-11-26" \
  "CODING_STANDARDS must stop advertising stale 2025-11-26 metadata"

echo "[PASS] active reference metadata truth contract passed"
