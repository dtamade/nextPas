#!/usr/bin/env sh

set -eu

case "$0" in
  */*) SCRIPT_PATH="$0" ;;
  *) SCRIPT_PATH="./$0" ;;
esac

SCRIPT_DIR=$(CDPATH= cd -- "${SCRIPT_PATH%/*}" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/../.." && pwd)
WORKTREES_DOC="$REPO_ROOT/docs/worktrees.md"

require_doc_pattern() {
  pattern="$1"
  description="$2"

  if ! grep -Eq "$pattern" "$WORKTREES_DOC"; then
    printf 'missing worktrees doc contract: %s\n' "$description" >&2
    exit 1
  fi
}

require_doc_pattern 'make test-tooling' 'tooling replacement gate'
require_doc_pattern '(\.github|CI).*make test-tooling|make test-tooling.*(\.github|CI)' 'CI changes use tooling gate'
require_doc_pattern '(scripts|tests/tooling|docs/worktrees[.]md).*make test-tooling|make test-tooling.*(scripts|tests/tooling|docs/worktrees[.]md)' 'tooling/docs changes use tooling gate'
require_doc_pattern 'make landing-check' 'landing check command'
require_doc_pattern 'LANE=system' 'landing check lane example'
require_doc_pattern 'FOCUS.*优先|优先.*FOCUS' 'explicit focus wins over lane'
require_doc_pattern 'LANE.*local/reporting helper|local/reporting helper.*LANE' 'landing check lane helper boundary'
require_doc_pattern 'CI matrix' 'lane helper is not CI matrix'

printf 'worktrees-doc-contract=pass\n'
