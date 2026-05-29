#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$PROJECT_ROOT"

BIN_DIR="tests/bin"
mkdir -p "$BIN_DIR"

TESTS=(
  test_transport
  test_bufferpool
  test_ct_bigint
  test_dtls_layer
  test_sni_callback
  test_nonblocking
  test_p384
  test_p384_ecdsa_verify
  test_p384_validation
  test_timeout_stream
  test_argon2
  test_pkcs12_skeleton
  test_tls12_clientauth
  test_tls12_fragmented_clienthello
  test_tls12_resume_reject_fallback
  test_tls12_secure_renegotiation
  test_tls13_record_size_limit
  test_freepascal_cipher_config
  test_freepascal_verify_callback_runtime
  test_aesni_full
  test_ed25519_certverify
  test_x509_chain_ecdsa
  test_ct_pure
  test_rfc_vectors
  test_tls12_session_resume
  test_tls12_loopback_resume
  test_freepascal_library
  test_freepascal_certificate
  test_freepascal_certstore
  test_freepascal_connection_info
  test_freepascal_tls13_server
  test_tls13_psk_loopback
)

PASSED=0
FAILED=0
FAILED_NAMES=()

echo "=== Compiling unit tests ==="
for T in "${TESTS[@]}"; do
  if fpc -B -Fu"src" -Fu"src/crypto" -Fu"src/tls12" -Fu"src/tls13" -Fu"src/freepascal" -Fu"src/openssl" -Fu"src/mbedtls" -FE"$BIN_DIR" -FU"$BIN_DIR" -gh "tests/unit/${T}.pas" > /tmp/fpc_out_$$.txt 2>&1; then
    echo "  OK: $T"
  else
    echo "  COMPILE FAIL: $T"
    grep -i "error" /tmp/fpc_out_$$.txt || true
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$T (compile)")
  fi
done

echo
echo "=== Running unit tests ==="
for T in "${TESTS[@]}"; do
  if [ ! -f "$BIN_DIR/$T" ]; then
    continue
  fi
  OUTPUT=$("$BIN_DIR/$T" 2>&1 || true)

  if echo "$OUTPUT" | grep -q "passed$"; then
    SUMMARY=$(echo "$OUTPUT" | grep "passed$" | tail -1)
    echo "  PASS: $T ($SUMMARY)"
    PASSED=$((PASSED + 1))
  else
    echo "  FAIL: $T"
    echo "$OUTPUT" | grep -i "fail" | head -3
    FAILED=$((FAILED + 1))
    FAILED_NAMES+=("$T")
  fi

  if echo "$OUTPUT" | grep -q "unfreed memory blocks"; then
    LEAKS=$(echo "$OUTPUT" | grep "unfreed memory blocks" | grep -oP '\d+(?= unfreed)')
    if [ -n "$LEAKS" ] && [ "$LEAKS" != "0" ]; then
      echo "    LEAK: $LEAKS unfreed blocks"
    fi
  fi
done

rm -f /tmp/fpc_out_$$.txt

echo
echo "=== Summary ==="
echo "Passed: $PASSED / $((PASSED + FAILED))"
if [ ${#FAILED_NAMES[@]} -gt 0 ]; then
  echo "Failed: ${FAILED_NAMES[*]}"
  exit 1
fi
echo "All unit tests passed!"
