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
STAGE0_BINARY="$REPO_ROOT/build/stage0-bootstrap/nextpas"
TARGET_ID="${TARGET_ID:-linux-x86_64}"

escape_ere() {
  printf '%s' "$1" | sed 's/[][\\.^$*+?{}()|]/\\&/g'
}

fail() {
  printf 'c8-self-compile-probe=%s\n' "$1" >&2
  exit 1
}

require_output_pattern() {
  PATTERN="$1"
  FILE="$2"
  LABEL="$3"
  if ! grep -Eq "$PATTERN" "$FILE"; then
    cat "$FILE"
    fail "$LABEL"
  fi
}

if [ "$#" -ne 1 ]; then
  fail 'usage: probe_self_compile_module.sh <module-path>'
fi

MODULE_PATH="$1"
MODULE_NAME=$(basename "$MODULE_PATH" .pas)
MODULE_PATTERN=$(escape_ere "$MODULE_NAME")
OUTPUT=$(mktemp)

cleanup() {
  rm -f "$OUTPUT"
}

trap cleanup EXIT INT TERM HUP

if [ ! -x "$STAGE0_BINARY" ]; then
  fail 'missing-stage0-binary-run-make-rebuild-compiler-first'
fi

printf 'c8-self-compile-probe=running\n'
printf 'c8-self-compile-module=%s\n' "$MODULE_PATH"
printf 'c8-self-compile-command=%s build %s --fold --target %s --workspace %s\n' "$STAGE0_BINARY" "$MODULE_PATH" "$TARGET_ID" "$REPO_ROOT"
if ! "$STAGE0_BINARY" build "$MODULE_PATH" --fold --target "$TARGET_ID" --workspace "$REPO_ROOT" >"$OUTPUT" 2>&1; then
  cat "$OUTPUT"
  fail 'self-compile-build-failed'
fi

cat "$OUTPUT"
require_output_pattern '^status=success$' "$OUTPUT" 'missing-success-status'
require_output_pattern '^result=success$' "$OUTPUT" 'missing-success-result'
require_output_pattern '^command-outcome=success$' "$OUTPUT" 'missing-command-outcome'
require_output_pattern '^ast-root-kind=unit$' "$OUTPUT" 'missing-root-kind'
require_output_pattern '^backend-output-kind=object-file$' "$OUTPUT" 'missing-output-kind'
require_output_pattern '^backend-primary-artifact-kind=object-file$' "$OUTPUT" 'missing-primary-artifact-kind'
require_output_pattern "^artifact=.*/\\.nextpas/cache/backend/$TARGET_ID/$MODULE_PATTERN\\.o$" "$OUTPUT" 'missing-object-artifact'
require_output_pattern '^toolchain-plan-family=bootstrap-native-assemble$' "$OUTPUT" 'missing-plan-family'
require_output_pattern '^logical-link-request-status=deferred$' "$OUTPUT" 'missing-link-request-status'
require_output_pattern '^tool-invocation-count=2$' "$OUTPUT" 'missing-tool-invocation-count'
require_output_pattern '^tool-run-status=success$' "$OUTPUT" 'missing-tool-run-status'
require_output_pattern '^tool-run-step-count=2$' "$OUTPUT" 'missing-tool-run-step-count'
require_output_pattern '^human-summary=build succeeded$' "$OUTPUT" 'missing-human-summary'
require_output_pattern '^tool-invocation-plan=.*"planFamily":"bootstrap-native-assemble".*"stepId":"host-fpc-emit-asm".*"stepId":"native-assemble"' "$OUTPUT" 'missing-tool-plan'
if grep -Eq '"stepId":"native-link"' "$OUTPUT"; then
  cat "$OUTPUT"
  fail 'unexpected-native-link-step'
fi

printf 'c8-self-compile-probe=pass\n'
