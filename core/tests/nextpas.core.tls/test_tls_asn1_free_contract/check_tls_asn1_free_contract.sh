#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="$CORE_ROOT/src"

fail() {
  echo "[tls-asn1-free-contract] FAIL: $*" >&2
  exit 1
}

# Empty finally after TASN1Reader.Create is the Batch B regression class.
# Heuristic: look for Create then only whitespace/try/Node:=Parse then empty finally.
if rg -n --glob 'nextpas.core.tls.x509.pas' --glob 'nextpas.core.crypto.ecdsa.pas' \
  --glob 'nextpas.core.crypto.p384.pas' --glob 'nextpas.core.crypto.pkcs8.pas' \
  --glob 'nextpas.core.tls.tls13.servercertverify.pas' \
  -U 'TASN1Reader\.Create[\s\S]{0,400}?finally\s*\n\s*end;' "$SRC"; then
  fail "found empty finally near TASN1Reader.Create (possible leak)"
fi

# Reader.Free must appear in the same high-risk units that create readers.
for f in \
  nextpas.core.tls.x509.pas \
  nextpas.core.crypto.ecdsa.pas \
  nextpas.core.crypto.p384.pas \
  nextpas.core.crypto.pkcs8.pas \
  nextpas.core.tls.tls13.servercertverify.pas; do
  path="$SRC/$f"
  if ! rg -q 'TASN1Reader\.Create' "$path"; then
    continue
  fi
  if ! rg -q 'Reader\.Free|LReader\.Free' "$path"; then
    fail "$f creates TASN1Reader but has no Reader.Free/LReader.Free"
  fi
done

echo "[tls-asn1-free-contract] PASS"
