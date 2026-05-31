#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

require_file() {
  local file="$1"
  local message="$2"
  if [[ ! -f "$file" ]]; then
    echo "[FAIL] $message"
    echo "  missing: $file"
    exit 1
  fi
}

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

require_file "docs/ROADMAP.md" "docs/ROADMAP.md must exist as the stable active roadmap entrypoint"
require_file "docs/plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md" \
  "framework excellence sequential execution master plan must exist as the current active batch"
require_fixed "docs/ROADMAP.md" "engineering_state: RELEASED" \
  "docs/ROADMAP.md must describe the post-release engineering state"
require_fixed "docs/ROADMAP.md" "approval_gate: sequential execution plan selected" \
  "docs/ROADMAP.md must document that scope selection has converged on the sequential execution plan"
require_fixed "docs/ROADMAP.md" 'current_execution_control_plane: `framework excellence sequential execution`' \
  "docs/ROADMAP.md must declare the current sequential execution plane"
require_fixed "docs/ROADMAP.md" 'current_release_plan: `docs/plans/2026-05-12-release-v1.5.0-formalization.md`' \
  "docs/ROADMAP.md must point to the active release-control plan"
require_fixed "docs/ROADMAP.md" 'current_release_readiness: `docs/test_reports/RELEASE_READINESS_V1.5.0.md`' \
  "docs/ROADMAP.md must point to the active release readiness report"
require_fixed "docs/ROADMAP.md" 'current_release_status: `RELEASED`' \
  "docs/ROADMAP.md must expose the released status"
require_fixed "docs/ROADMAP.md" 'wave_c_role: `closeout / approval / historical reference only`' \
  "docs/ROADMAP.md must limit Wave C to closeout / approval / history"
require_fixed "docs/ROADMAP.md" 'current_active_batch: `docs/plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md`' \
  "docs/ROADMAP.md must point the current active batch at the framework excellence sequential master plan"
require_fixed "docs/ROADMAP.md" 'next_route_candidate: `docs/plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md`' \
  "docs/ROADMAP.md must keep the next route candidate aligned to the framework excellence sequential master plan"
require_fixed "docs/ROADMAP.md" '当前活跃批次转入 framework excellence sequential execution master plan' \
  "docs/ROADMAP.md must describe the active route as the sequential execution master plan"

require_fixed "docs/plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md" \
  "# Framework Excellence Sequential Execution Master Plan" \
  "framework excellence sequential master plan must carry the expected title"
require_fixed "docs/plans/2026-05-25-framework-excellence-sequential-execution-master-plan.md" \
  "Stage 1: TSSLContextConfig factory direct application" \
  "framework excellence sequential master plan must start from the next code-heavy TSSLConfig slice"

require_fixed "docs/DOCUMENTATION_INDEX.md" "[ROADMAP.md](ROADMAP.md)" \
  "docs/DOCUMENTATION_INDEX.md must point to docs/ROADMAP.md as the active roadmap"
require_fixed "docs/DOCUMENTATION_INDEX.md" "[plans/2026-05-12-release-v1.5.0-formalization.md](plans/2026-05-12-release-v1.5.0-formalization.md)" \
  "docs/DOCUMENTATION_INDEX.md must point to the active release-control plan"
require_fixed "docs/DOCUMENTATION_INDEX.md" "[test_reports/RELEASE_READINESS_V1.5.0.md](test_reports/RELEASE_READINESS_V1.5.0.md)" \
  "docs/DOCUMENTATION_INDEX.md must point to the active release readiness report"
reject_regex "docs/DOCUMENTATION_INDEX.md" "\\*\\*\\[DEVELOPMENT_ROADMAP_2026\\.md\\]" \
  "docs/DOCUMENTATION_INDEX.md must not advertise the deleted 2026 roadmap as active"

require_fixed "docs/README.md" "[ROADMAP.md](ROADMAP.md)" \
  "docs/README.md must expose docs/ROADMAP.md as the current roadmap entrypoint"
require_fixed "docs/README.md" "plans/2026-05-12-release-v1.5.0-formalization.md" \
  "docs/README.md must expose the active release-control plan"
require_fixed "docs/README.md" "test_reports/RELEASE_READINESS_V1.5.0.md" \
  "docs/README.md must expose the active release readiness report"
require_fixed "README.md" "[当前路线图](docs/ROADMAP.md)" \
  "README.md must link to docs/ROADMAP.md from the primary docs table"
require_fixed "README.md" "[Release Plan](docs/plans/2026-05-12-release-v1.5.0-formalization.md)" \
  "README.md must link to the active release-control plan from the primary docs table"
require_fixed "README.md" "[Release Readiness](docs/test_reports/RELEASE_READINESS_V1.5.0.md)" \
  "README.md must link to the active release readiness report from the primary docs table"
require_fixed ".github/README.md" '`release.yml`' \
  ".github/README.md must expose the active release workflow"

require_fixed "docs/reference/ARCHITECTURE.md" "[当前路线图](../ROADMAP.md)" \
  "docs/reference/ARCHITECTURE.md must link to the stable active roadmap"
reject_regex "docs/ARCHITECTURE.md" "\\.claude/plans/" \
  "docs/ARCHITECTURE.md must not depend on local-only .claude roadmap files"

echo "[PASS] active roadmap references converge on stable in-repo docs"
