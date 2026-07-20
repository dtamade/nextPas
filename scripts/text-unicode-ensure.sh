#!/usr/bin/env bash
# Ensure text-unicode M1+ surface is present on current tree (guards concurrent main reset).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fail=0
need=(
  "core/docs/text/unicode/ROADMAP.md"
  "core/docs/text/unicode/SCORECARD.md"
  "core/tests/nextpas.core.text.unicode/Makefile"
  "core/src/nextpas.core.text.unicode.collate.pas"
  "core/src/nextpas.core.text.unicode.casefold.pas"
)
for f in "${need[@]}"; do
  if [[ ! -f "$ROOT/$f" ]]; then
    echo "MISSING: $f"
    fail=1
  fi
done
if ! grep -q 'UTF8ToTitleWords' "$ROOT/core/src/nextpas.core.text.unicode.casefold.pas" 2>/dev/null; then
  echo "MISSING: UTF8ToTitleWords in casefold.pas (M2)"
  fail=1
fi
if ! grep -q 'GAsciiCE\|CollectElementsInto' "$ROOT/core/src/nextpas.core.text.unicode.collate.pas" 2>/dev/null; then
  echo "MISSING: Collate M3b symbols"
  fail=1
fi
if ! grep -q 'function gate\|gate:' "$ROOT/core/tests/nextpas.core.text.unicode/Makefile" 2>/dev/null; then
  echo "MISSING: make gate target"
  fail=1
fi
if [[ $fail -ne 0 ]]; then
  echo "text-unicode-ensure: FAIL — re-cherry-pick M1–M3b from history"
  exit 1
fi
echo "text-unicode-ensure: OK"
