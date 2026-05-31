#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="${FAFAFA_TLS13_SIGNER_SOURCE:-src/nextpas.core.tls.tls13.servercertverify.pas}"
WITH_TEST="${FAFAFA_TLS13_SIGNER_PURITY_WITH_TEST:-0}"

cd "$ROOT_DIR"

if [[ ! -f "$TARGET" ]]; then
  echo "[purity] source file not found: $TARGET" >&2
  exit 2
fi

if rg -n "fafafa\.ssl\.openssl|gmp" "$TARGET" >/tmp/fafafa_tls13_signer_purity_hits.$$ 2>/dev/null; then
  echo "[purity] FAIL: external big-int/backend dependency found in $TARGET" >&2
  cat /tmp/fafafa_tls13_signer_purity_hits.$$ >&2 || true
  rm -f /tmp/fafafa_tls13_signer_purity_hits.$$
  exit 1
fi
rm -f /tmp/fafafa_tls13_signer_purity_hits.$$ || true

echo "[purity] PASS: no openssl/gmp reference in $TARGET"

if [[ "$WITH_TEST" != "1" ]]; then
  exit 0
fi

echo "[purity] running tls13 signer helper test"

if [[ -x "bin/test_tls13_servercertverify" ]]; then
  ./bin/test_tls13_servercertverify
  exit 0
fi

fpc -MObjFPC -Scghi -O2 -Criot -g -gl -vewnhibq \
  -Fu./src -Fu./src/openssl -Fu./src/mbedtls -Fu./src/schannel -Fu./src/wolfssl -Fu./src/freepascal -Fu./src/tls13 \
  -obin/test_tls13_servercertverify tests/test_tls13_servercertverify.pas >/dev/null

./bin/test_tls13_servercertverify
