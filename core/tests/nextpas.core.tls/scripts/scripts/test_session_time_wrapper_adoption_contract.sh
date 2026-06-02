#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
FREEPASCAL_FILE="$ROOT_DIR/src/nextpas.core.tls.freepascal.session.pas"
MBEDTLS_FILE="$ROOT_DIR/src/nextpas.core.tls.mbedtls.session.pas"
WOLFSSL_FILE="$ROOT_DIR/src/nextpas.core.tls.wolfssl.session.pas"

echo "[TEST] tls session time wrapper adoption contract"

python3 - "$FREEPASCAL_FILE" "$MBEDTLS_FILE" "$WOLFSSL_FILE" <<'PY'
from pathlib import Path
import re
import sys

files = {
    "freepascal": Path(sys.argv[1]).read_text(encoding="utf-8"),
    "mbedtls": Path(sys.argv[2]).read_text(encoding="utf-8"),
    "wolfssl": Path(sys.argv[3]).read_text(encoding="utf-8"),
}

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

for name, text in files.items():
    require("nextpas.core.time" in text, f"{name} session imports nextpas.core.time")
    require("FCreationTime := DateTimeNow;" in text,
            f"{name} session seeds creation time via DateTimeNow")
    require("DateTimeSecondsBetween(DateTimeNow, FCreationTime)" in text,
            f"{name} session computes age via DateTimeSecondsBetween + DateTimeNow")
    require(re.search(r"\bSecondsBetween\b", text) is None,
            f"{name} session no longer uses DateUtils SecondsBetween")
    require(re.search(r"\bNow\b", text) is None,
            f"{name} session no longer uses SysUtils Now directly")
PY

echo "[PASS] tls session time wrapper adoption contract passed"
