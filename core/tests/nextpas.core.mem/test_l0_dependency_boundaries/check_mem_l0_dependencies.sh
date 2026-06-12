#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

FORBIDDEN_UNITS=(
  "nextpas.core.sync"
  "nextpas.core.sync.mutex"
  "nextpas.core.platform.time"
  "nextpas.core.time.cpu"
  "nextpas.core.text.conv"
  "nextpas.core.fs.util"
  "Windows"
  "BaseUnix"
  "Unix"
  "SyncObjs"
)

KNOWN_DEBT=(
  "src/nextpas.core.mem.mapped_ring_buffer.pas|nextpas.core.fs.util"
  "src/nextpas.core.mem.mapped_ring_buffer.sharded.pas|SyncObjs"
  "src/nextpas.core.mem.mapped_ring_buffer.sharded.pas|nextpas.core.text.conv"
  "src/nextpas.core.mem.mapped_slab_pool.pas|nextpas.core.fs.util"
  "src/nextpas.core.mem.mapped_slab_pool.pas|nextpas.core.text.conv"
  "src/nextpas.core.mem.secure.pas|BaseUnix"
  "src/nextpas.core.mem.secure.pas|Windows"
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
done < <(find src -maxdepth 1 -name 'nextpas.core.mem*.pas' | sort) | sort -u > "$tmp_found"

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

echo "mem L0 dependency boundary contract passed"
echo "Known debt entries allowed: ${#KNOWN_DEBT[@]}"
