#!/usr/bin/env bash
# Forbid direct FPC RTL unit uses in collections production sources and tests.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
CORE_SRC="$ROOT/core/src"
TEST_ROOT="$ROOT/core/tests/nextpas.core.collections"
FORBIDDEN='SysUtils|Classes|TypInfo|DateUtils|BaseUnix|Unix|Windows'

fail_count=0

scan_file() {
  local file="$1"
  local rel="${file#$ROOT/}"
  local hits
  hits="$(
    awk -v forbidden="$FORBIDDEN" '
      function trim(s) { gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s); return s }
      function emit(file, line, parts, i, unit) {
        gsub(/\{[^}]*\}/, "", line)
        sub(/\/\/.*/, "", line)
        gsub(/^[ \t]*uses[ \t]*/, "", line)
        split(line, parts, /[,;]/)
        for (i in parts) {
          unit = trim(parts[i])
          if (unit != "" && unit ~ ("^(" forbidden ")$"))
            print file "|" unit
        }
      }
      /^[ \t]*uses[ \t]*/ {
        in_uses = 1
        emit(FILENAME, $0)
        if ($0 ~ /;/) in_uses = 0
        next
      }
      in_uses {
        emit(FILENAME, $0)
        if ($0 ~ /;/) in_uses = 0
      }
    ' "$file" 2>/dev/null || true
  )"
  if [[ -n "$hits" ]]; then
    while IFS='|' read -r f unit; do
      echo "[FAIL] $rel uses forbidden FPC RTL unit: $unit" >&2
      fail_count=$((fail_count + 1))
    done <<< "$hits"
  fi
}

while IFS= read -r -d '' f; do
  scan_file "$f"
done < <(find "$CORE_SRC" -maxdepth 1 -name 'nextpas.core.collections*.pas' -print0 | sort -z)

while IFS= read -r -d '' f; do
  scan_file "$f"
done < <(find "$TEST_ROOT" \( -name '*.pas' -o -name '*.lpr' \) -print0 | sort -z)

if [[ "$fail_count" -gt 0 ]]; then
  echo "collections source-contract: $fail_count violation(s)" >&2
  exit 1
fi

echo "collections source-contract: pass (no SysUtils/Classes/… in collections src+tests)"
