#!/usr/bin/env bash
# Go/Rust quality bar: every public Check* / To* API name must appear in
# framework self-tests (zero untested public assertion surface).
set -euo pipefail

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
CORE_ROOT="$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)"
SRC="$CORE_ROOT/src"
TESTS="$CORE_ROOT/tests/nextpas.core.test"

fail=0
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# ── Check* public procedures (interface section of check.pas) ───────────────
awk '
  /^interface/ { in_iface=1; next }
  /^implementation/ { in_iface=0 }
  in_iface && $1 == "procedure" && $2 ~ /^Check[A-Za-z0-9]+/ {
    name = $2
    sub(/\(.*$/, "", name)
    sub(/;.*$/, "", name)
    print name
  }
' "$SRC/nextpas.core.test.check.pas" | sort -u > "$tmp/check_api.txt"

{
  echo Fail
  echo Skip
  # SoftFail surface (Go t.Error) — not matched by Check* awk
  echo SoftFail
  echo SoftCheckTrue
  echo SoftCheckFalse
  echo SoftCheckEqual
  echo SoftCheckContains
  # v8.23 Soft high-frequency surface
  echo SoftCheckNear
} >> "$tmp/check_api.txt"
sort -u "$tmp/check_api.txt" -o "$tmp/check_api.txt"

echo "=== Check* / Fail / Skip coverage ==="
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  case "$name" in
    CheckArrayContainsInt|CheckArrayContainsStr)
      if ! rg -q "CheckArrayContains" "$TESTS" --glob '*.lpr'; then
        echo "MISSING: $name (and parent CheckArrayContains)"
        fail=1
      else
        echo "OK: $name (via CheckArrayContains)"
      fi
      continue
      ;;
  esac
  if ! rg -q --fixed-strings "$name" "$TESTS" --glob '*.lpr' --glob '*.pas' --glob '*.sh'; then
    echo "MISSING: $name"
    fail=1
  else
    echo "OK: $name"
  fi
done < "$tmp/check_api.txt"

# ── IExpectation To* methods ────────────────────────────────────────────────
awk '
  /^interface/ { in_iface=1; next }
  /^implementation/ { in_iface=0 }
  in_iface && /function To[A-Za-z0-9_]+/ {
    line = $0
    sub(/^.*function /, "", line)
    sub(/\(.*$/, "", line)
    sub(/:.*$/, "", line)
    sub(/;.*$/, "", line)
    gsub(/[[:space:]]/, "", line)
    if (line ~ /^To[A-Za-z0-9_]+$/) print line
  }
' "$SRC/nextpas.core.test.expect.pas" | sort -u > "$tmp/to_api.txt"

echo ""
echo "=== Expect To* coverage ==="
while IFS= read -r name; do
  [[ -z "$name" ]] && continue
  if ! rg -q --fixed-strings "$name" "$TESTS" --glob '*.lpr' --glob '*.pas'; then
    echo "MISSING: $name"
    fail=1
  else
    echo "OK: $name"
  fi
done < "$tmp/to_api.txt"

echo ""
check_n=$(wc -l < "$tmp/check_api.txt")
to_n=$(wc -l < "$tmp/to_api.txt")
echo "Checked Check*/Fail/Skip names: $check_n"
echo "Checked To* names: $to_n"

if [[ "$fail" -ne 0 ]]; then
  echo ""
  echo "FAIL: public API without self-test reference (Go/Rust zero-untested bar)"
  exit 1
fi

echo ""
echo "PASS: all public Check*/To* APIs referenced in self-tests"
exit 0
