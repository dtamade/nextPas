#!/usr/bin/env sh
# Source-contract: stage0 FPC flags have one owner file and all consumers source it.

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
FLAGS_FILE="$REPO_ROOT/scripts/stage0-fpc-flags.sh"
REBUILD="$REPO_ROOT/scripts/rebuild-compiler.sh"
VERIFY_LOCAL="$REPO_ROOT/build/verify_local.sh"
RUN_ALL="$REPO_ROOT/tests/run_all_tests.sh"

require_file() {
  if [ ! -f "$1" ]; then
    printf 'missing stage0 flags contract: %s\n' "$2" >&2
    exit 1
  fi
}

require_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  if ! grep -Eq "$pattern" "$file"; then
    printf 'missing stage0 flags contract: %s\n' "$description" >&2
    exit 1
  fi
}

reject_pattern() {
  file="$1"
  pattern="$2"
  description="$3"
  if grep -Eq "$pattern" "$file"; then
    printf 'forbidden stage0 flags contract: %s\n' "$description" >&2
    exit 1
  fi
}

require_file "$FLAGS_FILE" 'scripts/stage0-fpc-flags.sh'
require_pattern "$FLAGS_FILE" 'STAGE0_FPC_FLAGS=' 'canonical STAGE0_FPC_FLAGS definition'
require_pattern "$FLAGS_FILE" 'Fucompiler/lower' 'lower unit path in canonical flags'
require_pattern "$FLAGS_FILE" 'Fucore/src' 'core/src unit path in canonical flags'
require_pattern "$FLAGS_FILE" 'Ficore/src' 'core/src include path in canonical flags'

require_pattern "$REBUILD" 'stage0-fpc-flags\.sh' 'rebuild-compiler sources shared flags'
require_pattern "$VERIFY_LOCAL" 'stage0-fpc-flags\.sh' 'verify_local sources shared flags'
require_pattern "$RUN_ALL" 'stage0-fpc-flags\.sh' 'run_all_tests sources shared flags'

# Consumers must not re-define the long flag string inline (drift magnet).
reject_pattern "$REBUILD" '^STAGE0_FPC_FLAGS="-Fucompiler' 'rebuild-compiler must not inline STAGE0_FPC_FLAGS'
reject_pattern "$VERIFY_LOCAL" '^STAGE0_FPC_FLAGS="-Fucompiler' 'verify_local must not inline STAGE0_FPC_FLAGS'
reject_pattern "$RUN_ALL" '^STAGE0_FPC_FLAGS="-Fucompiler' 'run_all_tests must not inline STAGE0_FPC_FLAGS'

# shellcheck disable=SC1090
. "$FLAGS_FILE"
case " $STAGE0_FPC_FLAGS " in
  *" -Fucompiler/lower "*) ;;
  *)
    printf 'stage0 flags contract failed: -Fucompiler/lower missing from loaded flags\n' >&2
    exit 1
    ;;
esac
case " $STAGE0_FPC_FLAGS " in
  *" -Fucore/src "*) ;;
  *)
    printf 'stage0 flags contract failed: -Fucore/src missing from loaded flags\n' >&2
    exit 1
    ;;
esac

printf 'stage0-fpc-flags-contract=pass\n'
