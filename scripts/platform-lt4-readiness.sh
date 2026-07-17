#!/usr/bin/env bash
# platform-lt4-readiness.sh
# Inventory LT4 host/toolchain prerequisites. Does NOT promote truth tiers.
#
# Usage: ./scripts/platform-lt4-readiness.sh
# Exit: 0 always for inventory; prints ready=/blocked= summary.
# Evidence language stays honest: wine != real Windows; no macOS runtime here.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FPC="${FPC:-fpc}"
WINE="${WINE:-wine}"

ready=()
blocked=()
notes=()

note() { notes+=("$1"); }
mark_ready() { ready+=("$1"); }
mark_blocked() { blocked+=("$1"); }

echo "LT4 readiness inventory (not a truth promotion)"
echo "repo=$REPO_ROOT"
echo "date=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo ""

if command -v "$FPC" >/dev/null 2>&1; then
  mark_ready "fpc-on-path"
  note "fpc=$("$FPC" -iV 2>/dev/null || true) path=$(command -v "$FPC")"
else
  mark_blocked "fpc-missing"
fi

# Win64 cross via fpc -Twin64 (ppcrossx64 may live under FPC units, not PATH)
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/lt4_probe.pas" <<'EOF'
program lt4_probe;
begin
  WriteLn('lt4-win64-probe-ok');
end.
EOF
if (cd "$tmp" && "$FPC" -Twin64 -Px86_64 lt4_probe.pas >/dev/null 2>&1) \
  && [[ -f "$tmp/lt4_probe.exe" ]]; then
  mark_ready "fpc-twin64-cross"
  note "win64-pe=$(file -b "$tmp/lt4_probe.exe" 2>/dev/null || echo present)"
else
  mark_blocked "fpc-twin64-cross"
  note "ppcrossx64 not usable via fpc -Twin64 -Px86_64"
fi

if command -v "$WINE" >/dev/null 2>&1; then
  mark_ready "wine-on-path"
  note "wine=$("$WINE" --version 2>/dev/null || true)"
  if [[ -f "$tmp/lt4_probe.exe" ]]; then
    if out="$("$WINE" "$tmp/lt4_probe.exe" 2>/dev/null | tr -d '\r')" \
      && [[ "$out" == *lt4-win64-probe-ok* ]]; then
      mark_ready "wine-runs-win64-pe"
    else
      mark_blocked "wine-runs-win64-pe"
    fi
  fi
else
  mark_blocked "wine-on-path"
fi

if [[ -f "$REPO_ROOT/core/tests/common.mk" ]] \
  && grep -q 'wine-runtime-smoke' "$REPO_ROOT/core/tests/common.mk"; then
  mark_ready "common-mk-wine-target"
else
  mark_blocked "common-mk-wine-target"
fi

if [[ -x "$REPO_ROOT/core/scripts/platform-wine-ci-matrix.sh" ]] \
  || [[ -f "$REPO_ROOT/core/scripts/platform-wine-ci-matrix.sh" ]]; then
  mark_ready "wine-ci-matrix-script"
else
  mark_blocked "wine-ci-matrix-script"
fi

if [[ -f "$REPO_ROOT/scripts/platform-wine-runtime-smoke.sh" ]]; then
  mark_ready "wine-runtime-smoke-script"
else
  mark_blocked "wine-runtime-smoke-script"
fi

# Real Windows GHA matrix: D1.d promoted documented 17-gate set to ci-matrix.
if [[ -f "$REPO_ROOT/core/scripts/platform-windows-ci-matrix.sh" ]] \
  || [[ -f "$REPO_ROOT/core/scripts/platform-windows-ci-matrix.ps1" ]]; then
  mark_ready "real-windows-ci-matrix-script"
  note "GHA job test-windows-runtime runs platform-windows-ci-matrix.sh (truth=ci-matrix, 17-gate set)"
else
  mark_blocked "real-windows-ci-matrix-script"
fi
if grep -q 'truth=ci-matrix' "$REPO_ROOT/core/scripts/platform-windows-ci-matrix.sh" 2>/dev/null; then
  mark_ready "windows-ci-matrix-promoted"
  note "D1.d: documented 17-gate set is ci-matrix; not full-host Windows parity"
else
  mark_blocked "windows-ci-matrix-promoted"
fi
mark_blocked "macos-focused-runtime-host"
note "macOS focused-runtime promotion is ROADMAP D2"

echo "ready (${#ready[@]}):"
for item in "${ready[@]}"; do
  printf '  + %s\n' "$item"
done
echo "blocked (${#blocked[@]}):"
for item in "${blocked[@]}"; do
  printf '  - %s\n' "$item"
done
echo "notes:"
for item in "${notes[@]}"; do
  printf '  * %s\n' "$item"
done

echo ""
echo "truth=lt4-inventory; wine-runtime-smoke tools may be ready;"
if printf '%s\n' "${ready[@]}" | grep -qx 'windows-ci-matrix-promoted'; then
  echo "truth=lt4-inventory; windows documented 17-gate set is ci-matrix; macOS focused-runtime remains open (D2)"
  echo "status=windows-ci-matrix-promoted;macos-open"
else
  echo "truth=lt4-inventory; real Windows ci-matrix and macOS focused-runtime remain registered-only"
  echo "status=registered-only"
fi
