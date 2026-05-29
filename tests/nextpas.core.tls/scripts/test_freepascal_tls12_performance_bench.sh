#!/usr/bin/env bash
# P10 Performance benchmark: TLS 1.2 handshake latency
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${FAFAFA_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
PORT=44350
ITERATIONS=20
TMPDIR=$(mktemp -d)

cleanup() {
  [[ -n "${SERVER_PID:-}" ]] && kill "$SERVER_PID" 2>/dev/null || true
  wait "$SERVER_PID" 2>/dev/null || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/server.key" \
  -out "$TMPDIR/server.crt" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

# Compile
mkdir -p tmp/tls12smoke_units tmp/tls12smoke_bin
"$FPC" -B -O2 -Fu./src -Fu./tests -Fu./tests/framework \
  -FUtmp/tls12smoke_units -FEtmp/tls12smoke_bin \
  tests/crypto/test_tls12_openssl_smoke.pas 2>&1 | tail -1

BIN=tmp/tls12smoke_bin/test_tls12_openssl_smoke
if [[ ! -f "$BIN" ]]; then
  echo "[FATAL] Binary did not compile"
  exit 1
fi

echo "=== TLS 1.2 Handshake Performance Benchmark ==="
echo "Cipher: ECDHE-RSA-AES128-GCM-SHA256 (X25519)"
echo "Iterations: $ITERATIONS"
echo ""

# Start server
openssl s_server -tls1_2 \
  -cipher ECDHE-RSA-AES128-GCM-SHA256 \
  -groups X25519 \
  -cert "$TMPDIR/server.crt" -key "$TMPDIR/server.key" \
  -accept "$PORT" -www -quiet 2>/dev/null &
SERVER_PID=$!
sleep 1

if ! kill -0 "$SERVER_PID" 2>/dev/null; then
  echo "[FATAL] Server failed to start"
  exit 1
fi

TOTAL_MS=0
PASS=0
FAIL=0

for i in $(seq 1 $ITERATIONS); do
  START=$(date +%s%N)
  if "$BIN" "$PORT" >/dev/null 2>&1; then
    END=$(date +%s%N)
    ELAPSED_MS=$(( (END - START) / 1000000 ))
    TOTAL_MS=$((TOTAL_MS + ELAPSED_MS))
    PASS=$((PASS + 1))
  else
    FAIL=$((FAIL + 1))
  fi
done

if [[ $PASS -gt 0 ]]; then
  AVG_MS=$((TOTAL_MS / PASS))
  echo "Results: $PASS/$ITERATIONS successful"
  echo "Average handshake+data: ${AVG_MS}ms"
  echo ""

  if [[ $AVG_MS -lt 150 ]]; then
    echo "[PASS] Handshake latency under 150ms threshold (includes process startup)"
  elif [[ $AVG_MS -lt 300 ]]; then
    echo "[WARN] Handshake latency ${AVG_MS}ms (target: <150ms)"
  else
    echo "[FAIL] Handshake latency ${AVG_MS}ms exceeds 300ms"
    exit 1
  fi
else
  echo "[FAIL] All $ITERATIONS attempts failed"
  exit 1
fi
