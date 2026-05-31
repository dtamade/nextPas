#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/cleanup_ci_artifacts_draft.sh"

WORK_REL="tmp/test_cleanup_ci_artifacts_contract"
ARTIFACT_REL="$WORK_REL/artifacts/ci"
ARTIFACT_ROOT="$ROOT_DIR/$ARTIFACT_REL"

set_mtime_days_ago() {
  local target="$1"
  local days="$2"

  TARGET="$target" DAYS="$days" python3 - <<'PY'
import os
import time

target = os.environ["TARGET"]
days = int(os.environ["DAYS"])
ts = time.time() - (days * 86400)
os.utime(target, (ts, ts))
PY
}

write_fixtures() {
  rm -rf "$ROOT_DIR/$WORK_REL"
  mkdir -p "$ARTIFACT_ROOT"

  mkdir -p "$ARTIFACT_ROOT/run_old_delete"
  mkdir -p "$ARTIFACT_ROOT/run_old_hold"
  mkdir -p "$ARTIFACT_ROOT/run_new_keep"

  touch "$ARTIFACT_ROOT/run_old_hold/.hold"

  # Set mtimes after all file creation; script uses directory mtime for age checks.
  set_mtime_days_ago "$ARTIFACT_ROOT/run_old_delete" 40
  set_mtime_days_ago "$ARTIFACT_ROOT/run_old_hold" 40
  set_mtime_days_ago "$ARTIFACT_ROOT/run_new_keep" 1
}

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if ! grep -Fq "$needle" <<<"$haystack"; then
    echo "[FAIL] expected output to contain: $needle"
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if grep -Fq "$needle" <<<"$haystack"; then
    echo "[FAIL] expected output to NOT contain: $needle"
    exit 1
  fi
}

write_fixtures

out="$(cd /tmp && bash "$SCRIPT" \
  --root "$ARTIFACT_REL" \
  --profile pr \
  --older-than-days 30 \
  --dry-run)"

assert_contains "$out" "[CANDIDATE] run_old_delete"
assert_contains "$out" "[SKIP-HOLD] run_old_hold"
assert_not_contains "$out" "[DELETED]"

if [[ ! -d "$ARTIFACT_ROOT/run_old_delete" ]]; then
  echo "[FAIL] dry-run should not delete eligible runs"
  exit 1
fi

out_apply="$(cd /tmp && bash "$SCRIPT" \
  --root "$ARTIFACT_REL" \
  --profile pr \
  --older-than-days 30 \
  --apply)"

assert_contains "$out_apply" "[DELETED] run_old_delete"

if [[ -d "$ARTIFACT_ROOT/run_old_delete" ]]; then
  echo "[FAIL] apply should delete eligible runs"
  exit 1
fi

if [[ ! -d "$ARTIFACT_ROOT/run_old_hold" ]]; then
  echo "[FAIL] hold-marked run should not be deleted"
  exit 1
fi

if [[ ! -d "$ARTIFACT_ROOT/run_new_keep" ]]; then
  echo "[FAIL] new run should be kept"
  exit 1
fi

echo "[PASS] root path + behavior contract passed"

