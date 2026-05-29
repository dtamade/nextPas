#!/usr/bin/env bash
# Phase 0 contract: FreePascal backend must not depend on any C library
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

echo "[TEST] FreePascal backend no C library dependency contract"

FP_FILES=(
  src/nextpas.core.tls.freepascal.connection.pas
  src/nextpas.core.tls.freepascal.context.pas
  src/nextpas.core.tls.freepascal.context.material.pas
  src/nextpas.core.tls.freepascal.lib.pas
  src/nextpas.core.tls.freepascal.session.pas
  src/nextpas.core.tls.freepascal.earlydatareplay.pas
  src/nextpas.core.tls.freepascal.earlydatareplay.fileprovider.pas
  src/nextpas.core.tls.freepascal.earlydatareplay.dirstore.pas
  src/nextpas.core.tls.tls13.aead.pas
  src/nextpas.core.tls.tls13.appschedule.pas
  src/nextpas.core.tls.tls13.bigint.pas
  src/nextpas.core.tls.tls13.chacha20poly1305.pas
  src/nextpas.core.tls.tls13.clienthello.pas
  src/nextpas.core.tls.tls13.clienthello.parser.pas
  src/nextpas.core.tls.tls13.ecdsa.pas
  src/nextpas.core.tls.tls13.finished.pas
  src/nextpas.core.tls.tls13.keyschedule.pas
  src/nextpas.core.tls.tls13.parser.pas
  src/nextpas.core.tls.tls13.posthandshake.pas
  src/nextpas.core.tls.tls13.primitives.pas
  src/nextpas.core.tls.tls13.recordcrypto.pas
  src/nextpas.core.tls.tls13.servercertificate.pas
  src/nextpas.core.tls.tls13.servercertverify.pas
  src/nextpas.core.tls.tls13.serverhello.pas
  src/nextpas.core.tls.tls13.wire.pas
  src/nextpas.core.tls.tls13.x25519.pas
)

BANNED_PATTERNS=(
  "nextpas.core.tls.openssl"
  "nextpas.core.tls.mbedtls"
  "nextpas.core.tls.wolfssl"
  "nextpas.core.tls.winssl"
)

FAILED=0

for file in "${FP_FILES[@]}"; do
  if [[ ! -f "$file" ]]; then
    continue
  fi
  for pattern in "${BANNED_PATTERNS[@]}"; do
    if rg -F --quiet "$pattern" "$file" 2>/dev/null; then
      echo "[FAIL] $file depends on $pattern"
      rg -n -F "$pattern" "$file"
      FAILED=1
    fi
  done
done

if [[ $FAILED -eq 1 ]]; then
  echo ""
  echo "[FAIL] FreePascal/TLS1.3 code must not depend on any C-library backend"
  exit 1
fi

echo "[PASS] FreePascal backend has no C library dependencies"
