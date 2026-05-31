#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

assert_contains() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if ! rg -F --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    echo "[INFO] top of $file:"
    sed -n '1,260p' "$file" || true
    exit 1
  fi
}

assert_not_regex() {
  local file="$1"
  local pattern="$2"
  local message="$3"

  if rg -n --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    rg -n -- "$pattern" "$file" || true
    exit 1
  fi
}

assert_contains "README.md" \
  "- 历史手册仅作参考：\`docs/test_reports/WAVE_C_B121_ONE_PAGE_RUNBOOK_2026-02-08.md\`、\`docs/test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md\`。" \
  "README lost the historical-only label for B121/B127"

assert_contains "docs/README.md" \
  "历史参考：\`test_reports/WAVE_C_B121_ONE_PAGE_RUNBOOK_2026-02-08.md\`、\`test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md\`" \
  "docs/README.md lost the historical-only Wave C reference label"

assert_contains "docs/DOCUMENTATION_INDEX.md" \
  "### Wave C closeout / 审批 / 历史参考" \
  "Documentation index lost the Wave C closeout / historical section label"
assert_contains "docs/DOCUMENTATION_INDEX.md" \
  "WAVE_C_B121_ONE_PAGE_RUNBOOK_2026-02-08.md" \
  "Documentation index lost the B121 historical page link"
assert_contains "docs/DOCUMENTATION_INDEX.md" \
  "WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md" \
  "Documentation index lost the B127 historical page link"

assert_contains "docs/AGENTS.md" \
  "\`build_linux.sh\` 仍保留为历史兼容入口，但不再是默认文档路径。" \
  "docs/AGENTS.md no longer labels build_linux.sh as historical compatibility guidance"

assert_contains "docs/guides/LINUX_QUICKSTART.md" \
  "历史兼容构建脚本（非默认入口）" \
  "LINUX_QUICKSTART lost the historical label for build_linux.sh"

assert_contains "docs/guides/QUICKSTART_30SEC.md" \
  "需要回看历史故障定位顺序时，再看 \`docs/test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md\`" \
  "QUICKSTART_30SEC lost the historical-only label for B127"
assert_not_regex "docs/guides/QUICKSTART_30SEC.md" \
  "^[[:space:]]*-[[:space:]]*先看[[:space:]]+\`docs/test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09\\.md\`" \
  "QUICKSTART_30SEC still treats B127 as the first-stop troubleshooting entry"

assert_contains "docs/FCL_DEPENDENCIES.md" \
  "历史 \`build_linux.sh\` 仍可作为兼容入口保留，但不再是默认文档路径。" \
  "FCL dependencies doc lost the historical compatibility label for build_linux.sh"

echo "[PASS] active docs keep historical references explicitly labeled as historical/compatibility context"
