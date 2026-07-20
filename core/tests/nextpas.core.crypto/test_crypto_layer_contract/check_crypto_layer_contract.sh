#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SRC="$CORE_ROOT/src"

fail() {
  echo "[crypto-layer-contract] FAIL: $*" >&2
  exit 1
}

# crypto production sources must never depend on tls (layering)
if rg -n --glob 'nextpas.core.crypto*.pas' 'nextpas\.core\.tls' "$SRC"; then
  fail "crypto sources must not reference nextpas.core.tls"
fi

# hash module must not depend on crypto
if rg -n --glob 'nextpas.core.hash*.pas' 'nextpas\.core\.crypto' "$SRC"; then
  fail "hash sources must not reference nextpas.core.crypto"
fi

# crypto.hash must delegate to core.hash (no independent Transform tables)
if ! rg -q 'nextpas\.core\.hash\.(md5|sha1|sha256|sha512)' "$SRC/nextpas.core.crypto.hash.pas"; then
  fail "crypto.hash must use nextpas.core.hash implementations"
fi
if rg -q 'procedure TMD5Context\.Transform|procedure TSHA256Context\.Transform' "$SRC/nextpas.core.crypto.hash.pas"; then
  fail "crypto.hash must not reintroduce Transform implementations"
fi

# chacha owner must be crypto unit
if ! rg -q 'unit nextpas\.core\.crypto\.chacha20poly1305' "$SRC/nextpas.core.crypto.chacha20poly1305.pas"; then
  fail "missing crypto.chacha20poly1305 owner unit"
fi
if ! rg -q 'nextpas\.core\.crypto\.chacha20poly1305' "$SRC/nextpas.core.crypto.pas"; then
  fail "crypto facade must re-export crypto.chacha20poly1305"
fi
if rg -q 'nextpas\.core\.tls\.tls13\.chacha20poly1305' "$SRC/nextpas.core.crypto.pas"; then
  fail "crypto facade must not use tls chacha unit"
fi

# Batch B/C: TASN1Node must free children (prevent parse-tree leaks)
if ! rg -q 'FChildren\.Free' "$SRC/nextpas.core.crypto.asn1.pas"; then
  fail "TASN1Node.Destroy must free FChildren"
fi

# Batch C: certificate generation options must not heap-allocate SAN as TStringList
if rg -n 'SubjectAltNames\s*:=\s*TStringList\.Create' \
  --glob 'nextpas.core.tls.cert*.pas' "$SRC"; then
  fail "cert options/info SubjectAltNames must not use TStringList.Create"
fi
if ! rg -q 'SubjectAltNames:\s*TStringArray' "$SRC/nextpas.core.tls.cert.utils.pas"; then
  fail "TCertGenOptions/TCertInfo SubjectAltNames must be TStringArray"
fi

echo "[crypto-layer-contract] PASS"
