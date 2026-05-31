#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FACADE_FILE="$ROOT_DIR/src/nextpas.core.tls.pas"
CONN_BASE_FILE="$ROOT_DIR/src/nextpas.core.tls.connection.base.pas"
HOSTNAME_PRECEDENCE_FILE="$ROOT_DIR/tests/test_connection_builder_hostname_precedence.pas"

echo "[TEST] managed result init safety contract"

python3 - "$FACADE_FILE" "$CONN_BASE_FILE" "$HOSTNAME_PRECEDENCE_FILE" <<'PY'
from pathlib import Path
import re
import sys

facade = Path(sys.argv[1]).read_text(encoding="utf-8")
conn_base = Path(sys.argv[2]).read_text(encoding="utf-8")
hostname_precedence = Path(sys.argv[3]).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

def extract_function(text: str, signature: str) -> str:
    m = re.search(rf"{re.escape(signature)}.*?^end;", text, re.S | re.M)
    require(m is not None, f"function exists: {signature}")
    return m.group(0)

create_default = extract_function(
    facade, "function CreateDefaultConfig(AContextType: TSSLContextType): TSSLConfig;"
)
conn_info = extract_function(
    conn_base, "function TBaseSSLConnection.GetConnectionInfo: TSSLConnectionInfo;"
)
diag_info = extract_function(
    conn_base, "function TBaseSSLConnection.GetDiagnosticInfo: TSSLDiagnosticInfo;"
)
ocsp_resp = extract_function(
    conn_base, "function TBaseSSLConnection.DoGetOCSPResponse: TBytes;"
)
sct_list = extract_function(
    conn_base, "function TBaseSSLConnection.DoGetSignedCertificateTimestampList: TBytes;"
)
save_to_der = extract_function(
    hostname_precedence, "function TMockCertificate.SaveToDER: TBytes;"
)
serialize = extract_function(
    hostname_precedence, "function TMockSession.Serialize: TBytes;"
)

require("Result := Default(TSSLConfig);" in create_default,
        "CreateDefaultConfig fallback uses Default(TSSLConfig)")
require("FillChar(Result, SizeOf(Result), 0);" not in create_default,
        "CreateDefaultConfig no longer zeroes a managed TSSLConfig result with FillChar")

require("Result := Default(TSSLConnectionInfo);" in conn_info,
        "GetConnectionInfo uses Default(TSSLConnectionInfo)")
require("FillChar(Result, SizeOf(Result), 0);" not in conn_info,
        "GetConnectionInfo no longer zeroes a managed TSSLConnectionInfo result with FillChar")

require("Result := Default(TSSLDiagnosticInfo);" in diag_info,
        "GetDiagnosticInfo uses Default(TSSLDiagnosticInfo)")
require("FillChar(Result, SizeOf(Result), 0);" not in diag_info,
        "GetDiagnosticInfo no longer zeroes a managed TSSLDiagnosticInfo result with FillChar")

require("Result := nil;" in ocsp_resp,
        "DoGetOCSPResponse uses nil for the empty TBytes default")
require("SetLength(Result, 0);" not in ocsp_resp,
        "DoGetOCSPResponse no longer uses SetLength on an uninitialized TBytes result")

require("Result := nil;" in sct_list,
        "DoGetSignedCertificateTimestampList uses nil for the empty TBytes default")
require("SetLength(Result, 0);" not in sct_list,
        "DoGetSignedCertificateTimestampList no longer uses SetLength on an uninitialized TBytes result")

require("Result := nil;" in save_to_der,
        "TMockCertificate.SaveToDER uses nil for the empty TBytes default")
require("SetLength(Result, 0);" not in save_to_der,
        "TMockCertificate.SaveToDER no longer uses SetLength on an uninitialized TBytes result")

require("Result := nil;" in serialize,
        "TMockSession.Serialize uses nil for the empty TBytes default")
require("SetLength(Result, 0);" not in serialize,
        "TMockSession.Serialize no longer uses SetLength on an uninitialized TBytes result")
PY

echo "[PASS] managed result init safety contract passed"
