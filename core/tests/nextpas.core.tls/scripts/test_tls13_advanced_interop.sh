#!/usr/bin/env bash
# TLS 1.3 Advanced Interop: Client Certificate Auth + KeyUpdate
# FreePascal client vs OpenSSL s_server
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${FAFAFA_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
BASE_PORT=44700
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

# ============================================================================
# Generate test certificates
# ============================================================================

# Server RSA certificate
openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/server.key" \
  -out "$TMPDIR/server.crt" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

# CA for client certificates (self-signed CA)
openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/ca.key" \
  -out "$TMPDIR/ca.crt" -days 1 -nodes -subj "/CN=TestCA" 2>/dev/null

# Client RSA certificate signed by CA
openssl req -newkey rsa:2048 -keyout "$TMPDIR/client_rsa.key" \
  -out "$TMPDIR/client_rsa.csr" -nodes -subj "/CN=client-rsa" 2>/dev/null
openssl x509 -req -in "$TMPDIR/client_rsa.csr" -CA "$TMPDIR/ca.crt" \
  -CAkey "$TMPDIR/ca.key" -CAcreateserial -out "$TMPDIR/client_rsa.crt" \
  -days 1 2>/dev/null

# Client ECDSA certificate signed by CA
openssl ecparam -name prime256v1 -genkey -noout -out "$TMPDIR/client_ec.key" 2>/dev/null
openssl req -new -key "$TMPDIR/client_ec.key" \
  -out "$TMPDIR/client_ec.csr" -subj "/CN=client-ecdsa" 2>/dev/null
openssl x509 -req -in "$TMPDIR/client_ec.csr" -CA "$TMPDIR/ca.crt" \
  -CAkey "$TMPDIR/ca.key" -CAcreateserial -out "$TMPDIR/client_ec.crt" \
  -days 1 2>/dev/null

# Server ECDSA certificate (for KeyUpdate test variety)
openssl ecparam -name prime256v1 -genkey -noout -out "$TMPDIR/server_ec.key" 2>/dev/null
openssl req -x509 -new -key "$TMPDIR/server_ec.key" \
  -out "$TMPDIR/server_ec.crt" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

# ============================================================================
# Compile test binaries
# ============================================================================
mkdir -p tmp/tls13adv_units tmp/tls13adv_bin

echo "=== Compiling test binaries ==="
"$FPC" -B -Fu./src -FUtmp/tls13adv_units -FEtmp/tls13adv_bin \
  tests/crypto/test_tls13_client_cert.pas 2>&1 | tail -1

"$FPC" -Fu./src -FUtmp/tls13adv_units -FEtmp/tls13adv_bin \
  tests/crypto/test_tls13_keyupdate.pas 2>&1 | tail -1

"$FPC" -Fu./src -FUtmp/tls13adv_units -FEtmp/tls13adv_bin \
  tests/crypto/test_tls13_early_data_interop.pas 2>&1 | tail -1

CLIENT_CERT_BIN=tmp/tls13adv_bin/test_tls13_client_cert
KEYUPDATE_BIN=tmp/tls13adv_bin/test_tls13_keyupdate
EARLY_DATA_BIN=tmp/tls13adv_bin/test_tls13_early_data_interop

echo ""
echo "=== FreePascal TLS 1.3 Advanced Interop Matrix ==="
echo ""

# ============================================================================
# Test helpers
# ============================================================================

run_client_cert_test() {
  local name="$1" server_cert="$2" server_key="$3" \
        client_cert="$4" client_key="$5" port="$6"

  # Start s_server requiring client certificate
  openssl s_server -tls1_3 \
    -cert "$server_cert" -key "$server_key" \
    -CAfile "$TMPDIR/ca.crt" \
    -Verify 1 \
    -accept "$port" -www -quiet 2>/dev/null &
  local pid=$!
  PIDS+=("$pid")
  sleep 0.5

  if ! kill -0 "$pid" 2>/dev/null; then
    echo "[SKIP] $name (s_server failed to start)"
    SKIP=$((SKIP + 1))
    return
  fi

  if "$CLIENT_CERT_BIN" "$port" "$client_cert" "$client_key" >/dev/null 2>&1; then
    echo "[PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $name"
    "$CLIENT_CERT_BIN" "$port" "$client_cert" "$client_key" 2>&1 | head -20
    FAIL=$((FAIL + 1))
  fi

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

run_keyupdate_test() {
  local name="$1" cert="$2" key="$3" port="$4"

  # Start s_server in -www mode (handles multiple requests per connection)
  openssl s_server -tls1_3 \
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

  if "$KEYUPDATE_BIN" "$port" >/dev/null 2>&1; then
    echo "[PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $name"
    "$KEYUPDATE_BIN" "$port" 2>&1 | head -20
    FAIL=$((FAIL + 1))
  fi

  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
}

PORT=$BASE_PORT

# ============================================================================
# Client Certificate Authentication Tests
# ============================================================================
echo "--- Client Certificate Authentication ---"

run_client_cert_test "Client cert RSA (server RSA)" \
  "$TMPDIR/server.crt" "$TMPDIR/server.key" \
  "$TMPDIR/client_rsa.crt" "$TMPDIR/client_rsa.key" $((PORT + 0))

run_client_cert_test "Client cert ECDSA (server RSA)" \
  "$TMPDIR/server.crt" "$TMPDIR/server.key" \
  "$TMPDIR/client_ec.crt" "$TMPDIR/client_ec.key" $((PORT + 1))

run_client_cert_test "Client cert RSA (server ECDSA)" \
  "$TMPDIR/server_ec.crt" "$TMPDIR/server_ec.key" \
  "$TMPDIR/client_rsa.crt" "$TMPDIR/client_rsa.key" $((PORT + 2))

run_client_cert_test "Client cert ECDSA (server ECDSA)" \
  "$TMPDIR/server_ec.crt" "$TMPDIR/server_ec.key" \
  "$TMPDIR/client_ec.crt" "$TMPDIR/client_ec.key" $((PORT + 3))

echo ""

# ============================================================================
# KeyUpdate Tests
# ============================================================================
echo "--- KeyUpdate (client-initiated) ---"

run_keyupdate_test "KeyUpdate AES-256-GCM (RSA)" \
  "$TMPDIR/server.crt" "$TMPDIR/server.key" $((PORT + 4))

run_keyupdate_test "KeyUpdate AES-256-GCM (ECDSA)" \
  "$TMPDIR/server_ec.crt" "$TMPDIR/server_ec.key" $((PORT + 5))

# ============================================================================
# Early Data (0-RTT) Tests
# ============================================================================
echo ""
echo "--- Early Data (0-RTT) ---"

run_early_data_test() {
  local name="$1" cert="$2" key="$3" port="$4"

  # OpenSSL s_server with -early_data support
  openssl s_server -accept "$port" -cert "$cert" -key "$key" \
    -tls1_3 -early_data -HTTP -quiet 2>/dev/null &
  local srv_pid=$!
  PIDS+=("$srv_pid")
  sleep 0.3

  if "$EARLY_DATA_BIN" "$port" > /tmp/early_data_out_$$.txt 2>&1; then
    echo "[PASS] $name"
    PASS=$((PASS + 1))
  else
    local rc=$?
    if grep -q "SKIP" /tmp/early_data_out_$$.txt 2>/dev/null; then
      echo "[SKIP] $name (server did not issue resumable ticket)"
      SKIP=$((SKIP + 1))
    else
      echo "[FAIL] $name (exit=$rc)"
      cat /tmp/early_data_out_$$.txt 2>/dev/null | tail -5
      FAIL=$((FAIL + 1))
    fi
  fi
  rm -f /tmp/early_data_out_$$.txt

  kill "$srv_pid" 2>/dev/null || true
  wait "$srv_pid" 2>/dev/null || true
  PIDS=("${PIDS[@]/$srv_pid/}")
}

run_early_data_test "0-RTT early data (RSA)" \
  "$TMPDIR/server.crt" "$TMPDIR/server.key" $((PORT + 6))

echo ""
echo "=== Results: $PASS passed, $FAIL failed, $SKIP skipped ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
