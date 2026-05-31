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

matrix="docs/BACKEND_CAPABILITY_MATRIX.md"
base_unit="src/nextpas.core.tls.base.pas"
roadmap="docs/ROADMAP.md"
release_notes="docs/RELEASE_NOTES.md"

echo "[TEST] backend capability matrix version-history truth contract"

require_fixed "$base_unit" "FAFAFA_SSL_VERSION_STRING = '1.6.0';" \
  "Source version truth must remain v1.6.0"
require_fixed "$roadmap" '- `v1.5.0` 的发布链已经闭环' \
  "Roadmap must keep the current v1.5.0 release-control truth"
require_fixed "$release_notes" '**当前稳定版本**: `v1.6.0`' \
  "Release notes must keep the current stable release truth"

require_fixed "$matrix" '**当前稳定版本**: `v1.6.0`' \
  "Top-level backend matrix must publish the current stable version first"
require_fixed "$matrix" '- [当前路线图](ROADMAP.md)' \
  "Top-level backend matrix must point readers to the current roadmap"
require_fixed "$matrix" '- [Release Readiness v1.5.0](test_reports/RELEASE_READINESS_V1.5.0.md)' \
  "Top-level backend matrix must point readers to the current release-readiness entry"
require_fixed "$matrix" '- [Release Notes](RELEASE_NOTES.md)' \
  "Top-level backend matrix must point readers to release notes"
require_fixed "$matrix" '下面这些条目只保留 capability/capability-doc 相关的历史里程碑，不能替代当前' \
  "Top-level backend matrix must demote the historical items"
require_fixed "$matrix" '`v1.5.0` 的 release/runtime truth。' \
  "Top-level backend matrix must explain that old milestones are not current release truth"
require_fixed "$matrix" '### v1.4.1 capability 里程碑 (2026-05-02)' \
  "Top-level backend matrix must relabel v1.4.1 as a historical capability milestone"
require_fixed "$matrix" '### v1.4.0 capability 里程碑 (2026-05-02)' \
  "Top-level backend matrix must relabel v1.4.0 as a historical capability milestone"
require_fixed "$matrix" '### v1.3.0 capability 里程碑' \
  "Top-level backend matrix must relabel v1.3.0 as a historical capability milestone"

echo "[PASS] backend capability matrix version-history truth contract passed"
