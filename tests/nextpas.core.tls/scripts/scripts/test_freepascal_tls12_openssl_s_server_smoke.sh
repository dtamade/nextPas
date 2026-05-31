#!/usr/bin/env bash
# P5 smoke test: FreePascal TLS 1.2 client vs OpenSSL s_server
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${FAFAFA_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
PORT=44330
TMPDIR=$(mktemp -d)

cleanup() {
  [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Generate ephemeral RSA cert+key for s_server
openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/server.key" \
  -out "$TMPDIR/server.crt" -days 1 -nodes \
  -subj "/CN=localhost" 2>/dev/null

echo "[TEST] FreePascal TLS 1.2 client vs OpenSSL s_server (ECDHE-RSA-AES128-GCM-SHA256)"

# Compile the smoke test binary
mkdir -p tmp/tls12smoke_units tmp/tls12smoke_bin
"$FPC" -B -Fu./src -Fu./tests -Fu./tests/framework \
  -FUtmp/tls12smoke_units -FEtmp/tls12smoke_bin \
  tests/crypto/test_tls12_openssl_smoke.pas 2>&1 | tail -3

if [[ ! -f tmp/tls12smoke_bin/test_tls12_openssl_smoke ]]; then
  echo "[FAIL] Smoke test binary did not compile"
  exit 1
fi

# Start openssl s_server
openssl s_server -tls1_2 \
  -cipher ECDHE-RSA-AES128-GCM-SHA256 \
  -groups X25519 \
  -cert "$TMPDIR/server.crt" -key "$TMPDIR/server.key" \
  -accept "$PORT" -www \
  -quiet 2>/dev/null &
SERVER_PID=$!

sleep 1

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "[FAIL] OpenSSL s_server failed to start"
  exit 1
fi

# Run the smoke test
if tmp/tls12smoke_bin/test_tls12_openssl_smoke "$PORT"; then
  echo "[PASS] FreePascal TLS 1.2 ECDHE_RSA handshake succeeded against OpenSSL s_server"
else
  echo "[FAIL] FreePascal TLS 1.2 handshake failed"
  exit 1
fi
