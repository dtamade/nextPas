#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "[SKIP] not a git worktree"
  exit 0
fi

before_status="$(git status --porcelain)"

# Keep the contract cheap: run only one module, skip the broad compile step and phase2 dry-run.
bash scripts/run_minimal_ci_gate.sh \
  --fast-local \
  --skip-compile \
  --skip-phase2-dryrun \
  --modules PKCS7

after_status="$(git status --porcelain)"

if [[ "$before_status" != "$after_status" ]]; then
  echo "[FAIL] fast-local minimal gate changed git status output"
  echo "[INFO] before:"
  printf '%s\n' "$before_status"
  echo "[INFO] after:"
  printf '%s\n' "$after_status"
  exit 1
fi

echo "[PASS] fast-local minimal gate does not add workspace dirt"
