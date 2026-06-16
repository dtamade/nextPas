#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SOURCE="$CORE_ROOT/src/nextpas.core.errors.pas"

fail() {
  echo "[errors-source-contract] FAIL: $*" >&2
  exit 1
}

list_interface_uses_units() {
  awk '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function emit_units(line, parts, i, unit) {
      gsub(/\{[^}]*\}/, "", line)
      sub(/\/\/.*/, "", line)
      gsub(/^[ \t]*uses[ \t]*/, "", line)
      split(line, parts, /[,;]/)
      for (i in parts) {
        unit = trim(parts[i])
        if (unit != "" && unit !~ /^\$/) {
          print unit
        }
      }
    }
    /^[ \t]*interface[ \t]*$/ {
      in_interface = 1
      next
    }
    /^[ \t]*implementation[ \t]*$/ {
      exit
    }
    !in_interface {
      next
    }
    /^[ \t]*uses[ \t]*/ {
      in_uses = 1
      emit_units($0)
      if ($0 ~ /;/) in_uses = 0
      next
    }
    in_uses {
      emit_units($0)
      if ($0 ~ /;/) in_uses = 0
    }
  ' "$SOURCE"
}

USES_UNITS="$(list_interface_uses_units | tr '[:upper:]' '[:lower:]' | sort -u)"
EXPECTED_USES="nextpas.core.exception"

if [[ "$USES_UNITS" != "$EXPECTED_USES" ]]; then
  printf '[errors-source-contract] interface uses drifted\n' >&2
  printf '%s\n' '--- expected' >&2
  printf '%s\n' "$EXPECTED_USES" >&2
  printf '%s\n' '--- actual' >&2
  printf '%s\n' "$USES_UNITS" >&2
  exit 1
fi

if rg --quiet '^[[:space:]]*E[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*class\\b' "$SOURCE"; then
  fail "errors facade must alias canonical exception classes, not define shadow subclasses"
fi

for token in \
  'Exception = nextpas.core.exception.Exception;' \
  'ENextPasError = nextpas.core.exception.ENextPasError;' \
  'EOutOfMemoryError = nextpas.core.exception.EOutOfMemoryError;' \
  'ecResourceExhausted = nextpas.core.exception.ecResourceExhausted;'
do
  rg -F --quiet -- "$token" "$SOURCE" || fail "missing re-export token: $token"
done

echo "errors-source-contract=pass"
