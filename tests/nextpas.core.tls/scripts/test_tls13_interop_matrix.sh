#!/usr/bin/env bash
# TLS 1.3 Interop Matrix: FreePascal client vs OpenSSL s_server
# Tests: full handshake, PSK resume, cipher suites, KeyUpdate
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${FAFAFA_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
BASE_PORT=44600
TMPDIR=$(mktemp -d)
PASS=0
FAIL=0
SKIP=0

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

declare -a PIDS=()

# Generate test certificates
openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/rsa.key" \
  -out "$TMPDIR/rsa.crt" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

openssl ecparam -name prime256v1 -genkey -noout -out "$TMPDIR/ec.key" 2>/dev/null
openssl req -x509 -new -key "$TMPDIR/ec.key" \
  -out "$TMPDIR/ec.crt" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

# Compile test binaries
mkdir -p tmp/tls13matrix_units tmp/tls13matrix_bin

echo "=== Compiling test binaries ==="
"$FPC" -B -Fu./src -FUtmp/tls13matrix_units -FEtmp/tls13matrix_bin \
  tests/crypto/test_tls13_psk_openssl.pas 2>&1 | tail -1

PSK_BIN=tmp/tls13matrix_bin/test_tls13_psk_openssl

echo ""
echo "=== FreePascal TLS 1.3 Interop Matrix ==="
echo ""

run_psk_test() {
  local name="$1" ciphers="$2" cert="$3" key="$4" port="$5"

  openssl s_server -tls1_3 \
    -ciphersuites "$ciphers" \
    -cert "$cert" -key "$key" \
    -accept "$port" -www -quiet 2>/dev/null &
  local pid=$!
  PIDS+=("$pid")
  sleep 0.5

  if ! kill -0 "$pid" 2>/dev/null; then
    echo "[SKIP] $name (s_server failed)"
    SKIP=$((SKIP + 1))
    return
  fi

  if "$PSK_BIN" "$port" >/dev/null 2>&1; then
    echo "[PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $name"
    FAIL=$((FAIL + 1))
  fi

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

PORT=$BASE_PORT

# TLS 1.3 Full Handshake + PSK Resume (per cipher suite)
run_psk_test "TLS_AES_256_GCM_SHA384 (RSA, PSK resume)" \
  "TLS_AES_256_GCM_SHA384" "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" $((PORT + 0))

run_psk_test "TLS_AES_128_GCM_SHA256 (RSA, PSK resume)" \
  "TLS_AES_128_GCM_SHA256" "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" $((PORT + 1))

run_psk_test "TLS_CHACHA20_POLY1305_SHA256 (RSA, PSK resume)" \
  "TLS_CHACHA20_POLY1305_SHA256" "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" $((PORT + 2))

# ECDSA certificate
run_psk_test "TLS_AES_256_GCM_SHA384 (ECDSA, PSK resume)" \
  "TLS_AES_256_GCM_SHA384" "$TMPDIR/ec.crt" "$TMPDIR/ec.key" $((PORT + 3))

run_psk_test "TLS_AES_128_GCM_SHA256 (ECDSA, PSK resume)" \
  "TLS_AES_128_GCM_SHA256" "$TMPDIR/ec.crt" "$TMPDIR/ec.key" $((PORT + 4))

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
