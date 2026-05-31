#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/remind_hold_expiry_review_draft.sh"

WORK_REL="tmp/test_hold_expiry_review_contract"
ARTIFACT_REL="$WORK_REL/artifacts/ci"
REL_OUTPUT="$WORK_REL/hold_expiry_review.md"
TODAY="2026-02-13"

write_fixtures() {
  local run_id="$1"
  local expires_on="$2"

  mkdir -p "$ROOT_DIR/$ARTIFACT_REL/$run_id"

  cat > "$ROOT_DIR/$ARTIFACT_REL/$run_id/.hold.meta" <<EOF
run_id: $run_id
reason: contract_test
owner: owner_test
expires_on: $expires_on
set_at: 2026-02-01 00:00:00 +0000
EOF
}

assert_overdue_one() {
  local file="$1"
  if ! grep -qE "^\\| overdue \\| 1 \\|" "$file"; then
    echo "[FAIL] expected overdue=1 in report: $file"
    exit 1
  fi
}

run_path_contract() {
  rm -rf "$ROOT_DIR/$WORK_REL"
  mkdir -p "$ROOT_DIR/$WORK_REL"

  write_fixtures "run_overdue_1" "2026-02-10"

  rm -f "$ROOT_DIR/$REL_OUTPUT"

  (cd "$ROOT_DIR" && bash "$SCRIPT" \
    --root "$ARTIFACT_REL" \
    --today "$TODAY" \
    --days 7 \
    --output "$REL_OUTPUT" >/dev/null)

  if [[ ! -f "$ROOT_DIR/$REL_OUTPUT" ]]; then
    echo "[FAIL] output missing for root-dir execution"
    exit 1
  fi

  assert_overdue_one "$ROOT_DIR/$REL_OUTPUT"

  rm -f "$ROOT_DIR/$REL_OUTPUT"

  # Key contract: should still resolve relative --root and relative --output under project root.
  (cd /tmp && bash "$SCRIPT" \
    --root "$ARTIFACT_REL" \
    --today "$TODAY" \
    --days 7 \
    --output "$REL_OUTPUT" >/dev/null)

  if [[ ! -f "$ROOT_DIR/$REL_OUTPUT" ]]; then
    echo "[FAIL] output should be resolved under project root for relative --output"
    exit 1
  fi

  assert_overdue_one "$ROOT_DIR/$REL_OUTPUT"

  echo "[PASS] path resolution contract passed"
}

run_strict_contract() {
  rm -rf "$ROOT_DIR/$WORK_REL"
  mkdir -p "$ROOT_DIR/$WORK_REL"

  write_fixtures "run_overdue_1" "2026-02-10"

  rm -f "$ROOT_DIR/$REL_OUTPUT"

  if (cd /tmp && bash "$SCRIPT" \
    --root "$ARTIFACT_REL" \
    --today "$TODAY" \
    --days 7 \
    --output "$REL_OUTPUT" \
    --strict >/dev/null 2>&1); then
    echo "[FAIL] strict mode should fail when overdue holds exist"
    exit 1
  fi

  if [[ ! -f "$ROOT_DIR/$REL_OUTPUT" ]]; then
    echo "[FAIL] strict mode should still write report under project root"
    exit 1
  fi

  assert_overdue_one "$ROOT_DIR/$REL_OUTPUT"

  echo "[PASS] strict mode contract passed"
}

case "${1:-}" in
  --strict-check)
    run_strict_contract
    ;;
  *)
    run_path_contract
    ;;
esac

