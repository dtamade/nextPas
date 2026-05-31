#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
SOURCE_FILE="${REPO_ROOT}/src/nextpas.core.tls.openssl.loader.pas"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

[[ -f "${SOURCE_FILE}" ]] || fail "missing source file: ${SOURCE_FILE}"

rg -F "GetEnvironmentVariable('OPENSSL_ROOT')" "${SOURCE_FILE}" >/dev/null \
  || fail "loader must read OPENSSL_ROOT before generic library fallback"

rg -F "TryLoadLibraryFromOpenSSLRoot(osslLibCrypto)" "${SOURCE_FILE}" >/dev/null \
  || fail "loader must try OPENSSL_ROOT-backed libcrypto candidates first"

rg -F "TryLoadLibraryFromOpenSSLRoot(osslLibSSL)" "${SOURCE_FILE}" >/dev/null \
  || fail "loader must try OPENSSL_ROOT-backed libssl candidates first"

rg -F "IncludeTrailingPathDelimiter(LRoot) + 'lib' + PathDelim" "${SOURCE_FILE}" >/dev/null \
  || fail "loader must build absolute OPENSSL_ROOT/lib candidates"

for symbol in \
  "libcrypto.3.dylib" \
  "libcrypto.dylib" \
  "libssl.3.dylib" \
  "libssl.dylib"; do
  rg -F "${symbol}" "${SOURCE_FILE}" >/dev/null \
    || fail "missing expected macOS OpenSSL candidate: ${symbol}"
done

python3 - "${SOURCE_FILE}" <<'PY'
import sys
from pathlib import Path

source = Path(sys.argv[1]).read_text(encoding="utf-8")

checks = [
    (
        "TryLoadLibraryFromOpenSSLRoot(osslLibCrypto)",
        "FLibCrypto := TryLoadLibrary([",
        "libcrypto OPENSSL_ROOT priority must precede generic fallback",
    ),
    (
        "TryLoadLibraryFromOpenSSLRoot(osslLibSSL)",
        "FLibSSL := TryLoadLibrary([",
        "libssl OPENSSL_ROOT priority must precede generic fallback",
    ),
]

for first, second, message in checks:
    first_idx = source.find(first)
    second_idx = source.find(second)
    if first_idx == -1:
        raise SystemExit(f"[FAIL] missing marker: {first}")
    if second_idx == -1:
        raise SystemExit(f"[FAIL] missing marker: {second}")
    if first_idx > second_idx:
        raise SystemExit(f"[FAIL] {message}")

print("[PASS] macOS OPENSSL_ROOT loader priority contract holds")
PY
