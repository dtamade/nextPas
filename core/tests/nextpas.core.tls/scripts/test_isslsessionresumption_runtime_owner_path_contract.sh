#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

check_owner_path() {
  local file="$1"
  shift
  for pattern in "$@"; do
    if ! grep -F -q -- "$pattern" "$file"; then
      echo "[FAIL] missing ISSLSessionResumption owner-path usage in $file: $pattern"
      exit 1
    fi
  done
}

check_no_core_path() {
  local file="$1"
  if rg -n --quiet '\b(?:Conn|LConn|LConn1|LConn2|ResumedConn|InitialConn)\.(?:GetSession|SetSession|IsSessionReused)\b' "$file"; then
    echo "[FAIL] direct core session-resumption mirror still present in $file"
    exit 1
  fi
}

builder_file="tests/test_connection_builder_hostname_precedence.pas"
fp_cert_file="tests/test_freepascal_client_certificate_flight_requirements.pas"
fp_client_file="tests/test_freepascal_client_session_resumption.pas"
fp_server_file="tests/test_freepascal_server_session_resumption.pas"
earlydata_file="tests/test_openssl_wolfssl_early_data_connection_contract.pas"
builder_src="src/nextpas.core.tls.connection.builder.pas"
tls_src="src/nextpas.core.tls.tls.pas"

for file in \
  "$builder_file" \
  "$fp_cert_file" \
  "$fp_client_file" \
  "$fp_server_file" \
  "$earlydata_file" \
  "$builder_src" \
  "$tls_src"; do
  check_no_core_path "$file"
done

check_owner_path "$builder_file" \
  "Resumption: ISSLSessionResumption;" \
  "Supports(Conn, ISSLSessionResumption, Resumption)" \
  "Resumption.SetSession(TMockSession.Create("

check_owner_path "$fp_cert_file" \
  "LResumption: ISSLSessionResumption;" \
  "Supports(LConn, ISSLSessionResumption, LResumption)" \
  "LResumption.SetSession(LSession);" \
  "LResumption.IsSessionReused"

check_owner_path "$fp_client_file" \
  "LResumption1: ISSLSessionResumption;" \
  "LResumption2: ISSLSessionResumption;" \
  "Supports(LConn1, ISSLSessionResumption, LResumption1)" \
  "LSession := LResumption1.GetSession;" \
  "Supports(LConn2, ISSLSessionResumption, LResumption2)" \
  "LResumption2.SetSession(LSession);" \
  "LResumption2.IsSessionReused"

check_owner_path "$fp_server_file" \
  "LResumption1: ISSLSessionResumption;" \
  "LResumption2: ISSLSessionResumption;" \
  "Supports(LConn1, ISSLSessionResumption, LResumption1)" \
  "not LResumption1.IsSessionReused" \
  "Supports(LConn2, ISSLSessionResumption, LResumption2)" \
  "LResumption2.IsSessionReused"

check_owner_path "$earlydata_file" \
  "LResumption: ISSLSessionResumption;" \
  "Supports(LConn, ISSLSessionResumption, LResumption)" \
  "LResumption.SetSession(TMockSession.Create('mock-session'));"

check_owner_path "$builder_src" \
  "SessionResumption: ISSLSessionResumption;" \
  "Supports(AConnection, ISSLSessionResumption, SessionResumption)" \
  "SessionResumption.SetSession(FSession);"

check_owner_path "$tls_src" \
  "SessionResumption: ISSLSessionResumption;" \
  "Supports(AConn, ISSLSessionResumption, SessionResumption)" \
  "SessionResumption.SetSession(FSession);"

echo "[PASS] selected runtime tests now prefer ISSLSessionResumption owner path"
