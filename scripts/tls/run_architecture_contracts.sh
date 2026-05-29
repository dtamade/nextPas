#!/usr/bin/env bash
# Fast architecture/guidance contract runner.
# Use this as the quick development loop for doc/guidance changes.
# Runs in < 30s vs ~4min for the full minimal CI gate.
#
# Gate hierarchy:
#   1. scripts/run_architecture_contracts.sh  (< 30s, doc/guidance truth)
#   2. python3 scripts/compile_all_modules.py --rebuild  (< 2min, code compiles)
#   3. scripts/run_minimal_ci_gate.sh --fast-local  (< 4min, full local gate)
#   4. GitHub Actions CI  (before merge)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

PASS=0
FAIL=0
FAILED_LIST=()

run_contract() {
  local script="$1"
  if bash "$script" > /dev/null 2>&1; then
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
    FAILED_LIST+=("$script")
  fi
}

echo "========================================"
echo "Architecture & Guidance Contracts"
echo "========================================"

# Stage 2-3 core contracts
run_contract tests/scripts/test_facade_main_entry_truth_contract.sh
run_contract tests/scripts/test_public_unit_import_guidance_truth_contract.sh
run_contract tests/scripts/test_active_examples_public_import_truth_contract.sh
run_contract tests/scripts/test_user_guide_ordinary_entrypoint_truth_contract.sh
run_contract tests/scripts/test_active_roadmap_references_contract.sh
run_contract tests/scripts/test_tsslconfig_stage2_public_guidance_truth_contract.sh
run_contract tests/scripts/test_tsslconfig_stage2_active_docs_examples_drift_contract.sh
run_contract tests/scripts/test_tsslconfig_active_guidance_truth_contract.sh
run_contract tests/scripts/test_tsslconfig_migration_targets_contract.sh
run_contract tests/scripts/test_tsslconfig_scope_bucket_truth_contract.sh

# Platform and SNI guidance
run_contract tests/scripts/test_platform_support_guidance_convergence_contract.sh
run_contract tests/scripts/test_landing_docs_connection_level_sni_guidance_contract.sh
run_contract tests/scripts/test_migration_troubleshooting_connection_level_sni_omissions_contract.sh

echo ""
echo "========================================"
echo "Results: $PASS passed, $FAIL failed"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Failed contracts:"
  for f in "${FAILED_LIST[@]}"; do
    echo "  - $f"
  done
  exit 1
fi

echo "[PASS] All architecture contracts green"
