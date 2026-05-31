#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "[TEST] managed result init safety wave6 contract"

python3 - "$ROOT_DIR" <<'PY'
from pathlib import Path
import re
import sys

root = Path(sys.argv[1])

targets = [
    "tests/test_tls13_posthandshake.pas",
    "tests/test_tls13_clienthello_parser.pas",
    "tests/test_tls13_servercertverify.pas",
    "tests/test_freepascal_client_certificateverify_runtime.pas",
    "tests/test_freepascal_client_chain_trust_runtime.pas",
    "tests/test_freepascal_client_ocsp_stapling_runtime.pas",
    "tests/test_freepascal_server_ocsp_stapling_runtime.pas",
    "tests/test_freepascal_client_online_ocsp_runtime.pas",
    "tests/test_freepascal_client_ct_sct_surface.pas",
    "tests/test_freepascal_client_cert_verify_flags_runtime.pas",
    "tests/test_freepascal_tls13_early_data.pas",
]

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

for target in targets:
    text = (root / target).read_text(encoding="utf-8")
    require("SetLength(Result, 0);" not in text,
            f"{target} no longer initializes empty TBytes Result with SetLength(Result, 0)")

required_patterns = {
    "tests/test_tls13_servercertverify.pas": [
        r"function LoadFileBytes\(.*?begin\s+Result := nil;.*?SetLength\(Result, LStream.Size\);",
        r"function QWordToBytes\(.*?begin\s+Result := nil;.*?if AValue = 0 then",
        r"function BuildPEMPrivateKeyWithLeadingJunk\(.*?begin\s+Result := nil;.*?LJunkBytes :=",
        r"function BuildPEMWithMultiplePrivateKeys\(.*?begin\s+Result := nil;.*?LSepBytes :=",
    ],
    "tests/test_freepascal_tls13_early_data.pas": [
        r"function ReadBytesFromFile\(.*?begin\s+Result := nil;.*?AssertTrue",
        r"function BytesOf\(.*?begin\s+Result := nil;.*?SetLength\(Result, Length\(AValue\)\);",
    ],
}

for target, patterns in required_patterns.items():
    text = (root / target).read_text(encoding="utf-8")
    for pattern in patterns:
        require(re.search(pattern, text, re.S) is not None,
                f"{target} keeps explicit Result := nil before managed result resizing: {pattern}")

print("[PASS] managed result init safety wave6 contract passed")
PY
