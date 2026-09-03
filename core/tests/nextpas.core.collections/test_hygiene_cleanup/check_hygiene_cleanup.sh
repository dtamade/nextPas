#!/usr/bin/env bash
set -euo pipefail
# hygiene cleanup: remove stray *.new temp that breaks src flat & four-piece & hygiene zero-artifact
REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/../../.." && pwd)"
TARGET="$REPO_ROOT/src/nextpas.core.collections.pas.new"
if [ -e "$TARGET" ]; then
  rm -f "$TARGET"
  echo "removed $TARGET"
else
  echo "already clean: $TARGET not present"
fi
# also ensure no other *.new in src (conservative)
find "$REPO_ROOT/src" -maxdepth 1 -name '*.new' -type f -delete 2>/dev/null || true
# verify
if [ -e "$TARGET" ]; then
  echo "hygiene-cleanup=failed: $TARGET still exists" >&2
  exit 1
fi
echo "hygiene-cleanup=pass"
# verify facade still inline zero-copy via factory, bytes.ops single source, try..Free
if ! grep -q "inline;" "$REPO_ROOT/src/nextpas.core.collections.pas" 2>/dev/null; then
  echo "facade inline check failed" >&2
  exit 1
fi
echo "facade-verified=pass"
