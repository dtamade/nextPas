#!/usr/bin/env bash
# Source-contract: mem raise EAllocError/EOutOfMemory must use FormatAllocErrorMsg.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
SRC="$ROOT/core/src"
FAIL=0
# error.pas defines the helpers; self-raises may use FormatAllocErrorMsg too.
while IFS= read -r -d '' f; do
  base="$(basename "$f")"
  if [[ "$base" == "nextpas.core.mem.error.pas" ]]; then
    continue
  fi
  # Extract raise Create(...) blocks roughly; require FormatAllocErrorMsg nearby
  if grep -nE 'raise[[:space:]]+E(AllocError|OutOfMemory)\.Create' "$f" >/dev/null 2>&1; then
    # For each raise line, allow FormatAllocErrorMsg on same or following 3 lines
    mapfile -t lines < <(grep -nE 'raise[[:space:]]+E(AllocError|OutOfMemory)\.Create' "$f" || true)
    for entry in "${lines[@]}"; do
      ln="${entry%%:*}"
      # shellcheck disable=SC2002
      window="$(sed -n "${ln},$((ln + 4))p" "$f")"
      if ! grep -q 'FormatAllocErrorMsg' <<<"$window"; then
        echo "FAIL: $base:$ln raise without FormatAllocErrorMsg within 4 lines"
        echo "$window"
        FAIL=1
      fi
    done
  fi
done < <(find "$SRC" -maxdepth 1 -name 'nextpas.core.mem*.pas' -print0)

# mem tests must not uses SysUtils/Classes
while IFS= read -r -d '' f; do
  if grep -nE '^\s*SysUtils\s*,|,\s*SysUtils\s*,|,\s*SysUtils\s*$|^\s*SysUtils\s*$|uses\s+SysUtils' "$f" \
    | grep -v 'must not import SysUtils' >/dev/null 2>&1; then
    # tighter: only flag actual uses clauses
    if awk '
      BEGIN{inuses=0}
      /^uses/{inuses=1}
      inuses{
        if ($0 ~ /\bSysUtils\b/ || $0 ~ /\bClasses\b/) { print FILENAME":"NR":"$0; found=1 }
        if (/;/) inuses=0
      }
      END{exit found?0:1}
    ' "$f"; then
      echo "FAIL: FPC RTL unit in mem test uses: $f"
      FAIL=1
    fi
  fi
done < <(find "$ROOT/core/tests/nextpas.core.mem" \( -name '*.lpr' -o -name '*.pas' \) -print0 2>/dev/null)

if [[ "$FAIL" -ne 0 ]]; then
  echo "check_alloc_error_raises: FAIL"
  exit 1
fi
echo "check_alloc_error_raises: OK"
