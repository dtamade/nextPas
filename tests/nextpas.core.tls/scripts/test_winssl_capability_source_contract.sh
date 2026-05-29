#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/src/nextpas.core.tls.winssl.lib.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] WinSSL capability source contract"

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

m = re.search(
    r"function TWinSSLLibrary\.IsCipherSupported\(const ACipherName: string\): Boolean;(.*?)^end;",
    text,
    re.S | re.M,
)
require(m is not None, "WinSSL IsCipherSupported implementation exists")
body = m.group(1)

require("Result := True;" not in body,
        "WinSSL IsCipherSupported must not unconditionally accept every cipher name")
require("deferred to system" not in body,
        "WinSSL IsCipherSupported must not describe fake-cipher acceptance as deferred policy")
require("if LCipher = '' then" in body and "Exit(False);" in body,
        "WinSSL IsCipherSupported must reject empty cipher names explicitly")

for token in [
    "TLS_AES_128_GCM_SHA256",
    "TLS_AES_256_GCM_SHA384",
    "AES128",
    "AES256",
    "AES128-GCM",
    "AES256-GCM",
]:
    require(token in body, f"WinSSL IsCipherSupported allowlist contains {token}")

require("Result.SessionCacheSupport := sslSupportStable;" in text,
        "WinSSL GetCapabilities must publish stable SessionCacheSupport")

require("Result.SessionTicketsSupport := sslSupportExperimental;" in text,
        "WinSSL GetCapabilities must publish experimental SessionTicketsSupport until native resumed-handshake proof closes")

require("observed_reuse=false" in text and "session_configured=true" in text,
        "WinSSL KnownIssues must record the current dedicated runtime truth for session resumption")
PY

echo "[PASS] WinSSL capability source contract passed"
