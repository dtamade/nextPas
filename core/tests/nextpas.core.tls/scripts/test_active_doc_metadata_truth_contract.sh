#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKEND_SELECTION_DOC="${BACKEND_SELECTION_DOC:-$ROOT_DIR/docs/BACKEND_SELECTION_GUIDE.md}"
ARCHITECTURE_DOC="${ARCHITECTURE_DOC:-$ROOT_DIR/docs/ARCHITECTURE.md}"
MIGRATION_V11_DOC="${MIGRATION_V11_DOC:-$ROOT_DIR/docs/MIGRATION_GUIDE_V1.1.md}"

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

echo "[TEST] active doc metadata truth contract"

require_fixed "$BACKEND_SELECTION_DOC" "**文档版本**: v1.5.0" \
  "BACKEND_SELECTION_GUIDE footer must reflect the current shipped doc version"
require_fixed "$BACKEND_SELECTION_DOC" "**适用版本**: fafafa.ssl v1.5.0+" \
  "BACKEND_SELECTION_GUIDE footer must reflect the current shipped applicability range"
require_fixed "$BACKEND_SELECTION_DOC" "**更新日期**: 2026-05-21" \
  "BACKEND_SELECTION_GUIDE footer must reflect the current update date"
require_absent "$BACKEND_SELECTION_DOC" "**文档版本**: 1.0" \
  "BACKEND_SELECTION_GUIDE footer must stop advertising stale 1.0 doc version"
require_absent "$BACKEND_SELECTION_DOC" "**适用版本**: fafafa.ssl v1.3.0+" \
  "BACKEND_SELECTION_GUIDE footer must stop advertising stale v1.3 applicability"

require_fixed "$ARCHITECTURE_DOC" "**文档版本**: v1.5.0" \
  "ARCHITECTURE footer must reflect the current shipped doc version"
require_fixed "$ARCHITECTURE_DOC" "**最后更新**: 2026-05-21" \
  "ARCHITECTURE footer must reflect the current update date"
require_absent "$ARCHITECTURE_DOC" "**文档版本**: 1.0" \
  "ARCHITECTURE footer must stop advertising stale 1.0 doc version"

require_fixed "$MIGRATION_V11_DOC" "**文档状态**: 历史 v1.1 / v1.2 迁移专题（已按当前 active truth 注释）" \
  "MIGRATION_GUIDE_V1.1 footer must classify itself as a historical topic with refreshed active-truth annotations"
require_fixed "$MIGRATION_V11_DOC" "**最后更新**: 2026-05-21" \
  "MIGRATION_GUIDE_V1.1 footer must reflect the current refresh date"
require_absent "$MIGRATION_V11_DOC" "**文档版本**: 1.2" \
  "MIGRATION_GUIDE_V1.1 footer must stop advertising stale v1.2 doc version"

echo "[PASS] active doc metadata truth contract passed"
