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
ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
OUT="$ROOT/build/stage0-bootstrap"
# shellcheck source=stage0-fpc-flags.sh
. "$SCRIPT_DIR/stage0-fpc-flags.sh"

mkdir -p "$OUT"

rm -f "$OUT"/*.ppu "$OUT"/*.o
rm -f "$ROOT"/rtl/core/base/*.ppu "$ROOT"/rtl/core/base/*.o
rm -f "$ROOT"/rtl/core/text/*.ppu "$ROOT"/rtl/core/text/*.o
rm -f "$ROOT"/core/src/*.ppu "$ROOT"/core/src/*.o

(
  cd "$ROOT"
  fpc $STAGE0_FPC_FLAGS -FE"$OUT" -FU"$OUT" tools/stage0/nextpas.pas
)

if [ ! -x "$OUT/nextpas" ]; then
  printf 'rebuild-compiler-failure: missing stage0 binary at %s\n' "$OUT/nextpas" >&2
  exit 1
fi

printf 'rebuild-compiler=pass\n'
