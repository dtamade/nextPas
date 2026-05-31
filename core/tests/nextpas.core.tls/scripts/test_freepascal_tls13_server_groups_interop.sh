#!/usr/bin/env bash
# TLS 1.3 Server-side key_share interop: FreePascal server vs OpenSSL s_client
# Verifies the FreePascal server accepts X25519, P-256, and P-384 key shares.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${FAFAFA_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
BASE_PORT=44720
TMPDIR=$(mktemp -d)
PASS=0
FAIL=0

cleanup() {
  for pid in "${PIDS[@]:-}"; do
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  done
  rm -rf "$TMPDIR"
  rm -f server.crt server.key
}
trap cleanup EXIT
declare -a PIDS=()

# Server certificate (RSA leaf; key exchange group is independent of cert type)
openssl req -x509 -newkey rsa:2048 -keyout server.key \
  -out server.crt -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

echo "=== Compiling FreePascal TLS 1.3 server ==="
"$FPC" -B -Fu./src -Fu./src/crypto -Fu./src/tls12 -Fu./src/tls13 \
  -Fu./src/freepascal -Fu./src/openssl -Fu./src/mbedtls -Fu./examples \
  -FUtmp/srv_interop_units -FEtmp/srv_interop_bin \
  examples/10_freepascal_tls13_server.pas 2>&1 | tail -1

SERVER_BIN=tmp/srv_interop_bin/10_freepascal_tls13_server

echo ""
echo "=== FreePascal TLS 1.3 Server key_share Interop ==="
echo ""

run_group_test() {
  local name="$1" group="$2" port="$3"

  "$SERVER_BIN" "$port" once > /tmp/srv_out_$$.txt 2>&1 &
  local srv_pid=$!
  PIDS+=("$srv_pid")
  sleep 0.4

  # Force a single key_share group; -tls1_3 ensures TLS 1.3 only.
  echo "Q" | timeout 8 openssl s_client -connect "127.0.0.1:$port" \
    -tls1_3 -groups "$group" -servername localhost \
    > /tmp/cli_out_$$.txt 2>&1 || true

  # Wait for the one-shot server to exit and capture its status.
  if wait "$srv_pid" 2>/dev/null; then
    local srv_rc=0
  else
    local srv_rc=$?
  fi
  PIDS=("${PIDS[@]/$srv_pid/}")

  if [[ "$srv_rc" == "0" ]] && grep -q "Verify return code\|New, TLSv1.3\|^GET\|HTTP/1.1 200" /tmp/cli_out_$$.txt; then
    echo "[PASS] $name"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] $name (server rc=$srv_rc)"
    echo "  --- server output ---"; sed 's/^/  /' /tmp/srv_out_$$.txt | tail -4
    echo "  --- client output ---"; sed 's/^/  /' /tmp/cli_out_$$.txt | tail -6
    FAIL=$((FAIL + 1))
  fi
  rm -f /tmp/srv_out_$$.txt /tmp/cli_out_$$.txt
}

run_group_test "Server accepts X25519 key_share"  "X25519"   $((BASE_PORT + 0))
run_group_test "Server accepts P-256 key_share"   "P-256"    $((BASE_PORT + 1))
run_group_test "Server accepts P-384 key_share"   "P-384"    $((BASE_PORT + 2))

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="

if [[ $FAIL -gt 0 ]]; then
  exit 1
fi
