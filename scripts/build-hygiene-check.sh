#!/usr/bin/env sh

set -eu

case "$0" in
  */*)
    SCRIPT_PATH="$0"
    ;;
  *)
    SCRIPT_PATH="./$0"
    ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
WORKTREE_FILE=$(mktemp)
TRACKED_FILE=$(mktemp)
MODE="${1:-check}"

cleanup() {
  rm -f "$WORKTREE_FILE" "$TRACKED_FILE"
}

trap cleanup EXIT INT TERM HUP

case "$MODE" in
  check|clean-source-artifacts)
    ;;
  *)
    printf 'usage: %s [check|clean-source-artifacts]\n' "$0" >&2
    exit 2
    ;;
esac

scan_root() {
  ROOT_PATH="$1"
  if [ -e "$REPO_ROOT/$ROOT_PATH" ]; then
    find "$REPO_ROOT/$ROOT_PATH" \
      \( -name .nextpas -o \
         -name .sisyphus -o \
         -name build -o \
         -name .worktrees \) -prune -o \
      -type f \( \
        -name '*.o' -o \
        -name '*.ppu' -o \
        -name '*.compiled' -o \
        -name 'link*.res' -o \
        -name '*.test.res' -o \
        -name '*.pyc' -o \
        -name '*.exe' -o \
        -name '*.dll' -o \
        -name '*.so' -o \
        -name '*.dylib' -o \
        -name '*.a' -o \
        -name 'libimp*.a' -o \
        -name 'ppas.sh' \
      \) -print

    find "$REPO_ROOT/$ROOT_PATH" \
      \( -name .nextpas -o \
         -name .sisyphus -o \
         -name build -o \
         -name .worktrees \) -prune -o \
      -type f \( \
        -path "$REPO_ROOT/tests/harness/runner" -o \
        -path "$REPO_ROOT/tools/stage0/nextpas" -o \
        -path "$REPO_ROOT/tests/compiler/pass/*_pass" -o \
        -path "$REPO_ROOT/tests/compiler/fail/*_fail" -o \
        -path "$REPO_ROOT/tests/rtl/*_smoke" -o \
        -path "$REPO_ROOT/tests/crt/*_smoke" -o \
        -path "$REPO_ROOT/tests/regression/*_regression" -o \
        -path "$REPO_ROOT/tests/toolchain/*_smoke" -o \
        -path "$REPO_ROOT/tests/*/test_*/test_*" -o \
        -path "$REPO_ROOT/core/tests/*/test_*/test_*" -o \
        -path "$REPO_ROOT/core/tests/*/*/test_*" -o \
        -path "$REPO_ROOT/benchmarks/*/bench_*" -o \
        -path "$REPO_ROOT/benchmarks/*/bench_*/*" -o \
        -path "$REPO_ROOT/core/benchmarks/*/bench_*/bench_*" -o \
        -path "$REPO_ROOT/core/benchmarks/*/compare_go/bench_*" -o \
        -path "$REPO_ROOT/core/benchmarks/*/compare_rust/bench_*" -o \
        -path "$REPO_ROOT/core/benchmarks/*/compare_fpcrtl/bench_*" -o \
        -path "$REPO_ROOT/core/benchmarks/platform-comparison/*/bench_compare" -o \
        -path "$REPO_ROOT/examples/smoke/hello" -o \
        -path "$REPO_ROOT/examples/smoke/hello_with_units" -o \
        -path "$REPO_ROOT/rtl/core/sysutils/np_sysutils_test" \
      \) \
      ! -name '*.*' \
      -print
  fi
}

collect_source_artifacts() {
  : >"$WORKTREE_FILE"
  for ROOT_PATH in compiler core benchmarks tests examples rtl scripts tools units; do
    scan_root "$ROOT_PATH" >>"$WORKTREE_FILE"
  done
}

collect_tracked_artifacts() {
  git -C "$REPO_ROOT" ls-files | grep -E '(^|/)([^/]+\.o|[^/]+\.ppu|[^/]+\.compiled|link[^/]*\.res|[^/]+\.test\.res|ppas\.sh|[^/]+\.pyc|[^/]+\.exe|[^/]+\.dll|[^/]+\.so|[^/]+\.dylib|libimp[^/]*\.a|[^/]+\.a)$' >"$TRACKED_FILE" || true
}

collect_source_artifacts
collect_tracked_artifacts

if [ "$MODE" = "clean-source-artifacts" ]; then
  if [ -s "$WORKTREE_FILE" ]; then
    while IFS= read -r artifact_path; do
      rm -f "$artifact_path"
    done <"$WORKTREE_FILE"
  fi
  if [ -s "$TRACKED_FILE" ]; then
    printf 'tracked generated artifacts:\n'
    sort "$TRACKED_FILE"
    printf 'build-artifact-clean=failed\n' >&2
    exit 1
  fi
  printf 'build-artifact-clean=pass\n'
  exit 0
fi

FAILED=0

if [ -s "$WORKTREE_FILE" ]; then
  printf 'source build artifacts:\n'
  sed "s#^$REPO_ROOT/##" "$WORKTREE_FILE" | sort
  FAILED=1
fi

if [ -s "$TRACKED_FILE" ]; then
  printf 'tracked generated artifacts:\n'
  sort "$TRACKED_FILE"
  FAILED=1
fi

if [ "$FAILED" -ne 0 ]; then
  printf 'build-hygiene=failed\n' >&2
  exit 1
fi

printf 'build-hygiene=pass\n'
