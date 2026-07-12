#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
VERIFY_INCREMENTAL="$REPO_ROOT/tests/regression/verify_incremental.sh"
MAKEFILE_PATH="$REPO_ROOT/Makefile"

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"

  if ! grep -Eq "$pattern" "$file"; then
    printf 'missing incremental gate truth: %s\n' "$description" >&2
    exit 1
  fi
}

reject_pattern() {
  file="$1"
  pattern="$2"
  description="$3"

  if grep -Eq "$pattern" "$file"; then
    printf 'stale incremental gate truth: %s\n' "$description" >&2
    exit 1
  fi
}

run_expect_fail() {
  description="$1"
  expected_pattern="$2"
  shift 2

  log_file=$(mktemp)
  if "$@" >"$log_file" 2>&1; then
    printf 'incremental gate unexpectedly passed: %s\n' "$description" >&2
    cat "$log_file" >&2
    rm -f "$log_file"
    exit 1
  fi

  if ! grep -Eq "$expected_pattern" "$log_file"; then
    printf 'incremental gate missing failure evidence: %s\n' "$description" >&2
    cat "$log_file" >&2
    rm -f "$log_file"
    exit 1
  fi

  rm -f "$log_file"
}

TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT HUP INT TERM

FIXTURE_PATH="$TMP_ROOT/fixture.pas"
cat >"$FIXTURE_PATH" <<'EOF'
program fixture;
begin
end.
EOF

FAKE_NO_ARTIFACT="$TMP_ROOT/fake-no-artifact.sh"
cat >"$FAKE_NO_ARTIFACT" <<'EOF'
#!/usr/bin/env sh
printf '%s\n' 'status=success'
printf '%s\n' 'result=success'
exit 0
EOF
chmod +x "$FAKE_NO_ARTIFACT"

FAKE_BAD_ARTIFACT="$TMP_ROOT/fake-bad-artifact.sh"
cat >"$FAKE_BAD_ARTIFACT" <<'EOF'
#!/usr/bin/env sh
out_dir=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    --out-dir)
      out_dir="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
printf 'artifact=%s\n' "$out_dir/missing-artifact"
printf '%s\n' 'status=success'
printf '%s\n' 'result=success'
exit 0
EOF
chmod +x "$FAKE_BAD_ARTIFACT"

FAKE_NO_CACHE="$TMP_ROOT/fake-no-cache.sh"
cat >"$FAKE_NO_CACHE" <<'EOF'
#!/usr/bin/env sh
workspace=''
out_dir=''
source_path=''
while [ "$#" -gt 0 ]; do
  case "$1" in
    build)
      shift
      source_path="$1"
      shift
      ;;
    --workspace)
      workspace="$2"
      shift 2
      ;;
    --out-dir)
      out_dir="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

mkdir -p "$out_dir"
artifact="$out_dir/$(basename "$source_path" .pas)"
cat >"$artifact" <<'ARTIFACT'
#!/usr/bin/env sh
exit 0
ARTIFACT
chmod +x "$artifact"
printf 'artifact=%s\n' "$artifact"
printf '%s\n' 'status=success'
printf '%s\n' 'result=success'
exit 0
EOF
chmod +x "$FAKE_NO_CACHE"

require_pattern "$VERIFY_INCREMENTAL" 'NEXTPAS_INCREMENTAL_STAGE0' 'stage0 override for fail-closed tooling tests'
require_pattern "$VERIFY_INCREMENTAL" 'NEXTPAS_INCREMENTAL_WORK_ROOT' 'private work-root override'
require_pattern "$VERIFY_INCREMENTAL" 'NEXTPAS_HARNESS_TEMP_ROOT' 'shared harness temp-root support'
require_pattern "$VERIFY_INCREMENTAL" 'sed -i' 'real source-content mutation instead of mtime-only touch'
require_pattern "$VERIFY_INCREMENTAL" 'incremental-cache-entry-missing' 'cache-entry presence failure kind'
require_pattern "$VERIFY_INCREMENTAL" 'artifact escaped out-dir' 'artifact confinement check'
reject_pattern "$VERIFY_INCREMENTAL" '^[[:space:]]*exit 0([[:space:]]|$)' 'skip-on-missing-stage0 behavior'
reject_pattern "$VERIFY_INCREMENTAL" 'SKIP:' 'skip marker'
reject_pattern "$VERIFY_INCREMENTAL" '[|][|] true' 'swallowed build or corruption failures'
reject_pattern "$VERIFY_INCREMENTAL" 'touch "\$TEST_SRC"' 'mtime-only source mutation'

require_pattern "$MAKEFILE_PATH" '^test-incremental-gate: hygiene$' 'incremental gate target'
require_pattern "$MAKEFILE_PATH" '^[[:space:]]+\./tests/regression/verify_incremental\.sh$' 'incremental gate runner'
require_pattern "$MAKEFILE_PATH" '^[[:space:]]+\$\(MAKE\) test-incremental-gate$' 'verify includes incremental gate'

run_expect_fail \
  'missing stage0 must fail closed' \
  'FAIL: stage0 compiler not found' \
  env \
    NEXTPAS_INCREMENTAL_STAGE0="$TMP_ROOT/missing-stage0" \
    NEXTPAS_INCREMENTAL_FIXTURE_SRC="$FIXTURE_PATH" \
    NEXTPAS_INCREMENTAL_WORK_ROOT="$TMP_ROOT/work-missing-stage0" \
    "$VERIFY_INCREMENTAL"

run_expect_fail \
  'build success without artifact projection must fail closed' \
  'produced no artifact= projection' \
  env \
    NEXTPAS_INCREMENTAL_STAGE0="$FAKE_NO_ARTIFACT" \
    NEXTPAS_INCREMENTAL_FIXTURE_SRC="$FIXTURE_PATH" \
    NEXTPAS_INCREMENTAL_WORK_ROOT="$TMP_ROOT/work-no-artifact" \
    "$VERIFY_INCREMENTAL"

run_expect_fail \
  'artifact projection without executable must fail closed' \
  'artifact not executable' \
  env \
    NEXTPAS_INCREMENTAL_STAGE0="$FAKE_BAD_ARTIFACT" \
    NEXTPAS_INCREMENTAL_FIXTURE_SRC="$FIXTURE_PATH" \
    NEXTPAS_INCREMENTAL_WORK_ROOT="$TMP_ROOT/work-bad-artifact" \
    "$VERIFY_INCREMENTAL"

run_expect_fail \
  'missing NPC cache entries must fail closed' \
  'no NPC cache entries found to corrupt' \
  env \
    NEXTPAS_INCREMENTAL_STAGE0="$FAKE_NO_CACHE" \
    NEXTPAS_INCREMENTAL_FIXTURE_SRC="$FIXTURE_PATH" \
    NEXTPAS_INCREMENTAL_WORK_ROOT="$TMP_ROOT/work-no-cache" \
    "$VERIFY_INCREMENTAL"

printf 'incremental-gate-truth=pass\n'
