#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
KEYSCHEDULE_FILE="$ROOT_DIR/src/nextpas.core.tls.tls13.keyschedule.pas"
CLIENTHELLO_FILE="$ROOT_DIR/src/nextpas.core.tls.tls13.clienthello.pas"

echo "[TEST] managed result init safety wave4 contract"

python3 - "$KEYSCHEDULE_FILE" "$CLIENTHELLO_FILE" <<'PY'
from pathlib import Path
import re
import sys

keyschedule = Path(sys.argv[1]).read_text(encoding="utf-8")
clienthello = Path(sys.argv[2]).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

def require_function(text: str, signature: str) -> None:
    require(signature in text, f"function exists: {signature}")

require_function(keyschedule, "function HashTranscriptForSuite(ACipherSuite: Word; const AData: TBytes): TBytes;")
require_function(keyschedule, "function HKDFExtractForSuite(ACipherSuite: Word; const ASalt, AIKM: TBytes): TBytes;")
require_function(keyschedule, "function HKDFExpandLabelForSuite(")
require_function(keyschedule, "function TLS13ComputePSKBinderForCipherSuite(")

require_function(clienthello, "function BuildExtensionServerName(const AServerName: string): TBytes;")
require_function(clienthello, "function BuildExtensionALPN(const AALPNProtocols: string): TBytes;")
require_function(clienthello, "function BuildExtensionPreSharedKey(")
require_function(clienthello, "function BuildTLS13ClientHelloBody(")
require_function(clienthello, "function BuildTLS13ClientHelloBodyWithPSKCore(")
require_function(clienthello, "function BuildTLS13ClientHelloHandshake(")
require_function(clienthello, "function BuildTLS13ClientHelloHandshakeWithPSK(")
require_function(clienthello, "function BuildTLS13ClientHelloHandshakeWithComputedPSKBinder(")

require(
    re.search(r"function HashTranscriptForSuite\(ACipherSuite: Word; const AData: TBytes\): TBytes;.*?begin.*?Result := nil;.*?if TLS13CipherSuiteIsSHA256\(ACipherSuite\) then.*?Exit\(SHA256\(AData\)\);", keyschedule, re.S)
    is not None,
    "HashTranscriptForSuite initializes empty TBytes result with nil before early exits",
)
require(
    re.search(r"function HKDFExtractForSuite\(ACipherSuite: Word; const ASalt, AIKM: TBytes\): TBytes;.*?begin.*?Result := nil;.*?if TLS13CipherSuiteIsSHA256\(ACipherSuite\) then.*?Exit\(HKDF_Extract_SHA256\(ASalt, AIKM\)\);", keyschedule, re.S)
    is not None,
    "HKDFExtractForSuite initializes empty TBytes result with nil before early exits",
)
require(
    re.search(r"function HKDFExpandLabelForSuite\(.*?\): TBytes;.*?begin.*?Result := nil;.*?if TLS13CipherSuiteIsSHA256\(ACipherSuite\) then.*?Exit\(TLS13_HKDF_Expand_Label_SHA256\(ASecret, ALabel, AContext, ALength\)\);", keyschedule, re.S)
    is not None,
    "HKDFExpandLabelForSuite initializes empty TBytes result with nil before early exits",
)
require(
    re.search(r"function TLS13ComputePSKBinderForCipherSuite\(.*?\): TBytes;.*?begin.*?Result := nil;.*?LHashSize := TLS13CipherSuiteHashSize\(ACipherSuite\);", keyschedule, re.S)
    is not None,
    "TLS13ComputePSKBinderForCipherSuite initializes empty TBytes result with nil before validation and binder derivation",
)
require(
    "SetLength(Result, 0);" not in re.search(r"function HashTranscriptForSuite\(.*?end;", keyschedule, re.S).group(0),
    "HashTranscriptForSuite no longer uses SetLength(Result, 0)",
)
require(
    "SetLength(Result, 0);" not in re.search(r"function HKDFExtractForSuite\(.*?end;", keyschedule, re.S).group(0),
    "HKDFExtractForSuite no longer uses SetLength(Result, 0)",
)
require(
    "SetLength(Result, 0);" not in re.search(r"function HKDFExpandLabelForSuite\(.*?end;", keyschedule, re.S).group(0),
    "HKDFExpandLabelForSuite no longer uses SetLength(Result, 0)",
)
require(
    "SetLength(Result, 0);" not in re.search(r"function TLS13ComputePSKBinderForCipherSuite\(.*?end;", keyschedule, re.S).group(0),
    "TLS13ComputePSKBinderForCipherSuite no longer uses SetLength(Result, 0)",
)

require(
    re.search(r"function BuildExtensionServerName\(const AServerName: string\): TBytes;.*?if AServerName = '' then.*?Result := nil;.*?Exit;.*?Result := nil;.*?AppendUInt16\(Result, Word\(Length\(LListData\)\)\);", clienthello, re.S)
    is not None,
    "BuildExtensionServerName uses nil for both the empty fast path and the extension payload builder path",
)
require(
    re.search(r"function BuildExtensionALPN\(const AALPNProtocols: string\): TBytes;.*?if Length\(LProtocols\) = 0 then.*?Result := nil;.*?Exit;.*?Result := nil;.*?AppendUInt16\(Result, Word\(Length\(LListData\)\)\);", clienthello, re.S)
    is not None,
    "BuildExtensionALPN uses nil for both the empty fast path and the extension payload builder path",
)
require(
    re.search(r"function BuildExtensionPreSharedKey\(.*?\): TBytes;.*?if not APSKOffer.Valid then.*?Result := nil;.*?Exit;.*?Result := nil;.*?AppendBytes\(Result, LIdentities\);", clienthello, re.S)
    is not None,
    "BuildExtensionPreSharedKey uses nil for the invalid fast path and before building the PSK extension payload",
)
require(
    re.search(r"function BuildTLS13ClientHelloBody\(.*?\): TBytes;.*?Result := nil;.*?AppendUInt16\(Result, TLS_LEGACY_VERSION\);", clienthello, re.S)
    is not None,
    "BuildTLS13ClientHelloBody initializes empty TBytes result with nil before assembling ClientHello",
)
require(
    re.search(r"function BuildTLS13ClientHelloBodyWithPSKCore\(.*?\): TBytes;.*?SetLength\(APartialBody, 0\);.*?Result := nil;.*?AppendUInt16\(Result, TLS_LEGACY_VERSION\);", clienthello, re.S)
    is not None,
    "BuildTLS13ClientHelloBodyWithPSKCore initializes empty TBytes result with nil before assembling the final PSK ClientHello body",
)
require(
    re.search(r"function BuildTLS13ClientHelloHandshake\(.*?\): TBytes;.*?Result := nil;.*?AppendByte\(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO\);", clienthello, re.S)
    is not None,
    "BuildTLS13ClientHelloHandshake initializes empty TBytes result with nil before assembling the handshake wrapper",
)
require(
    re.search(r"function BuildTLS13ClientHelloHandshakeWithPSK\(.*?\): TBytes;.*?SetLength\(APartialHandshake, 0\);.*?Result := nil;.*?AppendByte\(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO\);", clienthello, re.S)
    is not None,
    "BuildTLS13ClientHelloHandshakeWithPSK initializes empty TBytes result with nil before assembling the PSK handshake wrapper",
)
require(
    re.search(r"function BuildTLS13ClientHelloHandshakeWithComputedPSKBinder\(.*?\): TBytes;.*?SetLength\(APartialHandshake, 0\);.*?Result := nil;.*?AppendByte\(Result, TLS_HANDSHAKE_TYPE_CLIENT_HELLO\);", clienthello, re.S)
    is not None,
    "BuildTLS13ClientHelloHandshakeWithComputedPSKBinder initializes empty TBytes result with nil before assembling the computed-binder handshake wrapper",
)

for signature in [
    r"function BuildExtensionServerName\(.*?end;",
    r"function BuildExtensionALPN\(.*?end;",
    r"function BuildExtensionPreSharedKey\(.*?end;",
    r"function BuildTLS13ClientHelloBody\(.*?end;",
    r"function BuildTLS13ClientHelloBodyWithPSKCore\(.*?end;",
    r"function BuildTLS13ClientHelloHandshake\(.*?end;",
    r"function BuildTLS13ClientHelloHandshakeWithPSK\(.*?end;",
    r"function BuildTLS13ClientHelloHandshakeWithComputedPSKBinder\(.*?end;",
]:
    block = re.search(signature, clienthello, re.S)
    require(block is not None, f"block exists: {signature}")
    require("SetLength(Result, 0);" not in block.group(0), f"{signature} no longer uses SetLength(Result, 0)")
PY

echo "[PASS] managed result init safety wave4 contract passed"
