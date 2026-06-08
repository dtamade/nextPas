#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
TMP_ROOT=$(mktemp -d)

cleanup() {
  rm -rf "$TMP_ROOT"
}

trap cleanup EXIT INT TERM HUP

SCRIPT_UNDER_TEST="$REPO_ROOT/scripts/report-envelope-check.sh"

expect_failure() {
  description="$1"
  shift
  if "$@" >"$TMP_ROOT/failure.out" 2>"$TMP_ROOT/failure.err"; then
    printf 'expected failure: %s\n' "$description" >&2
    cat "$TMP_ROOT/failure.out" >&2
    cat "$TMP_ROOT/failure.err" >&2
    exit 1
  fi
}

cat >"$TMP_ROOT/ready.md" <<'EOF'
Ready

branch: codex/core-tests-tooling-ci-report-envelope-20260608
worktree: /tmp/worktrees/report
HEAD: 0123456789abcdef
retained files:
- scripts/report-envelope-check.sh
excluded files:
- core/src/*
verification:
- make test-tooling: pass
landing recommendation: cherry-pick this narrow slice
EOF

"$SCRIPT_UNDER_TEST" --status Ready "$TMP_ROOT/ready.md" | grep -q '^report-envelope=pass$'

cat >"$TMP_ROOT/ready-missing-head.md" <<'EOF'
Ready

branch: codex/core-tests-tooling-ci-report-envelope-20260608
worktree: /tmp/worktrees/report
retained files:
- scripts/report-envelope-check.sh
excluded files:
- core/src/*
verification:
- make test-tooling: pass
landing recommendation: cherry-pick this narrow slice
EOF

expect_failure "Ready missing HEAD" "$SCRIPT_UNDER_TEST" --status Ready "$TMP_ROOT/ready-missing-head.md"
grep -q 'missing required Ready field: HEAD' "$TMP_ROOT/failure.err"

cat >"$TMP_ROOT/blocked.md" <<'EOF'
Blocked

blocking condition: full gate failure repeats on clean latest main
attempted actions:
- reran focused gate
required owner decision: decide whether to split module owner boundary
EOF

"$SCRIPT_UNDER_TEST" --status Blocked "$TMP_ROOT/blocked.md" | grep -q '^report-envelope=pass$'

cat >"$TMP_ROOT/blocked-missing-owner.md" <<'EOF'
Blocked

blocking condition: full gate failure repeats on clean latest main
attempted actions:
- reran focused gate
EOF

expect_failure "Blocked missing owner decision" "$SCRIPT_UNDER_TEST" --status Blocked "$TMP_ROOT/blocked-missing-owner.md"
grep -q 'missing required Blocked field: required owner decision' "$TMP_ROOT/failure.err"

cat >"$TMP_ROOT/landed.md" <<'EOF'
Landed

main commit: 89abcdef01234567
verification:
- make test-tooling: pass
equivalent absorption/cleanup state: old candidate dropped, temp worktree removed
EOF

"$SCRIPT_UNDER_TEST" --status Landed "$TMP_ROOT/landed.md" | grep -q '^report-envelope=pass$'

cat >"$TMP_ROOT/landed-missing-cleanup.md" <<'EOF'
Landed

main commit: 89abcdef01234567
verification:
- make test-tooling: pass
EOF

expect_failure "Landed missing cleanup state" "$SCRIPT_UNDER_TEST" --status Landed "$TMP_ROOT/landed-missing-cleanup.md"
grep -q 'missing required Landed field: equivalent absorption/cleanup state' "$TMP_ROOT/failure.err"

expect_failure "unknown status" "$SCRIPT_UNDER_TEST" --status NeedsReview "$TMP_ROOT/ready.md"
grep -q 'unknown status: NeedsReview' "$TMP_ROOT/failure.err"

printf 'report-envelope-check=pass\n'
