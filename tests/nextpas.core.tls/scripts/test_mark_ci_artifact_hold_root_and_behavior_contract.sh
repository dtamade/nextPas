#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/mark_ci_artifact_hold_draft.sh"

WORK_REL="tmp/test_mark_ci_artifact_hold_contract"
ROOT_REL="$WORK_REL/artifacts/ci"
RUN_ID="hold_contract_run_001"
RUN_DIR_REL="$ROOT_REL/$RUN_ID"
RUN_DIR="$ROOT_DIR/$RUN_DIR_REL"

write_fixtures() {
  rm -rf "$ROOT_DIR/$WORK_REL"
  mkdir -p "$RUN_DIR"
}

assert_exists() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "[FAIL] expected file to exist: $path"
    exit 1
  fi
}

assert_not_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "[FAIL] expected path to not exist: $path"
    exit 1
  fi
}

assert_meta_contains() {
  local file="$1"
  local needle="$2"
  if ! grep -Fq "$needle" "$file"; then
    echo "[FAIL] expected meta to contain: $needle"
    exit 1
  fi
}

write_fixtures

HOLD_FILE="$RUN_DIR/.hold"
META_FILE="$RUN_DIR/.hold.meta"

assert_not_exists "$HOLD_FILE"
assert_not_exists "$META_FILE"

# Dry-run should not create files (run-id path), and must work from /tmp with repo-relative --root.
(cd /tmp && bash "$SCRIPT" \
  --root "$ROOT_REL" \
  --run-id "$RUN_ID" \
  --reason "reason_a" \
  --owner "owner_a" \
  --expires-on "2026-03-01" \
  --dry-run >/dev/null)

assert_not_exists "$HOLD_FILE"
assert_not_exists "$META_FILE"

# Apply should create hold marker + metadata (run-id path).
(cd /tmp && bash "$SCRIPT" \
  --root "$ROOT_REL" \
  --run-id "$RUN_ID" \
  --reason "reason_b" \
  --owner "owner_b" \
  --expires-on "2026-03-02" \
  --apply >/dev/null)

assert_exists "$HOLD_FILE"
assert_exists "$META_FILE"
assert_meta_contains "$META_FILE" "reason: reason_b"
assert_meta_contains "$META_FILE" "owner: owner_b"
assert_meta_contains "$META_FILE" "expires_on: 2026-03-02"

# Clear should remove both files (run-id path).
(cd /tmp && bash "$SCRIPT" \
  --root "$ROOT_REL" \
  --run-id "$RUN_ID" \
  --clear \
  --apply >/dev/null)

assert_not_exists "$HOLD_FILE"
assert_not_exists "$META_FILE"

# Exercise --run-dir with a repo-relative path from /tmp.
(cd /tmp && bash "$SCRIPT" \
  --run-dir "$RUN_DIR_REL" \
  --reason "reason_c" \
  --owner "owner_c" \
  --expires-on "2026-03-03" \
  --apply >/dev/null)

assert_exists "$HOLD_FILE"
assert_exists "$META_FILE"
assert_meta_contains "$META_FILE" "reason: reason_c"

(cd /tmp && bash "$SCRIPT" \
  --run-dir "$RUN_DIR_REL" \
  --clear \
  --apply >/dev/null)

assert_not_exists "$HOLD_FILE"
assert_not_exists "$META_FILE"

echo "[PASS] root/run-dir path + behavior contract passed"

