#!/bin/bash
# TLS 1.3 E2E test runner — starts openssl s_server, runs test, cleans up
set -e
PORT=15555

# Generate cert if needed
if [ ! -f /tmp/tls13_test_cert.pem ]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1 \
    -keyout /tmp/tls13_test_key.pem -out /tmp/tls13_test_cert.pem \
    -days 1 -nodes -subj "/CN=localhost" 2>/dev/null
fi

# Kill any existing server on this port
kill $(lsof -ti :$PORT) 2>/dev/null || true
sleep 0.5

# Start server (pipe keeps stdin open, -www allows multiple connections)
(sleep 30) | openssl s_server -4 \
  -key /tmp/tls13_test_key.pem \
  -cert /tmp/tls13_test_cert.pem \
  -accept $PORT -www >/dev/null 2>/dev/null &
SERVER_PID=$!
sleep 1.5

# Verify server is listening
if ! lsof -i :$PORT >/dev/null 2>&1; then
  echo "FATAL: Server failed to start on port $PORT"
  exit 1
fi

# Run test
DIR="$(cd "$(dirname "$0")" && pwd)"
"$DIR/test_tls13_e2e_openssl"
RESULT=$?

# Cleanup
kill $SERVER_PID 2>/dev/null || true
wait $SERVER_PID 2>/dev/null || true

exit $RESULT
