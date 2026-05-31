#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MATRIX_DOC="$ROOT_DIR/docs/BACKEND_CAPABILITY_MATRIX.md"
API_REF="$ROOT_DIR/docs/reference/API_REFERENCE.md"
BASE_SRC="$ROOT_DIR/src/nextpas.core.tls.base.pas"

echo "[TEST] backend doc linkage and enum truth contract"

python3 - "$ROOT_DIR" "$MATRIX_DOC" "$API_REF" "$BASE_SRC" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])
matrix_doc = Path(sys.argv[2])
api_ref = Path(sys.argv[3])
base_src = Path(sys.argv[4])

def require(condition: bool, message: str) -> None:
    if not condition:
        print(f"[FAIL] {message}")
        raise SystemExit(1)
    print(f"[PASS] {message}")

matrix_text = matrix_doc.read_text(encoding="utf-8")
api_text = api_ref.read_text(encoding="utf-8")
base_text = base_src.read_text(encoding="utf-8")

for stale in [
    "reference/OPENSSL_BACKEND.md",
    "reference/WINSSL_BACKEND.md",
]:
    require(stale not in matrix_text,
            f"top-level backend capability matrix must not link missing backend doc: {stale}")

for rel_path in [
    "docs/reference/OPENSSL_MODULES.md",
    "docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md",
    "docs/reference/WINSSL_DESIGN.md",
    "docs/reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md",
]:
    require((root / rel_path).exists(), f"linked backend reference exists: {rel_path}")

for required_link in [
    "reference/OPENSSL_MODULES.md",
    "reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md",
    "reference/WINSSL_DESIGN.md",
    "reference/MBEDTLS_BACKEND_CAPABILITY_MATRIX.md",
]:
    require(required_link in matrix_text,
            f"top-level backend capability matrix links live backend reference: {required_link}")

require("sslMbedTLS   // MbedTLS 后端（计划中）" not in api_text,
        "API reference must not describe MbedTLS backend enum as planned")

for token in [
    "sslAutoDetect",
    "sslOpenSSL",
    "sslWolfSSL",
    "sslMbedTLS",
    "sslWinSSL",
    "sslFreePascal",
]:
    require(token in api_text,
            f"API reference TSSLLibraryType snippet includes {token}")

require("sslFreePascal    // 纯 FreePascal 实现（未来）" not in base_text,
        "source enum comment must not describe sslFreePascal as future-only")
require("sslFreePascal" in base_text and "纯 FreePascal 实现" in base_text,
        "source enum still documents sslFreePascal as implemented backend")

PY

echo "[PASS] backend doc linkage and enum truth contract passed"
