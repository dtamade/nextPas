#!/usr/bin/env bash
# flat-test-audit.sh — classify flattened test programs under a tests module
# =========================================================================
# Read-only audit: compiles every *.pas in a flattened tests module (e.g.
# tests/nextpas.core.tls/) and classifies each file so that zombie tests can
# be triaged before they are wired into the root `make test` matrix.
#
# Classification:
#   PASS     — compiles with the standard test flags (candidate for the matrix)
#   OLDUNIT  — references a unit that does not exist (Can't find unit). These
#              are typically leftovers of a renamed/moved unit (e.g.
#              nextpas.core.tls.crypto.* -> nextpas.core.crypto.*) and are
#              batch-fixable once the migration mapping is known.
#   FAIL     — any other compile error (external-unit references such as
#              fafafa.ssl, FPC RTL dependencies, missing support units, ...)
#
# The tool never edits files and never builds into the repo (artifacts go to
# a temp dir). Fixing the non-PASS files is a per-batch task, not this tool's.
#
# Usage:
#   scripts/flat-test-audit.sh [--dir tests/nextpas.core.tls] [--jobs N]
#     --dir    tests module dir containing flattened *.pas (default: auto-detect
#              the only nextpas.core.* module with flattened test programs)
#     --jobs   parallel compile jobs (default: nproc)
#     --fpc    FPC binary (default: fpc)

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
core_root="$repo_root/core"
module_dir=""
jobs="$(nproc 2>/dev/null || echo 4)"
fpc_bin="${FPC:-fpc}"

usage() {
  cat >&2 <<'EOF'
usage: scripts/flat-test-audit.sh [--dir tests/nextpas.core.tls] [--jobs N] [--fpc PATH]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dir)
      module_dir="${2:-}"
      shift 2
      ;;
    --jobs)
      jobs="${2:-}"
      shift 2
      ;;
    --fpc)
      fpc_bin="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option $1" >&2
      usage
      exit 2
      ;;
  esac
done

if [[ -z "$module_dir" ]]; then
  module_dir="$(cd "$core_root/tests" && ls -d nextpas.core.* 2>/dev/null | while read -r d; do
    if compgen -G "$core_root/tests/$d/*.pas" >/dev/null 2>&1; then echo "$d"; fi
  done | head -1)"
fi
module_dir="${module_dir#./}"
full_dir="$core_root/$module_dir"
if [[ ! -d "$full_dir" ]]; then
  echo "error: module dir not found: $full_dir" >&2
  exit 2
fi

work="$(mktemp -d /tmp/flat-test-audit.XXXXXX)"
trap 'rm -rf "$work"' EXIT
# single string, not an array: exported to parallel bash -c children
export FPC_FLAGS_STR="-MObjFPC -Sh -Sg -O2 -gl -gh -dHEAPTRC_ACTIVE -Fu$core_root/src -Fi$core_root/src -Fu$core_root/tests/shared"
export work

classify() {
  local file="$1" out="$work/out_$$.txt"
  local name
  name="$(basename "$file" .pas)"
  # per-PID output/ppu dirs: parallel children must not race on shared .ppu
  mkdir -p "$work/fu_$$" "$work/bin_$$" || return 1
  if timeout 90 "$fpc_bin" $FPC_FLAGS_STR \
    -FU"$work/fu_$$" -FE"$work/bin_$$" "$file" >"$out" 2>&1; then
    echo "PASS $name"
  elif grep -q "Can't find unit" "$out"; then
    local u
    u="$(grep -m1 "Can't find unit" "$out" | sed -E "s/.*Can't find unit ([^ ]+).*/\1/")"
    echo "OLDUNIT $name -> $u"
  elif grep -qE 'Error:|Fatal:' "$out"; then
    local msg
    msg="$(grep -m1E 'Error:|Fatal:' "$out" | head -c 160)"
    echo "FAIL $name :: $msg"
  else
    echo "FAIL $name :: rc=$?"
  fi
}

export -f classify
export fpc_bin

mapfile -t files < <(find "$full_dir" -maxdepth 1 -name '*.pas' | sort)
if [[ ${#files[@]} -eq 0 ]]; then
  echo "no flattened *.pas in $full_dir"
  exit 0
fi

printf '%s\n' "${files[@]}" | xargs -P"$jobs" -n1 bash -c 'classify "$1"' _ >"$work/result.txt"

echo "module=$module_dir files=${#files[@]} jobs=$jobs fpc=$fpc_bin"
echo "--- summary ---"
awk '{c[$1]++} END {print "PASS    " (c["PASS"]+0); print "OLDUNIT " (c["OLDUNIT"]+0); print "FAIL    " (c["FAIL"]+0)}' "$work/result.txt"
echo "--- PASS list (matrix candidates) ---"
grep '^PASS ' "$work/result.txt" | sed 's/^PASS //' || true
echo "--- OLDUNIT list (missing unit <- test count) ---"
grep '^OLDUNIT ' "$work/result.txt" | sed -E 's/^OLDUNIT ([^ ]+) -> (.*)$/\2 <- \1/' | sort | uniq -c | sort -rn || true