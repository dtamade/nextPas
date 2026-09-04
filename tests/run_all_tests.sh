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
RUNNER_SOURCE="$REPO_ROOT/tests/harness/runner.pas"
RUNNER_SUPPORT_SOURCE="$REPO_ROOT/tests/harness/snapshot_support.pas"
RUNNER_BUILD_DIR="$REPO_ROOT/build/harness/bootstrap"
RUNNER_BINARY="$RUNNER_BUILD_DIR/runner"
STAGE0_SOURCE="$REPO_ROOT/tools/stage0/nextpas.pas"
STAGE0_BUILD_DIR="$REPO_ROOT/build/stage0-bootstrap"
STAGE0_BINARY="$STAGE0_BUILD_DIR/nextpas"
# shellcheck source=../scripts/stage0-fpc-flags.sh
. "$REPO_ROOT/scripts/stage0-fpc-flags.sh"
# Source dirs feeding the stage0 build; mirrors STAGE0_FPC_FLAGS -Fu entries.
# Keep in sync when compiler/core layout moves (same drift class as HOST_UNIT_SEARCH_FLAGS).
STAGE0_SOURCE_DIRS="compiler/src compiler/frontend compiler/diagnostics compiler/targets compiler/syntax compiler/sema compiler/lower compiler/ir compiler/backend compiler/toolchain tools/stage0 rtl/core/base rtl/core/text core/src"
BASELINE_TARGET="linux-x86_64"

emit_bootstrap_failure() {
  human_summary="$1"
  failure_kind="$2"
  message="$3"
  bootstrap_step="${4:-}"
  bootstrap_command="${5:-}"
  bootstrap_stderr_file="${6:-}"

  printf 'command=test\n' >&2
  printf 'selector=bootstrap\n' >&2
  printf 'target=%s\n' "$BASELINE_TARGET" >&2
  printf 'status=failure\n' >&2
  printf 'result=failure\n' >&2
  printf 'failure-kind=%s\n' "$failure_kind" >&2
  printf 'command-outcome=failure\n' >&2
  printf 'command-envelope={"command":"test","exitCode":1,"result":{"selector":"bootstrap","target":"%s","status":"failure","result":"failure","failureKind":"%s"},"diagnostics":[],"buildTraceRef":null,"humanSummary":"%s"}\n' "$BASELINE_TARGET" "$failure_kind" "$human_summary" >&2
  printf 'human-summary=%s\n' "$human_summary" >&2
  if [ -n "$bootstrap_step" ]; then
    printf 'bootstrap-step=%s\n' "$bootstrap_step" >&2
  fi
  if [ -n "$bootstrap_command" ]; then
    printf 'bootstrap-command=%s\n' "$bootstrap_command" >&2
  fi
  if [ -n "$bootstrap_stderr_file" ]; then
    printf 'bootstrap-stderr-file=%s\n' "$bootstrap_stderr_file" >&2
    if [ -s "$bootstrap_stderr_file" ]; then
      cat "$bootstrap_stderr_file" >&2
    fi
  fi
  printf '%s\n' "$message" >&2
  exit 1
}

ensure_runner() {
  runner_build_command="fpc -Fucore/src -Ficore/src -FE$RUNNER_BUILD_DIR -FU$RUNNER_BUILD_DIR tests/harness/runner.pas"
  runner_stderr_file="$RUNNER_BUILD_DIR/harness-runner-build.stderr.txt"
  if [ ! -x "$RUNNER_BINARY" ] || [ "$RUNNER_SOURCE" -nt "$RUNNER_BINARY" ] || [ "$RUNNER_SUPPORT_SOURCE" -nt "$RUNNER_BINARY" ]; then
    if ! command -v fpc >/dev/null 2>&1; then
      emit_bootstrap_failure \
        'missing compiler for harness runner' \
        'missing-compiler' \
        'missing-compiler: fpc'
    fi

    mkdir -p "$RUNNER_BUILD_DIR"
    rm -f "$runner_stderr_file"
    # Same half-stale-cache crash class as stage0 (EListError in fpc itself):
    # clean before (re)build so a rotten .ppu can never crash the compile.
    rm -f "$RUNNER_BUILD_DIR"/*.ppu "$RUNNER_BUILD_DIR"/*.o "$RUNNER_BUILD_DIR"/*.a "$RUNNER_BUILD_DIR"/*.res
    if ! (
      cd "$REPO_ROOT" &&
      fpc -Fucore/src -Ficore/src -FE"$RUNNER_BUILD_DIR" -FU"$RUNNER_BUILD_DIR" tests/harness/runner.pas \
        >/dev/null 2>"$runner_stderr_file"
    ); then
      emit_bootstrap_failure \
        'failed to build harness runner' \
        'harness-runner-build-failed' \
        'harness-runner-build-failed' \
        'harness-runner-build' \
        "$runner_build_command" \
        "$runner_stderr_file"
    fi
  fi
}

stage0_compute_fingerprint() {
  {
    printf '%s\n' "$STAGE0_FPC_FLAGS"
    fpc -iV
    for stage0_dir in $STAGE0_SOURCE_DIRS; do
      if [ -d "$REPO_ROOT/$stage0_dir" ]; then
        find "$REPO_ROOT/$stage0_dir" -type f \( -name '*.pas' -o -name '*.inc' -o -name '*.pp' \) -print0
      fi
    done | sort -z | xargs -0 -r sha256sum
  } | sha256sum | awk '{print $1}'
}

stage0_fingerprint_matches() {
  [ -f "$stage0_fingerprint_file" ] &&
    [ "$(stage0_compute_fingerprint)" = "$(cat "$stage0_fingerprint_file")" ]
}

ensure_stage0() {
  stage0_build_command="fpc $STAGE0_FPC_FLAGS -FE$STAGE0_BUILD_DIR -FU$STAGE0_BUILD_DIR tools/stage0/nextpas.pas"
  stage0_stderr_file="$STAGE0_BUILD_DIR/stage0-build.stderr.txt"
  stage0_fingerprint_file="$STAGE0_BUILD_DIR/.source-fingerprint"
  if ! command -v fpc >/dev/null 2>&1; then
    emit_bootstrap_failure \
      'missing compiler for stage0 bootstrap' \
      'missing-compiler' \
      'missing-compiler: fpc'
  fi

  mkdir -p "$STAGE0_BUILD_DIR"
  rm -f "$stage0_stderr_file"
  # Content-hash skip: inputs provably unchanged since last successful build
  # means a rebuild would produce a byte-identical driver, so skip it.
  # Any mismatch (sources, flags, fpc version, missing file) falls through
  # to a clean rebuild; a torn fingerprint can only cause a rebuild, never
  # a false skip.
  if [ -x "$STAGE0_BINARY" ] && stage0_fingerprint_matches; then
    return 0
  fi
  # Drop cached .ppu/.o before rebuilding: fpc reuse of half-stale unit
  # caches has been observed to crash the compiler itself (EListError)
  # instead of recompiling, which turns every run into stage0-build-failed.
  # Same rationale as core/tests/common.mk build target.
  rm -f "$STAGE0_BUILD_DIR"/*.ppu "$STAGE0_BUILD_DIR"/*.o "$STAGE0_BUILD_DIR"/*.a "$STAGE0_BUILD_DIR"/*.res
  if ! (
    cd "$REPO_ROOT" &&
    fpc $STAGE0_FPC_FLAGS -FE"$STAGE0_BUILD_DIR" -FU"$STAGE0_BUILD_DIR" tools/stage0/nextpas.pas \
      >/dev/null 2>"$stage0_stderr_file"
  ); then
    emit_bootstrap_failure \
      'failed to build stage0 driver' \
      'stage0-build-failed' \
      'stage0-build-failed' \
      'stage0-build' \
      "$stage0_build_command" \
      "$stage0_stderr_file"
  fi
  stage0_compute_fingerprint >"$stage0_fingerprint_file"
}

ensure_stage0
ensure_runner
cd "$REPO_ROOT"
export NEXTPAS_STAGE0="${NEXTPAS_STAGE0:-$STAGE0_BINARY}"
export NEXTPAS_WORKSPACE_ROOT="${NEXTPAS_WORKSPACE_ROOT:-$REPO_ROOT}"
export NEXTPAS_REPO_ROOT="${NEXTPAS_REPO_ROOT:-$REPO_ROOT}"
exec "$RUNNER_BINARY" "$@"
