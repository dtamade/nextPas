#!/usr/bin/env bash
# P9 Interop Matrix: FreePascal TLS 1.2 client vs OpenSSL s_server
# Tests all supported cipher suites with RSA and ECDSA certificates
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${FAFAFA_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
BASE_PORT=44340
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

# Compile smoke test binary
mkdir -p tmp/tls12smoke_units tmp/tls12smoke_bin
"$FPC" -B -Fu./src -Fu./tests -Fu./tests/framework \
  -FUtmp/tls12smoke_units -FEtmp/tls12smoke_bin \
  tests/crypto/test_tls12_openssl_smoke.pas 2>&1 | tail -1

BIN=tmp/tls12smoke_bin/test_tls12_openssl_smoke
if [[ ! -f "$BIN" ]]; then
  echo "[FATAL] Smoke test binary did not compile"
  exit 1
fi

echo "=== FreePascal TLS 1.2 Interop Matrix ==="
echo ""

run_test() {
  local name="$1" cipher="$2" cert="$3" key="$4" port="$5" groups="${6:-X25519}"

  openssl s_server -tls1_2 \
    -cipher "$cipher" \
    -groups "$groups" \
    -cert "$cert" -key "$key" \
    -accept "$port" -www -quiet 2>/dev/null &
  local pid=$!
  PIDS+=("$pid")
  sleep 0.5

  if ! kill -0 "$pid" 2>/dev/null; then
    echo "[SKIP] $name (s_server failed to start)"
    SKIP=$((SKIP + 1))
    return
  fi

  if "$BIN" "$port" >/dev/null 2>&1; then
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

# RSA cipher suites
run_test "ECDHE-RSA-AES128-GCM-SHA256 (X25519)" \
  "ECDHE-RSA-AES128-GCM-SHA256" "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" $((BASE_PORT + 0))

run_test "ECDHE-RSA-AES256-GCM-SHA384 (X25519)" \
  "ECDHE-RSA-AES256-GCM-SHA384" "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" $((BASE_PORT + 1))

# ECDSA cipher suites
run_test "ECDHE-ECDSA-AES128-GCM-SHA256 (X25519)" \
  "ECDHE-ECDSA-AES128-GCM-SHA256" "$TMPDIR/ec.crt" "$TMPDIR/ec.key" $((BASE_PORT + 2)) "X25519"

run_test "ECDHE-ECDSA-AES256-GCM-SHA384 (X25519)" \
  "ECDHE-ECDSA-AES256-GCM-SHA384" "$TMPDIR/ec.crt" "$TMPDIR/ec.key" $((BASE_PORT + 3)) "X25519"

# RSA with different key sizes
openssl req -x509 -newkey rsa:4096 -keyout "$TMPDIR/rsa4096.key" \
  -out "$TMPDIR/rsa4096.crt" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

run_test "ECDHE-RSA-AES128-GCM-SHA256 (RSA-4096)" \
  "ECDHE-RSA-AES128-GCM-SHA256" "$TMPDIR/rsa4096.crt" "$TMPDIR/rsa4096.key" $((BASE_PORT + 4))

# P-256 ECDHE group (instead of X25519)
run_test "ECDHE-RSA-AES128-GCM-SHA256 (P-256)" \
  "ECDHE-RSA-AES128-GCM-SHA256" "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" $((BASE_PORT + 5)) "P-256"

run_test "ECDHE-ECDSA-AES256-GCM-SHA384 (P-256)" \
  "ECDHE-ECDSA-AES256-GCM-SHA384" "$TMPDIR/ec.crt" "$TMPDIR/ec.key" $((BASE_PORT + 6)) "P-256"

# ChaCha20-Poly1305 cipher suites
run_test "ECDHE-RSA-CHACHA20-POLY1305 (X25519)" \
  "ECDHE-RSA-CHACHA20-POLY1305" "$TMPDIR/rsa.crt" "$TMPDIR/rsa.key" $((BASE_PORT + 7))

run_test "ECDHE-ECDSA-CHACHA20-POLY1305 (X25519)" \
  "ECDHE-ECDSA-CHACHA20-POLY1305" "$TMPDIR/ec.crt" "$TMPDIR/ec.key" $((BASE_PORT + 8)) "X25519"

# CBC cipher suites — handshake-only (app data uses different record format)
# CBC handshake verified separately; excluded from end-to-end matrix

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
