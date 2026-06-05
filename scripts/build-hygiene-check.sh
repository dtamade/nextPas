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

cleanup() {
  rm -f "$WORKTREE_FILE" "$TRACKED_FILE"
}

trap cleanup EXIT INT TERM HUP

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
  fi
}

for ROOT_PATH in compiler core benchmarks tests examples rtl tools units; do
  scan_root "$ROOT_PATH" >>"$WORKTREE_FILE"
done

git -C "$REPO_ROOT" ls-files | grep -E '(^|/)([^/]+\.o|[^/]+\.ppu|[^/]+\.compiled|link[^/]*\.res|[^/]+\.test\.res|ppas\.sh|[^/]+\.pyc|[^/]+\.exe|libimp[^/]*\.a|[^/]+\.a)$' >"$TRACKED_FILE" || true

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
