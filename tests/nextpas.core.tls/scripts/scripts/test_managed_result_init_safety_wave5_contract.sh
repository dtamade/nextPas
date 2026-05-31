#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPSCHEDULE_FILE="$ROOT_DIR/src/nextpas.core.tls.tls13.appschedule.pas"
SERVERHELLO_FILE="$ROOT_DIR/src/nextpas.core.tls.tls13.serverhello.pas"
RESUMPTION_TEST_FILE="$ROOT_DIR/tests/test_tls13_resumption.pas"

echo "[TEST] managed result init safety wave5 contract"

python3 - "$APPSCHEDULE_FILE" "$SERVERHELLO_FILE" "$RESUMPTION_TEST_FILE" <<'PY'
from pathlib import Path
import re
import sys

appschedule = Path(sys.argv[1]).read_text(encoding="utf-8")
serverhello = Path(sys.argv[2]).read_text(encoding="utf-8")
resumption = Path(sys.argv[3]).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

def require_text(text: str, needle: str, label: str) -> None:
    require(needle in text, f"function exists: {label}")

require_text(appschedule, "function TLS13ComputeResumptionMasterSecretFromTranscriptHash(", "TLS13ComputeResumptionMasterSecretFromTranscriptHash")
require_text(appschedule, "function TLS13DeriveResumptionPSKFromTranscriptHash(", "TLS13DeriveResumptionPSKFromTranscriptHash")
require_text(appschedule, "function HashTranscriptForSuite(ACipherSuite: Word; const AData: TBytes): TBytes;", "HashTranscriptForSuite")
require_text(appschedule, "function HKDFExtractForSuite(ACipherSuite: Word; const ASalt, AIKM: TBytes): TBytes;", "HKDFExtractForSuite")
require_text(appschedule, "function HKDFExpandLabelForSuite(", "HKDFExpandLabelForSuite")

require_text(serverhello, "function BuildExtensionHeader(AType: Word; const AData: TBytes): TBytes;", "BuildExtensionHeader")
require_text(serverhello, "function BuildTLS13ServerHelloBody(", "BuildTLS13ServerHelloBody")
require_text(serverhello, "function BuildTLS13ServerHelloHandshake(", "BuildTLS13ServerHelloHandshake")
require_text(serverhello, "function BuildTLS13ServerHelloHandshakeWithSelectedPSK(", "BuildTLS13ServerHelloHandshakeWithSelectedPSK")

require_text(resumption, "function HexToBytes(const AHex: string): TBytes;", "HexToBytes")

require(
    re.search(r"function TLS13ComputeResumptionMasterSecretFromTranscriptHash\(.*?\): TBytes;.*?begin.*?Result := nil;.*?LHashSize := TLS13CipherSuiteHashSize\(ACipherSuite\);", appschedule, re.S)
    is not None,
    "TLS13ComputeResumptionMasterSecretFromTranscriptHash initializes empty TBytes result with nil before validation",
)
require(
    re.search(r"function TLS13DeriveResumptionPSKFromTranscriptHash\(.*?\): TBytes;.*?begin.*?Result := nil;.*?LHashSize := TLS13CipherSuiteHashSize\(ACipherSuite\);", appschedule, re.S)
    is not None,
    "TLS13DeriveResumptionPSKFromTranscriptHash initializes empty TBytes result with nil before validation",
)
require(
    re.search(r"function HashTranscriptForSuite\(ACipherSuite: Word; const AData: TBytes\): TBytes;.*?begin.*?Result := nil;.*?if TLS13CipherSuiteIsSHA256\(ACipherSuite\) then.*?Exit\(SHA256\(AData\)\);", appschedule, re.S)
    is not None,
    "appschedule HashTranscriptForSuite initializes empty TBytes result with nil before early exits",
)
require(
    re.search(r"function HKDFExtractForSuite\(ACipherSuite: Word; const ASalt, AIKM: TBytes\): TBytes;.*?begin.*?Result := nil;.*?if TLS13CipherSuiteIsSHA256\(ACipherSuite\) then.*?Exit\(HKDF_Extract_SHA256\(ASalt, AIKM\)\);", appschedule, re.S)
    is not None,
    "appschedule HKDFExtractForSuite initializes empty TBytes result with nil before early exits",
)
require(
    re.search(r"function HKDFExpandLabelForSuite\(.*?\): TBytes;.*?begin.*?Result := nil;.*?if TLS13CipherSuiteIsSHA256\(ACipherSuite\) then.*?Exit\(TLS13_HKDF_Expand_Label_SHA256\(ASecret, ALabel, AContext, ALength\)\);", appschedule, re.S)
    is not None,
    "appschedule HKDFExpandLabelForSuite initializes empty TBytes result with nil before early exits",
)

for signature in [
    r"function TLS13ComputeResumptionMasterSecretFromTranscriptHash\(.*?end;",
    r"function TLS13DeriveResumptionPSKFromTranscriptHash\(.*?end;",
    r"function HashTranscriptForSuite\(.*?end;",
    r"function HKDFExtractForSuite\(.*?end;",
    r"function HKDFExpandLabelForSuite\(.*?end;",
]:
    block = re.search(signature, appschedule, re.S)
    require(block is not None, f"block exists: {signature}")
    require("SetLength(Result, 0);" not in block.group(0), f"{signature} no longer uses SetLength(Result, 0)")

require(
    re.search(r"function BuildExtensionHeader\(AType: Word; const AData: TBytes\): TBytes;.*?begin.*?Result := nil;.*?AppendUInt16\(Result, AType\);", serverhello, re.S)
    is not None,
    "BuildExtensionHeader initializes empty TBytes result with nil before building the extension header",
)
require(
    re.search(r"function BuildTLS13ServerHelloBody\(.*?\): TBytes;.*?begin.*?Result := nil;.*?if Length\(ALegacySessionID\) > 32 then.*?Result := nil;.*?AppendUInt16\(Result, TLS_LEGACY_VERSION\);", serverhello, re.S)
    is not None,
    "BuildTLS13ServerHelloBody initializes empty TBytes result with nil before assembling the ServerHello body",
)
require(
    re.search(r"function BuildTLS13ServerHelloHandshake\(.*?\): TBytes;.*?begin.*?Result := nil;.*?LBody := BuildTLS13ServerHelloBody\(.*?Result := nil;.*?AppendByte\(Result, TLS_HANDSHAKE_TYPE_SERVER_HELLO\);", serverhello, re.S)
    is not None,
    "BuildTLS13ServerHelloHandshake initializes empty TBytes result with nil before assembling the handshake wrapper",
)
require(
    re.search(r"function BuildTLS13ServerHelloHandshakeWithSelectedPSK\(.*?\): TBytes;.*?begin.*?Result := nil;.*?LBody := BuildTLS13ServerHelloBody\(.*?Result := nil;.*?AppendByte\(Result, TLS_HANDSHAKE_TYPE_SERVER_HELLO\);", serverhello, re.S)
    is not None,
    "BuildTLS13ServerHelloHandshakeWithSelectedPSK initializes empty TBytes result with nil before assembling the selected-PSK handshake wrapper",
)

for signature in [
    r"function BuildExtensionHeader\(.*?end;",
    r"function BuildTLS13ServerHelloBody\(.*?end;",
    r"function BuildTLS13ServerHelloHandshake\(.*?end;",
    r"function BuildTLS13ServerHelloHandshakeWithSelectedPSK\(.*?end;",
]:
    block = re.search(signature, serverhello, re.S)
    require(block is not None, f"block exists: {signature}")
    require("SetLength(Result, 0);" not in block.group(0), f"{signature} no longer uses SetLength(Result, 0)")

require(
    re.search(r"function HexToBytes\(const AHex: string\): TBytes;.*?begin.*?Result := nil;.*?LLen := Length\(AHex\);.*?SetLength\(Result, LLen div 2\);", resumption, re.S)
    is not None,
    "test HexToBytes initializes empty TBytes result with nil before SetLength",
)
PY

echo "[PASS] managed result init safety wave5 contract passed"
