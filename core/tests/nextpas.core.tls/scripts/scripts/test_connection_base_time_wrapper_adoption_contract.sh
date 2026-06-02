#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
CONNECTION_BASE_FILE="$ROOT_DIR/src/nextpas.core.tls.connection.base.pas"

echo "[TEST] tls connection base time wrapper adoption contract"

python3 - "$CONNECTION_BASE_FILE" <<'PY'
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
        "connection base imports nextpas.core.time")
require("LEntry.Timestamp := DateTimeNow;" in text,
        "connection base records error timestamps via DateTimeNow")
require("FFirstByteTime := DateTimeMillisecondsBetween(DateTimeNow, FConnectTime);" in text,
        "connection base computes first-byte latency via DateTimeMillisecondsBetween")
require(text.count("FConnectTime := DateTimeNow;") >= 2,
        "connection base seeds connect timestamps via DateTimeNow for connect/accept")
require(text.count("FHandshakeStartTime := DateTimeNow;") >= 3,
        "connection base seeds handshake timestamps via DateTimeNow for connect/accept/handshake")
require(text.count("DateTimeMillisecondsBetween(DateTimeNow, FHandshakeStartTime)") >= 3,
        "connection base computes handshake duration via DateTimeMillisecondsBetween")
require("Result.LastErrorTime := DateTimeNow;" in text,
        "connection base health snapshot uses DateTimeNow")
require("Result.ConnectionAge := DateTimeSecondsBetween(DateTimeNow, FConnectTime)" in text,
        "connection base health snapshot uses DateTimeSecondsBetween")
require(re.search(r"\bMilliSecondsBetween\b", text) is None,
        "connection base no longer uses DateUtils MilliSecondsBetween")
require(re.search(r"\bNow\b", text) is None,
        "connection base no longer uses SysUtils Now directly")
PY

echo "[PASS] tls connection base time wrapper adoption contract passed"
