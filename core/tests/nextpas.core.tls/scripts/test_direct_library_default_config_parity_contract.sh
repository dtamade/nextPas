#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

check_file() {
  local file="$1"
  local class_name="$2"

  if ! rg -n --quiet 'TSSLFactory\.NormalizeConfig\(LConfig\);' "$file"; then
    echo "[FAIL] $file does not normalize library default config before storing it"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetProtocolVersions\(LConfig\.ProtocolVersions\);' "$file"; then
    echo "[FAIL] $file does not apply ProtocolVersions on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetPreferredVersion\(LConfig\.PreferredVersion\);' "$file"; then
    echo "[FAIL] $file does not apply PreferredVersion on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetVerifyMode\(LVerifyMode\);' "$file"; then
    echo "[FAIL] $file does not apply VerifyMode on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetVerifyDepth\(LConfig\.VerifyDepth\);' "$file"; then
    echo "[FAIL] $file does not apply VerifyDepth on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetCipherList\(LConfig\.CipherList\);' "$file"; then
    echo "[FAIL] $file does not apply CipherList on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetCipherSuites\(LConfig\.CipherSuites\);' "$file"; then
    echo "[FAIL] $file does not apply CipherSuites on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetOptions\(LConfig\.Options\);' "$file"; then
    echo "[FAIL] $file does not apply Options on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetSessionCacheSize\(LConfig\.SessionCacheSize\);' "$file"; then
    echo "[FAIL] $file does not apply SessionCacheSize on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetSessionTimeout\(LConfig\.SessionTimeout\);' "$file"; then
    echo "[FAIL] $file does not apply SessionTimeout on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetSessionCacheMode\(ssoEnableSessionCache in LConfig\.Options\);' "$file"; then
    echo "[FAIL] $file does not apply SessionCacheMode on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet 'Result\.SetALPNProtocols\(LConfig\.ALPNProtocols\);' "$file"; then
    echo "[FAIL] $file does not apply ALPNProtocols on the direct-library context path"
    exit 1
  fi

  if ! rg -n --quiet "${class_name}\.CreateContext\(AType: TSSLContextType\)" "$file"; then
    echo "[FAIL] $file no longer contains ${class_name}.CreateContext"
    exit 1
  fi
}

check_file "src/nextpas.core.tls.freepascal.lib.pas" "TFreePascalSSLLibrary"
check_file "src/nextpas.core.tls.winssl.lib.pas" "TWinSSLLibrary"
check_file "src/nextpas.core.tls.mbedtls.lib.pas" "TMbedTLSLibrary"
check_file "src/nextpas.core.tls.wolfssl.lib.pas" "TWolfSSLLibrary"

echo "[PASS] direct-library default-config parity remains aligned across backend library paths"
