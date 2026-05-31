#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PRIMITIVES_FILE="$ROOT_DIR/src/nextpas.core.tls.tls13.primitives.pas"
CONSTANT_TIME_FILE="$ROOT_DIR/src/nextpas.core.tls.crypto.constant_time.pas"

echo "[TEST] managed result init safety wave3 contract"

python3 - "$PRIMITIVES_FILE" "$CONSTANT_TIME_FILE" <<'PY'
from pathlib import Path
import re
import sys

primitives = Path(sys.argv[1]).read_text(encoding="utf-8")
constant_time = Path(sys.argv[2]).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

def extract_function(text: str, signature: str) -> str:
    m = re.search(rf"{re.escape(signature)}.*?^end;", text, re.S | re.M)
    require(m is not None, f"function exists: {signature}")
    return m.group(0)

extract_function(primitives, "function CopyBytes(const AData: TBytes): TBytes;")
extract_function(primitives, "function ConcatBytes(const ALeft, ARight: TBytes): TBytes;")
extract_function(
    primitives,
    "function BuildTLS13HKDFLabel(const ALabel: string; const AContext: TBytes; ALength: Integer): TBytes;",
)
extract_function(
    primitives, "function HKDF_Expand_SHA256(const APRK, AInfo: TBytes; ALength: Integer): TBytes;"
)
extract_function(
    primitives, "function HKDF_Expand_SHA384(const APRK, AInfo: TBytes; ALength: Integer): TBytes;"
)
extract_function(
    constant_time,
    "class function TConstantTime.Select(Condition: Integer; const IfTrue, IfFalse: TBytes): TBytes;",
)

require(
    re.search(r"function CopyBytes\(const AData: TBytes\): TBytes;.*?Result := nil;.*?SetLength\(Result, Length\(AData\)\);", primitives, re.S)
    is not None,
    "CopyBytes initializes empty TBytes result with nil before SetLength",
)
require(
    re.search(r"function ConcatBytes\(const ALeft, ARight: TBytes\): TBytes;.*?Result := nil;.*?SetLength\(Result, LLeftLen \+ LRightLen\);", primitives, re.S)
    is not None,
    "ConcatBytes initializes empty TBytes result with nil before SetLength",
)
require(
    re.search(r"function BuildTLS13HKDFLabel\(const ALabel: string; const AContext: TBytes; ALength: Integer\): TBytes;.*?Result := nil;.*?AppendUInt16\(Result, Word\(ALength\)\);", primitives, re.S)
    is not None,
    "BuildTLS13HKDFLabel initializes empty TBytes result with nil before building the HKDF label",
)
require(
    re.search(r"function BuildTLS13HKDFLabel\(const ALabel: string; const AContext: TBytes; ALength: Integer\): TBytes;.*?SetLength\(Result, 0\);", primitives, re.S)
    is None,
    "BuildTLS13HKDFLabel no longer uses SetLength(Result, 0) on an uninitialized managed result",
)
require(
    re.search(r"function HKDF_Expand_SHA256\(const APRK, AInfo: TBytes; ALength: Integer\): TBytes;.*?Result := nil;.*?SetLength\(Result, ALength\);", primitives, re.S)
    is not None,
    "HKDF_Expand_SHA256 initializes empty TBytes result with nil before allocating output bytes",
)
require(
    re.search(r"function HKDF_Expand_SHA256\(const APRK, AInfo: TBytes; ALength: Integer\): TBytes;.*?SetLength\(Result, 0\);", primitives, re.S)
    is None,
    "HKDF_Expand_SHA256 no longer uses SetLength(Result, 0) on an uninitialized managed result",
)
require(
    re.search(r"function HKDF_Expand_SHA384\(const APRK, AInfo: TBytes; ALength: Integer\): TBytes;.*?Result := nil;.*?SetLength\(Result, ALength\);", primitives, re.S)
    is not None,
    "HKDF_Expand_SHA384 initializes empty TBytes result with nil before allocating output bytes",
)
require(
    re.search(r"function HKDF_Expand_SHA384\(const APRK, AInfo: TBytes; ALength: Integer\): TBytes;.*?SetLength\(Result, 0\);", primitives, re.S)
    is None,
    "HKDF_Expand_SHA384 no longer uses SetLength(Result, 0) on an uninitialized managed result",
)
require(
    re.search(r"class function TConstantTime\.Select\(Condition: Integer; const IfTrue, IfFalse: TBytes\): TBytes;.*?Result := nil;.*?SetLength\(Result, Length\(IfTrue\)\);", constant_time, re.S)
    is not None,
    "TConstantTime.Select initializes empty TBytes result with nil before SetLength",
)
PY

echo "[PASS] managed result init safety wave3 contract passed"
