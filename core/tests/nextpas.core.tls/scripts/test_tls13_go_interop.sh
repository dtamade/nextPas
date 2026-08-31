#!/usr/bin/env bash
# TLS 1.3 Interop: FreePascal client vs Go crypto/tls server
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$PROJECT_ROOT"

FPC="${NEXTPAS_FPC_EXE:-/opt/fpcupdeluxe/fpc/bin/x86_64-linux/fpc}"
PORT=44800
TMPDIR=$(mktemp -d)

cleanup() {
  kill "$GO_PID" 2>/dev/null || true
  wait "$GO_PID" 2>/dev/null || true
  rm -rf "$TMPDIR"
}
trap cleanup EXIT

# Generate test certificate
openssl req -x509 -newkey rsa:2048 -keyout "$TMPDIR/key.pem" \
  -out "$TMPDIR/cert.pem" -days 1 -nodes -subj "/CN=localhost" 2>/dev/null

# Write Go TLS server
cat > "$TMPDIR/server.go" << 'GOEOF'
package main

import (
	"crypto/tls"
	"fmt"
	"os"
)

func main() {
	port := os.Args[1]
	certFile := os.Args[2]
	keyFile := os.Args[3]

	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		fmt.Fprintf(os.Stderr, "LoadX509KeyPair: %v\n", err)
		os.Exit(1)
	}

	config := &tls.Config{
		Certificates: []tls.Certificate{cert},
		MinVersion:   tls.VersionTLS13,
	}

	ln, err := tls.Listen("tcp", "127.0.0.1:"+port, config)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Listen: %v\n", err)
		os.Exit(1)
	}
	defer ln.Close()

	fmt.Println("READY")

	for i := 0; i < 3; i++ {
		conn, err := ln.Accept()
		if err != nil {
			continue
		}
		tlsConn := conn.(*tls.Conn)
		tlsConn.Handshake()
		buf := make([]byte, 4096)
		n, _ := tlsConn.Read(buf)
		if n > 0 {
			response := "HTTP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nOK"
			tlsConn.Write([]byte(response))
		}
		conn.Close()
	}
}
GOEOF

# Compile Go server
go build -o "$TMPDIR/goserver" "$TMPDIR/server.go"

# Start Go server
"$TMPDIR/goserver" "$PORT" "$TMPDIR/cert.pem" "$TMPDIR/key.pem" &
GO_PID=$!
sleep 0.5

if ! kill -0 "$GO_PID" 2>/dev/null; then
  echo "[FATAL] Go TLS server failed to start"
  exit 1
fi

# Compile FreePascal PSK test
mkdir -p tmp/go_interop_units tmp/go_interop_bin
"$FPC" -B -Fu"$PWD/core/src" -FUtmp/go_interop_units -FEtmp/go_interop_bin \
  core/tests/nextpas.core.tls/crypto/test_tls13_psk_openssl.pas 2>&1 | tail -1

BIN=tmp/go_interop_bin/test_tls13_psk_openssl

echo "=== FreePascal TLS 1.3 vs Go crypto/tls ==="

# 落盘后判定：grep -q 早退会 SIGPIPE 截断测试二进制输出；pipefail 下二进制
# 非零退出也会污染管道状态——崩溃无 FAIL 串时会被误判为通过
set +e
"$BIN" "$PORT" > "$TMPDIR/output.log" 2>&1
BIN_RC=$?
set -e

if [[ $BIN_RC -ne 0 ]] || grep -q "FAIL" "$TMPDIR/output.log"; then
  echo ""
  echo "[FAIL] Go interop failed (exit=$BIN_RC)"
  grep "FAIL" "$TMPDIR/output.log" || true
  exit 1
fi

PASS_COUNT=$(grep -c "PASS" "$TMPDIR/output.log" || echo 0)
echo ""
echo "[PASS] Go crypto/tls interop: $PASS_COUNT assertions passed"
