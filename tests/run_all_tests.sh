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
RUNNER_BUILD_DIR="$REPO_ROOT/.sisyphus/tmp/harness/bootstrap"
RUNNER_BINARY="$RUNNER_BUILD_DIR/runner"
STAGE0_SOURCE="$REPO_ROOT/tools/stage0/nextpas.pas"
STAGE0_BUILD_DIR="$REPO_ROOT/.sisyphus/tmp/stage0-bootstrap"
STAGE0_BINARY="$STAGE0_BUILD_DIR/nextpas"
STAGE0_FPC_FLAGS="-Fucompiler/frontend -Fucompiler/diagnostics -Fucompiler/targets -Fucompiler/syntax -Fucompiler/sema -Fucompiler/ir -Fucompiler/backend -Fucompiler/toolchain -Futools/stage0 -Furtl/core/base -Furtl/core/text"
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
  runner_build_command="fpc -FE$RUNNER_BUILD_DIR -FU$RUNNER_BUILD_DIR tests/harness/runner.pas"
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
    if ! (
      cd "$REPO_ROOT" &&
      fpc -FE"$RUNNER_BUILD_DIR" -FU"$RUNNER_BUILD_DIR" tests/harness/runner.pas \
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

ensure_stage0() {
  stage0_build_command="fpc $STAGE0_FPC_FLAGS -FE$STAGE0_BUILD_DIR -FU$STAGE0_BUILD_DIR tools/stage0/nextpas.pas"
  stage0_stderr_file="$STAGE0_BUILD_DIR/stage0-build.stderr.txt"
  if ! command -v fpc >/dev/null 2>&1; then
    emit_bootstrap_failure \
      'missing compiler for stage0 bootstrap' \
      'missing-compiler' \
      'missing-compiler: fpc'
  fi

  mkdir -p "$STAGE0_BUILD_DIR"
  rm -f "$stage0_stderr_file"
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
}

ensure_stage0
ensure_runner
cd "$REPO_ROOT"
export NEXTPAS_STAGE0="${NEXTPAS_STAGE0:-$STAGE0_BINARY}"
export NEXTPAS_WORKSPACE_ROOT="${NEXTPAS_WORKSPACE_ROOT:-$REPO_ROOT}"
export NEXTPAS_REPO_ROOT="${NEXTPAS_REPO_ROOT:-$REPO_ROOT}"
exec "$RUNNER_BINARY" "$@"
