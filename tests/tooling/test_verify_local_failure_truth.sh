#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
VERIFY_LOCAL="$REPO_ROOT/build/verify_local.sh"

require_verify_local_pattern() {
  pattern="$1"
  description="$2"

  if ! grep -Eq "$pattern" "$VERIFY_LOCAL"; then
    printf 'missing verify_local failure truth: %s\n' "$description" >&2
    exit 1
  fi
}

reject_verify_local_pattern() {
  pattern="$1"
  description="$2"

  if grep -Eq "$pattern" "$VERIFY_LOCAL"; then
    printf 'stale verify_local failure truth: %s\n' "$description" >&2
    exit 1
  fi
}

require_verify_local_pattern 'llvm-opt-failure-attribution-check=running' 'llvm opt failure check marker'
require_verify_local_pattern 'llvm-llc-failure-attribution-check=running' 'llvm llc failure check marker'
require_verify_local_pattern 'toolchain[.]llvm-opt-exec-failed' 'llvm opt failure mapping'
require_verify_local_pattern 'toolchain[.]llvm-llc-exec-failed' 'llvm llc failure mapping'
require_verify_local_pattern 'diagnostic-step-id=llvm-opt-bitcode' 'llvm opt diagnostic step'
require_verify_local_pattern 'diagnostic-step-id=llvm-llc-object' 'llvm llc diagnostic step'
require_verify_local_pattern 'diagnostic-logical-executable=opt' 'llvm opt logical executable'
require_verify_local_pattern 'diagnostic-logical-executable=llc' 'llvm llc logical executable'
require_verify_local_pattern 'diagnostic-exit-code=41' 'llvm opt fake exit code'
require_verify_local_pattern 'diagnostic-exit-code=43' 'llvm llc fake exit code'
require_verify_local_pattern '"llvmOptFailureAttributionCheck":"pass"' 'verify envelope llvm opt result'
require_verify_local_pattern '"llvmLlcFailureAttributionCheck":"pass"' 'verify envelope llvm llc result'
require_verify_local_pattern 'CORE_PLATFORM_TIME_WIN64_CHECK_STATUS=pass' 'time win64 pass status'
require_verify_local_pattern 'CORE_PLATFORM_TIME_WIN64_CHECK_STATUS=skip' 'time win64 skip status'
require_verify_local_pattern 'CORE_PLATFORM_THREAD_WIN64_CHECK_STATUS=pass' 'thread win64 pass status'
require_verify_local_pattern 'CORE_PLATFORM_THREAD_WIN64_CHECK_STATUS=skip' 'thread win64 skip status'
require_verify_local_pattern 'CORE_PLATFORM_SYNC_WIN64_CHECK_STATUS=pass' 'sync win64 pass status'
require_verify_local_pattern 'CORE_PLATFORM_SYNC_WIN64_CHECK_STATUS=skip' 'sync win64 skip status'
require_verify_local_pattern '"corePlatformTimeWin64Check":"%s"' 'time win64 envelope interpolation'
require_verify_local_pattern '"corePlatformThreadWin64Check":"%s"' 'thread win64 envelope interpolation'
require_verify_local_pattern '"corePlatformSyncWin64Check":"%s"' 'sync win64 envelope interpolation'
reject_verify_local_pattern '"corePlatformTimeWin64Check":"pass"' 'time win64 hard-coded pass'

printf 'verify-local-failure-truth=pass\n'
