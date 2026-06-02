#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
DTLS_FILE="$ROOT_DIR/src/nextpas.core.tls.dtls.layer.pas"
AESGCM_POOL_FILE="$ROOT_DIR/src/nextpas.core.tls.aesgcm.pool.pas"

echo "[TEST] tls time wrapper adoption contract"

python3 - "$DTLS_FILE" "$AESGCM_POOL_FILE" <<'PY'
from pathlib import Path
import re
import sys

dtls = Path(sys.argv[1]).read_text(encoding="utf-8")
pool = Path(sys.argv[2]).read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

require("nextpas.core.time" in dtls, "dtls layer imports nextpas.core.time")
require("nextpas.core.time" in pool, "aesgcm pool imports nextpas.core.time")

require("FRetransmitQueue[LIdx].LastSentTime := DateTimeNow;" in dtls,
        "dtls layer records retransmit enqueue time via DateTimeNow")
require("FRetransmitQueue[I].LastSentTime := DateTimeNow;" in dtls,
        "dtls layer records retransmit resend time via DateTimeNow")
require(re.search(r"\bNow\b", dtls) is None,
        "dtls layer no longer uses SysUtils Now directly")
require(re.search(r"\bDateUtils\b", dtls) is None,
        "dtls layer no longer imports DateUtils for Now-only usage")

require("LOldestTime := DateTimeNow;" in pool,
        "aesgcm pool seeds LRU scan with DateTimeNow")
require(pool.count("LastUsed := DateTimeNow;") >= 3,
        "aesgcm pool updates LastUsed through DateTimeNow at initialize/reset/acquire points")
require(re.search(r"\bNow\b", pool) is None,
        "aesgcm pool no longer uses SysUtils Now directly")
require(re.search(r"\bDateUtils\b", pool) is None,
        "aesgcm pool no longer imports DateUtils for Now-only usage")
PY

echo "[PASS] tls time wrapper adoption contract passed"
