#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

require_fixed() {
  local file="$1"
  local expected="$2"
  local message="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "[FAIL] $message"
    echo "  file: $file"
    echo "  expected: $expected"
    exit 1
  fi
}

reject_regex() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -n --quiet "$pattern" "$file"; then
    echo "[FAIL] $message"
    rg -n "$pattern" "$file" || true
    exit 1
  fi
}

require_fixed "README.md" '- 默认导航：先看 `docs/ROADMAP.md`、`docs/plans/2026-05-12-release-v1.5.0-formalization.md`、`docs/test_reports/RELEASE_READINESS_V1.5.0.md`。' \
  "README is missing the current release-control navigation line"
require_fixed "README.md" '- Wave C closeout / 审批参考：`docs/test_reports/WAVE_C_CLOSEOUT_STATUS_2026-03-18.md`、`docs/test_reports/WAVE_C_LOCAL_FIRST_AND_PRE_CI_CHAIN_STATUS_2026-03-16.md`。' \
  "README is missing the Wave C closeout / approval label"
require_fixed "README.md" '- 历史手册仅作参考：`docs/test_reports/WAVE_C_B121_ONE_PAGE_RUNBOOK_2026-02-08.md`、`docs/test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md`。' \
  "README is missing the historical-only label for B121/B127"

require_fixed "docs/README.md" "## 当前工程入口（post-release）" \
  "docs/README.md is missing the post-release entrypoint section"
require_fixed "docs/README.md" '当前已发布 release-control plan：`plans/2026-05-12-release-v1.5.0-formalization.md`' \
  "docs/README.md is missing the current release-control plan link"
require_fixed "docs/README.md" '当前已发布 release readiness：`test_reports/RELEASE_READINESS_V1.5.0.md`' \
  "docs/README.md is missing the current release readiness link"
require_fixed "docs/README.md" '- 当前 workflow surface：`../.github/README.md`' \
  "docs/README.md is missing the workflow surface link"
require_fixed "docs/README.md" "python3 scripts/compile_all_modules.py" \
  "docs/README.md is missing the canonical compile entry command"
require_fixed "docs/README.md" "bash scripts/run_minimal_ci_gate.sh --fast-local" \
  "docs/README.md is missing the canonical minimal gate command"
require_fixed "docs/README.md" "bash scripts/run_freepascal_tls13_completeness_gate.sh --fast-local" \
  "docs/README.md is missing the canonical FreePascal focused gate command"
require_fixed "docs/README.md" "python3 scripts/check_code_style.py src" \
  "docs/README.md is missing the canonical style gate command"
require_fixed "docs/README.md" "bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local" \
  "docs/README.md is missing the canonical phase2 dry-run command"
require_fixed "docs/README.md" 'Wave C closeout / 历史参考：`test_reports/WAVE_C_CLOSEOUT_STATUS_2026-03-18.md`、`test_reports/WAVE_C_LOCAL_FIRST_AND_PRE_CI_CHAIN_STATUS_2026-03-16.md`' \
  "docs/README.md is missing the Wave C closeout / approval label"
require_fixed "docs/README.md" '历史参考：`test_reports/WAVE_C_B121_ONE_PAGE_RUNBOOK_2026-02-08.md`、`test_reports/WAVE_C_B127_LOCAL_GUARD_TROUBLESHOOTING_2026-02-09.md`' \
  "docs/README.md is missing the historical-only Wave C references"

require_fixed "docs/DOCUMENTATION_INDEX.md" "## 🧭 当前工程入口（post-release）" \
  "docs/DOCUMENTATION_INDEX.md is missing the release-control entrypoint section"
require_fixed "docs/DOCUMENTATION_INDEX.md" "**[plans/2026-05-12-release-v1.5.0-formalization.md](plans/2026-05-12-release-v1.5.0-formalization.md)**" \
  "docs/DOCUMENTATION_INDEX.md is missing the release-control plan link"
require_fixed "docs/DOCUMENTATION_INDEX.md" "**[test_reports/RELEASE_READINESS_V1.5.0.md](test_reports/RELEASE_READINESS_V1.5.0.md)**" \
  "docs/DOCUMENTATION_INDEX.md is missing the release readiness link"
require_fixed "docs/DOCUMENTATION_INDEX.md" "### Wave C closeout / 审批 / 历史参考" \
  "docs/DOCUMENTATION_INDEX.md is missing the Wave C closeout / history section label"
require_fixed "docs/DOCUMENTATION_INDEX.md" "以下条目不再是默认工程入口，仅在需要审批、closeout 或历史对照时使用。" \
  "docs/DOCUMENTATION_INDEX.md is missing the Wave C role note"

reject_regex "docs/README.md" "Wave C canonical chain" \
  "docs/README.md still presents Wave C as the canonical engineering chain"
reject_regex "docs/DOCUMENTATION_INDEX.md" "Wave C canonical chain" \
  "docs/DOCUMENTATION_INDEX.md still presents Wave C as the canonical engineering chain"

reject_regex "docs/guides/GETTING_STARTED.md" "bash build_linux\\.sh" \
  "GETTING_STARTED.md still treats build_linux.sh as active build/test guidance"
require_fixed "docs/guides/GETTING_STARTED.md" "bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local" \
  "GETTING_STARTED.md is missing the current phase2 dry-run guidance"

reject_regex "docs/guides/QUICKSTART.md" "bash build_linux\\.sh" \
  "QUICKSTART.md still treats build_linux.sh as active build/test guidance"
require_fixed "docs/guides/QUICKSTART.md" "bash scripts/run_phase2_performance_baseline.sh --dry-run --fast-local" \
  "QUICKSTART.md is missing the current phase2 dry-run guidance"

echo "[PASS] release-control entrypoint docs converge on the active chain and keep Wave C historical boundaries explicit"
