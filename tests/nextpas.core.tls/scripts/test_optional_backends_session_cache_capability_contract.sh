#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MBEDTLS_FILE="$ROOT_DIR/src/nextpas.core.tls.mbedtls.lib.pas"
WOLFSSL_FILE="$ROOT_DIR/src/nextpas.core.tls.wolfssl.lib.pas"

echo "[TEST] optional backend session-cache capability contract"

python3 - "$MBEDTLS_FILE" "$WOLFSSL_FILE" <<'PY'
from pathlib import Path
import re
import sys

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

def extract_function(text: str, signature: str) -> str:
    match = re.search(rf"{re.escape(signature)}(.*?)^end;", text, re.S | re.M)
    require(match is not None, f"{signature} exists")
    return match.group(1)

for label, filename in [("MbedTLS", Path(sys.argv[1])), ("WolfSSL", Path(sys.argv[2]))]:
    text = filename.read_text(encoding="utf-8")
    feature_body = extract_function(text, f"function T{label}Library.IsFeatureSupported(AFeature: TSSLFeature): Boolean;")
    caps_body = extract_function(text, f"function T{label}Library.GetCapabilities: TSSLBackendCapabilities;")

    require("sslFeatSessionCache: Result := True;" in feature_body,
            f"{label} IsFeatureSupported keeps advertising session-cache support")
    require("Result.SessionCacheSupport := sslSupportStable;" in caps_body,
            f"{label} GetCapabilities publishes stable SessionCacheSupport when the source still advertises session-cache support")

PY

echo "[PASS] optional backend session-cache capability contract passed"
