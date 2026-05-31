#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FILE="$ROOT_DIR/src/nextpas.core.tls.winssl.connection.pas"

fail() {
  echo "[FAIL] $1"
  exit 1
}

echo "[TEST] WinSSL session serialization roundtrip contract"

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

def body(kind: str, name: str) -> str:
    m = re.search(rf"{kind} TWinSSLSession\.{name}(?:\([^)]*\))?(?:: [^;]+)?;(.*?)^end;", text, re.S | re.M)
    require(m is not None, f"TWinSSLSession implements {name}")
    return m.group(1)

serialize = body("function", "Serialize")
deserialize = body("function", "Deserialize")
set_timeout = body("procedure", "SetTimeout")
set_metadata = body("procedure", "SetSessionMetadata")

require("BuildSerializedSessionData" in text,
        "TWinSSLSession must define a helper that builds serialized metadata payloads")
require("TryLoadSerializedSessionData" in text,
        "TWinSSLSession must define a helper that restores metadata from serialized payloads")

require(("BuildSerializedSessionData" in serialize) or ("RebuildSerializedSessionData" in serialize),
        "Serialize must return a metadata-backed serialized payload, not a raw stale field")

require(("TryLoadSerializedSessionData" in deserialize) and ("Result :=" in deserialize),
        "Deserialize must parse serialized metadata and return a real success/failure result")

require(("BuildSerializedSessionData" in set_timeout) or ("RebuildSerializedSessionData" in set_timeout),
        "SetTimeout must refresh the serialized payload when timeout changes")

require(("BuildSerializedSessionData" in set_metadata) or ("RebuildSerializedSessionData" in set_metadata),
        "SetSessionMetadata must refresh the serialized payload when metadata changes")
PY

echo "[PASS] WinSSL session serialization roundtrip contract passed"
