#!/usr/bin/env bash
# Cross-backend interop: FreePascal TLS 1.2 client ↔ FreePascal TLS 1.2 server
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${FAFAFA_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
PORT=44370
TMPDIR=$(mktemp -d)
PASS=0
FAIL=0

cleanup() {
  [[ -n "${SRV_PID:-}" ]] && kill "$SRV_PID" 2>/dev/null || true
  wait "$SRV_PID" 2>/dev/null || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Generate certs
openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/rsa.key" \
  -out "$TMPDIR/rsa.crt" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

# Compile binaries
mkdir -p tmp/interop_units tmp/interop_bin
"$FPC" -B -Fu./src -Fu./tests -Fu./tests/framework \
  -FUtmp/interop_units -FEtmp/interop_bin \
  tests/crypto/test_tls12_openssl_smoke.pas 2>&1 | tail -1
"$FPC" -B -Fu./src -Fu./tests -Fu./tests/framework \
  -FUtmp/interop_units -FEtmp/interop_bin \
  tests/crypto/test_tls12_server_smoke.pas 2>&1 | tail -1

echo "=== Cross-Backend Interop Matrix ==="
echo ""

# Test 1: FreePascal client → OpenSSL server (GCM)
echo -n "[TEST] FPC client → OpenSSL server (GCM): "
openssl s_server -tls1_2 -cipher ECDHE-RSA-AES128-GCM-SHA256 -groups X25519 \
  -cert "$TMPDIR/rsa.crt" -key "$TMPDIR/rsa.key" -accept $PORT -www -quiet 2>/dev/null &
SRV_PID=$!; sleep 1
if tmp/interop_bin/test_tls12_openssl_smoke $PORT >/dev/null 2>&1; then
  echo "PASS"; PASS=$((PASS+1))
else
  echo "FAIL"; FAIL=$((FAIL+1))
fi
kill $SRV_PID 2>/dev/null; wait $SRV_PID 2>/dev/null; PORT=$((PORT+1))

# Test 2: OpenSSL client → FreePascal server (GCM)
echo -n "[TEST] OpenSSL client → FPC server (GCM): "
tmp/interop_bin/test_tls12_server_smoke $PORT "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" &
SRV_PID=$!; sleep 1
if echo "Q" | openssl s_client -connect 127.0.0.1:$PORT -tls1_2 \
  -cipher ECDHE-RSA-AES128-GCM-SHA256 -groups X25519 -no_ticket 2>&1 | grep -q "Cipher is ECDHE"; then
  echo "PASS"; PASS=$((PASS+1))
else
  echo "FAIL"; FAIL=$((FAIL+1))
fi
wait $SRV_PID 2>/dev/null; PORT=$((PORT+1))

# Test 3: FreePascal client → OpenSSL server (ChaCha20)
echo -n "[TEST] FPC client → OpenSSL server (ChaCha20): "
openssl s_server -tls1_2 -cipher ECDHE-RSA-CHACHA20-POLY1305 -groups X25519 \
  -cert "$TMPDIR/rsa.crt" -key "$TMPDIR/rsa.key" -accept $PORT -www -quiet 2>/dev/null &
SRV_PID=$!; sleep 1
if tmp/interop_bin/test_tls12_openssl_smoke $PORT >/dev/null 2>&1; then
  echo "PASS"; PASS=$((PASS+1))
else
  echo "FAIL"; FAIL=$((FAIL+1))
fi
kill $SRV_PID 2>/dev/null; wait $SRV_PID 2>/dev/null; PORT=$((PORT+1))

# Test 4: OpenSSL client → FreePascal server (ChaCha20)
echo -n "[TEST] OpenSSL client → FPC server (ChaCha20): "
tmp/interop_bin/test_tls12_server_smoke $PORT "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" &
SRV_PID=$!; sleep 1
if echo "Q" | openssl s_client -connect 127.0.0.1:$PORT -tls1_2 \
  -cipher ECDHE-RSA-CHACHA20-POLY1305 -groups X25519 -no_ticket 2>&1 | grep -q "Cipher is ECDHE"; then
  echo "PASS"; PASS=$((PASS+1))
else
  echo "FAIL"; FAIL=$((FAIL+1))
fi
wait $SRV_PID 2>/dev/null; PORT=$((PORT+1))

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
if [[ $FAIL -gt 0 ]]; then exit 1; fi
