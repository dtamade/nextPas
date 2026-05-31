#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/scan_active_docs_noise_draft.sh"
REL_WORK="tmp/test_scan_active_docs_noise_contract"
REL_DOCS_ROOT="$REL_WORK/docs"
REL_OUTPUT="$REL_WORK/reports/active_docs_noise.md"

fail() {
  echo "[FAIL] $1"
  exit 1
}

assert_contains() {
  local file="$1"
  local pattern="$2"
  if ! rg -F --quiet "$pattern" "$file"; then
    echo "[FAIL] missing expected pattern: $pattern"
    echo "[INFO] top of output ($file):"
    sed -n '1,160p' "$file" || true
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local pattern="$2"
  if rg -F --quiet "$pattern" "$file"; then
    echo "[FAIL] unexpected pattern found: $pattern"
    echo "[INFO] top of output ($file):"
    sed -n '1,160p' "$file" || true
    exit 1
  fi
}

write_fixtures() {
  rm -rf "$ROOT_DIR/$REL_WORK"
  mkdir -p "$ROOT_DIR/$REL_DOCS_ROOT/guides"
  mkdir -p "$ROOT_DIR/$REL_DOCS_ROOT/plans"
  mkdir -p "$ROOT_DIR/$REL_DOCS_ROOT/test_reports"
  mkdir -p "$ROOT_DIR/$REL_DOCS_ROOT/archive"

  cat > "$ROOT_DIR/$REL_DOCS_ROOT/guides/active.md" <<'EOF_ACTIVE'
# Active Doc
TODO: this should be detected
EOF_ACTIVE

  cat > "$ROOT_DIR/$REL_DOCS_ROOT/plans/plan.md" <<'EOF_PLAN'
# Historical Plan
TODO: this should be excluded
EOF_PLAN

  cat > "$ROOT_DIR/$REL_DOCS_ROOT/test_reports/report.md" <<'EOF_REPORT'
# Historical Report
TODO: this should be excluded
EOF_REPORT

  cat > "$ROOT_DIR/$REL_DOCS_ROOT/archive/legacy.md" <<'EOF_ARCHIVE'
# Historical Archive
TODO: this should be excluded
EOF_ARCHIVE

  cat > "$ROOT_DIR/$REL_DOCS_ROOT/DOCS_NOISE_GOVERNANCE.md" <<'EOF_POLICY'
# Policy
TODO: this should be excluded by default
EOF_POLICY
}

assert_report_shape() {
  local report="$1"
  assert_contains "$report" "| total_hits | 1 |"
  assert_contains "$report" "guides/active.md"
  assert_not_contains "$report" "plans/plan.md"
  assert_not_contains "$report" "test_reports/report.md"
  assert_not_contains "$report" "archive/legacy.md"
  assert_not_contains "$report" "DOCS_NOISE_GOVERNANCE.md"
}

run_path_contract() {
  write_fixtures
  rm -f "$ROOT_DIR/$REL_OUTPUT" "/tmp/$REL_OUTPUT"

  if (cd /tmp && bash "$SCRIPT" \
    --docs-root "$REL_DOCS_ROOT" \
    --output "$REL_OUTPUT" >/dev/null 2>&1); then
    :
  else
    fail "script should succeed without --strict when hits exist"
  fi

  [[ -f "$ROOT_DIR/$REL_OUTPUT" ]] || fail "output report should be written under project root"
  [[ ! -f "/tmp/$REL_OUTPUT" ]] || fail "output should not leak into /tmp"

  assert_report_shape "$ROOT_DIR/$REL_OUTPUT"
  echo "[PASS] path resolution contract passed"
}

run_strict_contract() {
  write_fixtures
  rm -f "$ROOT_DIR/$REL_OUTPUT" "/tmp/$REL_OUTPUT"

  if (cd /tmp && bash "$SCRIPT" \
    --docs-root "$REL_DOCS_ROOT" \
    --output "$REL_OUTPUT" \
    --strict >/dev/null 2>&1); then
    fail "strict mode should fail when active docs noise hits exist"
  fi

  [[ -f "$ROOT_DIR/$REL_OUTPUT" ]] || fail "strict mode should still write report under project root"
  [[ ! -f "/tmp/$REL_OUTPUT" ]] || fail "strict mode output leaked into /tmp"

  assert_report_shape "$ROOT_DIR/$REL_OUTPUT"
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
