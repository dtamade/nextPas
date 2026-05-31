#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

OUT_DIR="examples/bin"
mkdir -p "$OUT_DIR"

FPC_VERSION=$(fpc -iV)
FPC_BASE="/usr/lib/fpc/${FPC_VERSION}"
if [ ! -d "$FPC_BASE" ]; then
  FPC_BASE="$HOME/freePascal/fpc/units/x86_64-linux"
fi

UNIT_PATHS="-Fu${FPC_BASE}/rtl-objpas -Fu${FPC_BASE}/fcl-base -Fusrc"

echo "Building examples (*.lpr/*.pas) → $OUT_DIR"

shopt -s nullglob

count=0
for src in examples/*.lpr examples/*.pas; do
  base=$(basename "$src")
  name="${base%.*}"
  echo "[+] Compiling $src"
  if fpc $UNIT_PATHS -FE"$OUT_DIR" "$src" >/tmp/example_build.log 2>&1; then
    echo "    OK -> $OUT_DIR/$name"
    count=$((count+1))
  else
    echo "    SKIP (build failed)"
    head -5 /tmp/example_build.log || true
  fi
done

echo "Done. Built $count example(s)."


