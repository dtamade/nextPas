#!/usr/bin/env bash
# TLS 1.3 PSK Session Resumption Interop Test
# FreePascal client vs OpenSSL s_server
set -euo pipefail
SPID=""

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${NEXTPAS_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
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
"$FPC" -B -Fu"$PWD/core/src" -FUtmp/psk_gate_units -FEtmp/psk_gate_bin \
  core/tests/nextpas.core.tls/crypto/test_tls13_psk_openssl.pas 2>&1 | tail -1

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

# 落盘后判定：grep -q 早退会 SIGPIPE 截断测试二进制输出；pipefail 下二进制
# 非零退出也会污染管道状态——崩溃无 FAIL 串时会被误判为通过
set +e
"$BIN" "$PORT" > "$TMPDIR/output.log" 2>&1
BIN_RC=$?
set -e

if [[ $BIN_RC -ne 0 ]] || grep -q "FAIL" "$TMPDIR/output.log"; then
  echo ""
  echo "[FAIL] PSK resumption interop failed (exit=$BIN_RC)"
  grep "FAIL" "$TMPDIR/output.log" || true
  exit 1
fi

PASS_COUNT=$(grep -c "PASS" "$TMPDIR/output.log" || echo 0)
echo ""
echo "[PASS] TLS 1.3 PSK resumption: $PASS_COUNT assertions passed"
