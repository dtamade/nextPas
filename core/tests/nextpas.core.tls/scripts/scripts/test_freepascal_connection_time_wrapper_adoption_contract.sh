#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
FREEPASCAL_CONNECTION_FILE="$ROOT_DIR/src/nextpas.core.tls.freepascal.connection.pas"

echo "[TEST] freepascal connection time wrapper adoption contract"

python3 - "$FREEPASCAL_CONNECTION_FILE" <<'PY'
from pathlib import Path
import re
import sys

text = Path(sys.argv[1]).read_text(encoding="utf-8")


def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")


require("nextpas.core.time" in text,
        "freepascal connection imports nextpas.core.time")
require(text.count("DateTimeNow,") >= 4,
        "freepascal connection seeds resumption creation timestamps via DateTimeNow")
require("LSessionAgeMs := DateTimeMillisecondsBetween(DateTimeNow, FConfiguredSession.GetCreationTime);" in text,
        "freepascal connection computes configured session age via DateTimeMillisecondsBetween")
require(re.search(r"\bMilliSecondsBetween\b", text) is None,
        "freepascal connection no longer uses DateUtils MilliSecondsBetween")
require(re.search(r"\bNow\b", text) is None,
        "freepascal connection no longer uses SysUtils Now directly")
PY

echo "[PASS] freepascal connection time wrapper adoption contract passed"
