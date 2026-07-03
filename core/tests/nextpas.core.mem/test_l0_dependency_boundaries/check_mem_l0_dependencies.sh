#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

FORBIDDEN_UNITS=(
  "nextpas.core.sync"
  "nextpas.core.sync.mutex"
  "nextpas.core.platform.time"
  "nextpas.core.time.cpu"
  "nextpas.core.text.conv"
  "nextpas.core.fs.util"
  "nextpas.core.os.env"
  "nextpas.core.path"
  "nextpas.core.fs.path"
  "SysUtils"
  "Windows"
  "BaseUnix"
  "Unix"
  "SyncObjs"
)

KNOWN_DEBT=(
)

is_forbidden_unit() {
  local unit="$1"
  local forbidden
  for forbidden in "${FORBIDDEN_UNITS[@]}"; do
    if [[ "$unit" == "$forbidden" ]]; then
      return 0
    fi
  done
  return 1
}

is_known_debt() {
  local key="$1"
  local known
  for known in "${KNOWN_DEBT[@]}"; do
    if [[ "$key" == "$known" ]]; then
      return 0
    fi
  done
  return 1
}

tmp_found="$(mktemp)"
tmp_unknown="$(mktemp)"
trap 'rm -f "$tmp_found" "$tmp_unknown"' EXIT

while IFS= read -r file; do
  awk -v file="$file" '
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
          print file "|" unit
        }
      }
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
  ' "$file"
done < <(find core/src -maxdepth 1 -name 'nextpas.core.mem*.pas' | sort) | sort -u > "$tmp_found"

while IFS='|' read -r file unit; do
  if is_forbidden_unit "$unit"; then
    key="$file|$unit"
    if ! is_known_debt "$key"; then
      printf '%s\n' "$key" >> "$tmp_unknown"
    fi
  fi
done < "$tmp_found"

if [[ -s "$tmp_unknown" ]]; then
  echo "Unexpected mem L0 dependency boundary violations:"
  cat "$tmp_unknown"
  exit 1
fi

# --- Phase 2: forbidden identifier scan (implicit System unit references) ---
# TRTLCriticalSection comes from implicit `System` unit, not visible in uses clauses.
# mem module must use TPlatformMutex (nextpas.core.platform.sync) or TMemMutex instead.
FORBIDDEN_IDENTIFIERS=(
  "TRTLCriticalSection"
  "InitCriticalSection"
  "DoneCriticalSection"
  "EnterCriticalSection"
  "LeaveCriticalSection"
)

tmp_id_violations="$(mktemp)"
tmp_id_raw="$(mktemp)"
trap 'rm -f "$tmp_found" "$tmp_unknown" "$tmp_id_violations" "$tmp_id_raw"' EXIT

MEM_SRC_FILES=$(find core/src -maxdepth 1 -name 'nextpas.core.mem*.pas' | sort)

for ident in "${FORBIDDEN_IDENTIFIERS[@]}"; do
  # grep may return 1 if no matches — that's fine
  grep -rn "\b${ident}\b" $MEM_SRC_FILES 2>/dev/null | grep -v '^\s*//' >> "$tmp_id_raw" || true
done

while IFS=: read -r file line content; do
  # Extract which forbidden identifier was found
  for ident in "${FORBIDDEN_IDENTIFIERS[@]}"; do
    if echo "$content" | grep -q "\b${ident}\b"; then
      echo "${file}:${line}: forbidden identifier '${ident}' — use TPlatformMutex or TMemMutex" >> "$tmp_id_violations"
      break
    fi
  done
done < "$tmp_id_raw"

if [[ -s "$tmp_id_violations" ]]; then
  echo "Forbidden FPC System unit identifiers in mem module:"
  cat "$tmp_id_violations"
  exit 1
fi

echo "mem L0 dependency boundary contract passed"
echo "Known debt entries allowed: ${#KNOWN_DEBT[@]}"
