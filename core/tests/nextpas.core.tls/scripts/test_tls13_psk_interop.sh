#!/usr/bin/env bash
# TLS 1.3 PSK Session Resumption Interop Test
# FreePascal client vs OpenSSL s_server
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${FAFAFA_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
TMPDIR=$(mktemp -d)
PORT=${PSK_TEST_PORT:-44560}

cleanup() {
  kill "$SPID" 2>/dev/null || true
  wait "$SPID" 2>/dev/null || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Generate test certificate
openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/key.pem" \
  -out "$TMPDIR/cert.pem" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

# Compile PSK test binary
mkdir -p tmp/psk_gate_units tmp/psk_gate_bin
"$FPC" -B -Fu./src -FUtmp/psk_gate_units -FEtmp/psk_gate_bin \
  tests/crypto/test_tls13_psk_openssl.pas 2>&1 | tail -1

BIN=tmp/psk_gate_bin/test_tls13_psk_openssl
if [[ ! -f "$BIN" ]]; then
  echo "[FATAL] PSK test binary did not compile"
  exit 1
fi

# Start OpenSSL s_server
openssl s_server -tls1_3 \
  -cert "$TMPDIR/cert.pem" -key "$TMPDIR/key.pem" \
  -accept "$PORT" -www -quiet 2>/dev/null &
SPID=$!
sleep 0.5

if ! kill -0 "$SPID" 2>/dev/null; then
  echo "[FATAL] OpenSSL s_server failed to start"
  exit 1
fi

echo "=== TLS 1.3 PSK Session Resumption Interop ==="

if "$BIN" "$PORT" 2>&1 | tee "$TMPDIR/output.log" | grep -q "FAIL"; then
  echo ""
  echo "[FAIL] PSK resumption interop failed"
  grep "FAIL" "$TMPDIR/output.log"
  exit 1
fi

PASS_COUNT=$(grep -c "PASS" "$TMPDIR/output.log" || echo 0)
echo ""
echo "[PASS] TLS 1.3 PSK resumption: $PASS_COUNT assertions passed"
