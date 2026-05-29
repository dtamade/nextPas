#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/src/nextpas.core.tls.winssl.context.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] WinSSL session-cache runtime flag contract"

python3 - "$FILE" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

def block(name: str) -> str:
    m = re.search(rf"procedure TWinSSLContext\.{name}(?:\([^)]*\))?;(.*?)^end;", text, re.S | re.M)
    require(m is not None, f"WinSSL context implements {name}")
    return m.group(1)

set_cache_mode = block("SetSessionCacheMode")
set_options = block("SetOptions")
ensure_credentials = block("EnsureCredentialsAcquired")

require("FCredentialsNeedRebuild := True;" in set_cache_mode,
        "SetSessionCacheMode must force credential rebuild when session-cache mode changes")

require("FCredentialsNeedRebuild := True;" in set_options,
        "SetOptions must force credential rebuild when session/ticket-related options change")

require("SCH_CRED_DISABLE_RECONNECTS" in ensure_credentials,
        "EnsureCredentialsAcquired must keep a server-side reconnect-disable mapping for WinSSL session-cache/ticket truth")

require(("FContextType = sslCtxServer" in ensure_credentials) and
        ("not FSessionCacheEnabled" in ensure_credentials) and
        ("ssoEnableSessionTickets in FOptions" in ensure_credentials),
        "EnsureCredentialsAcquired must scope SCH_CRED_DISABLE_RECONNECTS to server-side truth and still derive it from session-cache/ticket state")
PY

echo "[PASS] WinSSL session-cache runtime flag contract passed"
