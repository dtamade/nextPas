#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/check_docs_index_dedup_draft.sh"

WORK_REL="tmp/test_docs_index_dedup_contract"
REL_INDEX="$WORK_REL/DOCUMENTATION_INDEX.md"
REL_OUTPUT="$WORK_REL/dedup_report.md"

write_fixture_index() {
  rm -rf "$ROOT_DIR/$WORK_REL"
  mkdir -p "$ROOT_DIR/$WORK_REL"

  cat > "$ROOT_DIR/$REL_INDEX" <<'MD'
# Documentation Index (Fixture)

- [Doc A](archive/foo.md)
- [Doc B](archive/foo.md)
- [Same Title](plans/PHASE4_X.md)
- [Same Title](plans/PHASE4_Y.md)
MD
}

assert_metrics_warn() {
  local file="$1"
  if ! grep -qE "^\\| duplicate_paths \\| 1 \\|" "$file"; then
    echo "[FAIL] expected duplicate_paths=1 in report: $file"
    exit 1
  fi
  if ! grep -qE "^\\| duplicate_titles \\| 1 \\|" "$file"; then
    echo "[FAIL] expected duplicate_titles=1 in report: $file"
    exit 1
  fi
  if ! grep -qE "^\\| status \\| warn \\|" "$file"; then
    echo "[FAIL] expected status=warn in report: $file"
    exit 1
  fi
}

run_path_contract() {
  write_fixture_index
  rm -f "$ROOT_DIR/$REL_OUTPUT"

  (cd "$ROOT_DIR" && bash "$SCRIPT" \
    --index "$REL_INDEX" \
    --scope all \
    --output "$REL_OUTPUT" >/dev/null)

  if [[ ! -f "$ROOT_DIR/$REL_OUTPUT" ]]; then
    echo "[FAIL] output missing for root-dir execution"
    exit 1
  fi

  assert_metrics_warn "$ROOT_DIR/$REL_OUTPUT"

  rm -f "$ROOT_DIR/$REL_OUTPUT"

  # Key contract: should resolve relative --index and relative --output under project root when invoked from /tmp.
  (cd /tmp && bash "$SCRIPT" \
    --index "$REL_INDEX" \
    --scope all \
    --output "$REL_OUTPUT" >/dev/null)

  if [[ ! -f "$ROOT_DIR/$REL_OUTPUT" ]]; then
    echo "[FAIL] output should be resolved under project root for relative --output"
    exit 1
  fi

  assert_metrics_warn "$ROOT_DIR/$REL_OUTPUT"

  echo "[PASS] path resolution contract passed"
}

run_strict_contract() {
  write_fixture_index
  rm -f "$ROOT_DIR/$REL_OUTPUT"

  if (cd /tmp && bash "$SCRIPT" \
    --index "$REL_INDEX" \
    --scope all \
    --output "$REL_OUTPUT" \
    --strict >/dev/null 2>&1); then
    echo "[FAIL] strict mode should fail when duplicates exist"
    exit 1
  fi

  if [[ ! -f "$ROOT_DIR/$REL_OUTPUT" ]]; then
    echo "[FAIL] strict mode should still write report under project root"
    exit 1
  fi

  assert_metrics_warn "$ROOT_DIR/$REL_OUTPUT"

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

