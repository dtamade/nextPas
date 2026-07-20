#!/usr/bin/env bash
# Ensure text-unicode surface is present on current tree (guards concurrent main reset).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
need=(
  "core/docs/text/unicode/ROADMAP.md"
  "core/docs/text/unicode/SCORECARD.md"
  "core/docs/text/ERROR_MODEL.md"
  "core/tests/nextpas.core.text.unicode/Makefile"
  "core/src/nextpas.core.text.unicode.collate.pas"
  "core/src/nextpas.core.text.unicode.casefold.pas"
  "core/src/nextpas.core.text.unicode.idna.pas"
  "core/src/nextpas.core.text.unicode.script_extensions.inc"
  "core/src/nextpas.core.text.unicode.idna_mapping.inc"
)
for f in "${need[@]}"; do
  if [[ ! -f "$ROOT/$f" ]]; then
    echo "MISSING: $f"
    fail=1
  fi
done
check_grep() {
  local file="$1" pat="$2" msg="$3"
  if ! grep -qE "$pat" "$ROOT/$file" 2>/dev/null; then
    echo "MISSING: $msg"
    fail=1
  fi
}
check_grep "core/src/nextpas.core.text.unicode.casefold.pas" 'UTF8ToTitleWords' 'UTF8ToTitleWords in casefold.pas (M2)'
check_grep "core/src/nextpas.core.text.unicode.collate.pas" 'GAsciiCE|CollectElementsInto' 'Collate M3b symbols'
check_grep "core/src/nextpas.core.text.unicode.collate.pas" 'FCollatorLock|IMutex' 'Collate IMutex (P0-RTL)'
check_grep "core/src/nextpas.core.text.unicode.bidi.pas" 'ReorderBidiVisually' 'Bidi visual APIs (P2-3)'
check_grep "core/src/nextpas.core.text.unicode.script.pas" 'GetScriptExtensions' 'Script_Extensions (P2-4)'
check_grep "core/src/nextpas.core.text.unicode.idna.pas" 'TIDNAErrorKind' 'TIDNAErrorKind (P3-0)'
check_grep "core/src/nextpas.core.text.unicode.idna.pas" 'ApplyIdnaMap|IDNA_MAP_RANGES' 'IdnaMappingTable (P3-1)'
check_grep "core/docs/text/ERROR_MODEL.md" 'L0|L1|L2|TIDNAErrorKind' 'ERROR_MODEL P3-2'
check_grep "core/tests/nextpas.core.text.unicode/Makefile" 'function gate|gate:' 'make gate target'
if [[ $fail -ne 0 ]]; then
  echo "text-unicode-ensure: FAIL — re-cherry-pick text-unicode history"
  exit 1
fi
echo "text-unicode-ensure: OK"
