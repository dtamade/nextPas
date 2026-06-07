#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
DOC="$REPO_ROOT/docs/architecture/ci-evidence-matrix.md"
ROOT_CI="$REPO_ROOT/.github/workflows/ci.yml"
CORE_CI="$REPO_ROOT/.github/workflows/core-ci.yml"

require_file() {
  file_path="$1"
  description="$2"

  if [ ! -f "$file_path" ]; then
    printf 'missing CI evidence matrix doc contract: %s\n' "$description" >&2
    exit 1
  fi
}

require_doc_pattern() {
  pattern="$1"
  description="$2"

  if ! grep -Eq "$pattern" "$DOC"; then
    printf 'missing CI evidence matrix doc contract: %s\n' "$description" >&2
    exit 1
  fi
}

require_workflow_command_documented() {
  workflow="$1"
  command="$2"
  description="$3"

  if ! grep -Fq "run: $command" "$workflow"; then
    printf 'CI evidence matrix workflow command missing from workflow: %s\n' "$description" >&2
    exit 1
  fi

  require_doc_pattern "$command" "$description"
}

require_file "$DOC" 'docs/architecture/ci-evidence-matrix.md'

require_doc_pattern 'CI Evidence Matrix' 'document title'
require_doc_pattern 'root CI|Linux Verification' 'root CI row'
require_doc_pattern 'core CI|Core CI' 'core CI row'
require_doc_pattern 'source-contract' 'source-contract truth type'
require_doc_pattern 'forced-compile' 'forced compile truth type'
require_doc_pattern 'runtime' 'runtime truth type'
require_doc_pattern 'CI truth' 'CI truth type'
require_doc_pattern 'local/reporting helper' 'lane helper boundary'
require_doc_pattern 'not.*CI matrix|不是.*CI matrix' 'lane-focused is not CI matrix'
require_doc_pattern 'best-effort' 'best-effort CI boundary'
require_doc_pattern 'make test-tooling.*make verify|make verify.*make test-tooling' 'tooling before verify relationship'

require_workflow_command_documented "$ROOT_CI" 'make test-tooling' 'root tooling command'
require_workflow_command_documented "$ROOT_CI" 'make verify' 'root verify command'
require_workflow_command_documented "$CORE_CI" 'make test' 'core test command'
require_workflow_command_documented "$CORE_CI" 'FPC=fpc benchmarks/nextpas.core.tui/run_all.sh' 'core TUI benchmark smoke command'

printf 'ci-evidence-matrix-doc-contract=pass\n'
