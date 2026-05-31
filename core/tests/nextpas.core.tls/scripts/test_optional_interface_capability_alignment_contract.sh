#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_match() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

openssl_context="src/nextpas.core.tls.openssl.context.pas"
openssl_lib="src/nextpas.core.tls.openssl.backed.pas"
openssl_connection="src/nextpas.core.tls.openssl.connection.pas"
wolfssl_context="src/nextpas.core.tls.wolfssl.context.pas"
wolfssl_lib="src/nextpas.core.tls.wolfssl.lib.pas"
wolfssl_connection="src/nextpas.core.tls.wolfssl.connection.pas"

printf '[TEST] optional interface capability alignment contract\n'

require_match "$openssl_context" \
  'TOpenSSLContext = class\(TInterfacedObject, ISSLContext, ISSLNativeHandleAccess,\s*ISSLHttpHooksAccess\)' \
  'OpenSSL base context no longer implements optional early-data or server-OCSP interfaces unconditionally'
require_match "$openssl_context" \
  'TOpenSSLEarlyDataContext = class\(TOpenSSLContext, ISSLEarlyDataContext\)' \
  'OpenSSL declares a dedicated early-data context subclass'
require_match "$openssl_context" \
  'TOpenSSLServerOCSPContext = class\(TOpenSSLContext, ISSLServerOCSPStaplingContext\)' \
  'OpenSSL declares a dedicated server-OCSP context subclass'
require_match "$openssl_context" \
  'TOpenSSLAdvancedContext = class\(TOpenSSLContext,\s*ISSLEarlyDataContext, ISSLServerOCSPStaplingContext\)' \
  'OpenSSL declares a combined optional-interface context subclass when both capabilities are present'
require_match "$openssl_lib" \
  'LExposeEarlyData := GetCapabilities\.EarlyDataSupport <> sslSupportNone;.*?LExposeServerOCSP := \(AType in \[sslCtxServer, sslCtxBoth\]\) and\s*\(GetCapabilities\.OCSPStaplingSupport <> sslSupportNone\);.*?TOpenSSLAdvancedContext\.Create.*?TOpenSSLEarlyDataContext\.Create.*?TOpenSSLServerOCSPContext\.Create.*?TOpenSSLContext\.Create' \
  'OpenSSL library create-context path selects the optional-interface subclass that matches current capability truth'

require_match "$openssl_connection" \
  'TOpenSSLConnection = class\(TBaseSSLConnection, ISSLClientConnection,\s*ISSLNativeHandleAccess\)' \
  'OpenSSL base connection no longer implements optional OCSP or early-data connection interfaces unconditionally'
require_match "$openssl_connection" \
  'TOpenSSLOCSPConnection = class\(TOpenSSLConnection, ISSLOCSPStapling\)' \
  'OpenSSL declares a dedicated OCSP connection subclass'
require_match "$openssl_connection" \
  'TOpenSSLEarlyDataConnection = class\(TOpenSSLConnection, ISSLEarlyDataConnection\)' \
  'OpenSSL declares a dedicated early-data connection subclass'
require_match "$openssl_connection" \
  'TOpenSSLAdvancedConnection = class\(TOpenSSLEarlyDataConnection, ISSLOCSPStapling\)' \
  'OpenSSL declares a combined early-data plus OCSP connection subclass'
require_match "$openssl_context" \
  'function TOpenSSLContext\.CreateConnection\(ASocket: THandle\): ISSLConnection;.*?LExposeEarlyData := Supports\(Self, ISSLEarlyDataContext, LEarlyDataContext\);.*?LExposeOCSP := HasClientOCSPCapability;.*?TOpenSSLAdvancedConnection\.Create\(Self, ASocket\).*?TOpenSSLEarlyDataConnection\.Create\(Self, ASocket\).*?TOpenSSLOCSPConnection\.Create\(Self, ASocket\).*?TOpenSSLConnection\.Create\(Self, ASocket\)' \
  'OpenSSL socket connection path selects the OCSP/early-data subclass matrix that matches current capability truth'
require_match "$openssl_context" \
  'function TOpenSSLContext\.CreateConnection\(AStream: TStream\): ISSLConnection;.*?LExposeEarlyData := Supports\(Self, ISSLEarlyDataContext, LEarlyDataContext\);.*?LExposeOCSP := HasClientOCSPCapability;.*?TOpenSSLAdvancedConnection\.Create\(Self, AStream\).*?TOpenSSLEarlyDataConnection\.Create\(Self, AStream\).*?TOpenSSLOCSPConnection\.Create\(Self, AStream\).*?TOpenSSLConnection\.Create\(Self, AStream\)' \
  'OpenSSL stream connection path selects the OCSP/early-data subclass matrix that matches current capability truth'

require_match "$wolfssl_context" \
  'TWolfSSLContext = class\(TInterfacedObject, ISSLContext, ISSLNativeHandleAccess\)' \
  'WolfSSL base context no longer implements server OCSP stapling unconditionally'
require_match "$wolfssl_context" \
  'TWolfSSLOCSPStaplingContext = class\(TWolfSSLContext, ISSLServerOCSPStaplingContext\)' \
  'WolfSSL declares a dedicated server-OCSP context subclass'
require_match "$wolfssl_context" \
  'TWolfSSLAdvancedContext = class\(TWolfSSLContext,\s*ISSLEarlyDataContext, ISSLServerOCSPStaplingContext\)' \
  'WolfSSL declares a combined optional-interface context subclass when both capabilities are present'
require_match "$wolfssl_lib" \
  'LExposeEarlyData := GetCapabilities\.EarlyDataSupport <> sslSupportNone;.*?LExposeServerOCSP := \(AType in \[sslCtxServer, sslCtxBoth\]\) and\s*\(GetCapabilities\.OCSPStaplingSupport <> sslSupportNone\);.*?TWolfSSLAdvancedContext\.Create.*?TWolfSSLEarlyDataContext\.Create.*?TWolfSSLOCSPStaplingContext\.Create.*?TWolfSSLContext\.Create' \
  'WolfSSL library create-context path selects the optional-interface subclass that matches current capability truth'
require_match "$wolfssl_connection" \
  'TWolfSSLConnection = class\(TBaseSSLConnection, ISSLClientConnection,\s*ISSLNativeHandleAccess\)' \
  'WolfSSL base connection no longer implements optional OCSP or early-data connection interfaces unconditionally'
require_match "$wolfssl_connection" \
  'TWolfSSLOCSPConnection = class\(TWolfSSLConnection, ISSLOCSPStapling\)' \
  'WolfSSL declares a dedicated OCSP connection subclass'
require_match "$wolfssl_connection" \
  'TWolfSSLEarlyDataConnection = class\(TWolfSSLConnection, ISSLEarlyDataConnection\)' \
  'WolfSSL declares a dedicated early-data connection subclass'
require_match "$wolfssl_connection" \
  'TWolfSSLAdvancedConnection = class\(TWolfSSLEarlyDataConnection, ISSLOCSPStapling\)' \
  'WolfSSL declares a combined early-data plus OCSP connection subclass'
require_match "$wolfssl_context" \
  'function TWolfSSLContext\.CreateConnection\(ASocket: THandle\): ISSLConnection;.*?LExposeEarlyData := HasEarlyDataCapability;.*?LExposeOCSP := HasClientOCSPCapability;.*?TWolfSSLAdvancedConnection\.Create\(Self, ASocket\).*?TWolfSSLEarlyDataConnection\.Create\(Self, ASocket\).*?TWolfSSLOCSPConnection\.Create\(Self, ASocket\).*?TWolfSSLConnection\.Create\(Self, ASocket\)' \
  'WolfSSL socket connection path selects the OCSP/early-data subclass matrix that matches current capability truth'
require_match "$wolfssl_context" \
  'function TWolfSSLContext\.CreateConnection\(AStream: TStream\): ISSLConnection;.*?LExposeEarlyData := HasEarlyDataCapability;.*?LExposeOCSP := HasClientOCSPCapability;.*?TWolfSSLAdvancedConnection\.Create\(Self, AStream\).*?TWolfSSLEarlyDataConnection\.Create\(Self, AStream\).*?TWolfSSLOCSPConnection\.Create\(Self, AStream\).*?TWolfSSLConnection\.Create\(Self, AStream\)' \
  'WolfSSL stream connection path selects the OCSP/early-data subclass matrix that matches current capability truth'

printf '[PASS] optional interface capability alignment contract passed\n'
