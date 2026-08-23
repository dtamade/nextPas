#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

source_file="core/src/nextpas.core.tls.base.pas"

printf '[TEST] ISSLConnection whole-surface taxonomy contract\n'

python3 - <<'PY'
from pathlib import Path
import re
import sys

path = Path("core/src/nextpas.core.tls.base.pas")
lines = path.read_text(encoding="utf-8").splitlines()
start = next(i for i, line in enumerate(lines) if line.strip() == "ISSLConnection = interface")
end = next(i for i in range(start + 1, len(lines)) if lines[i].strip() == "end;")

methods = []
for line in lines[start:end]:
    match = re.match(r"\s*(function|procedure)\s+([A-Za-z0-9_]+)", line)
    if match:
      methods.append(match.group(2))

expected = [
    "Connect",
    "Accept",
    "Shutdown",
    "Close",
    "DoHandshake",
    "IsHandshakeComplete",
    "Renegotiate",
    "Read",
    "Write",
    "ReadString",
    "WriteString",
    "WantRead",
    "WantWrite",
    "GetError",
    "GetConnectionInfo",
    "GetProtocolVersion",
    "GetCipherName",
    "GetPeerCertificate",
    "GetPeerCertificateChain",
    "GetVerifyResult",
    "GetVerifyResultString",
    "GetSession",
    "SetSession",
    "IsSessionReused",
    "GetSelectedALPNProtocol",
    "IsConnected",
    "GetState",
    "GetStateString",
    "SetTimeout",
    "GetTimeout",
    "SetBlocking",
    "GetBlocking",
    "GetContext",
    "GetHealthStatus",
    "IsHealthy",
    "GetDiagnosticInfo",
    "GetPerformanceMetrics",
    "GetOCSPStaplingEnabled",
    "GetOCSPResponse",
    "IsOCSPResponseVerified",
    "GetOCSPResponseStatus",
]

if len(methods) != 41:
    print(f"[FAIL] expected 41 ISSLConnection methods, found {len(methods)}", file=sys.stderr)
    sys.exit(1)

if sorted(methods) != sorted(expected):
    missing = sorted(set(expected) - set(methods))
    extra = sorted(set(methods) - set(expected))
    print(f"[FAIL] ISSLConnection method inventory mismatch\nmissing: {missing}\nextra: {extra}", file=sys.stderr)
    sys.exit(1)
PY


printf '[PASS] ISSLConnection whole-surface taxonomy contract passed\n'
