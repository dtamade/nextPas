#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

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

source_file="src/nextpas.core.tls.base.pas"
design_v2="docs/reference/INTERFACE_DESIGN_V2.md"

printf '[TEST] ISSLConnection whole-surface taxonomy contract\n'

python3 - <<'PY'
from pathlib import Path
import re
import sys

path = Path("src/nextpas.core.tls.base.pas")
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

require_fixed "$design_v2" '当前 shipped surface 已经穷尽为 41 个方法，精确分成 `17 core + 6 convenience mirror + 18 compatibility-core mirror`。' \
  "INTERFACE_DESIGN_V2 must state the current 41-method partition"
require_fixed "$design_v2" '| Core | 17 |' \
  "INTERFACE_DESIGN_V2 must include the core bucket count"
require_fixed "$design_v2" '| Convenience mirror | 6 |' \
  "INTERFACE_DESIGN_V2 must include the convenience bucket count"
require_fixed "$design_v2" '| Compatibility-core mirror | 18 |' \
  "INTERFACE_DESIGN_V2 must include the compatibility bucket count"
require_fixed "$design_v2" '| `ReadString` / `WriteString` | 2 | `ISSLConnectionTextIO` |' \
  "INTERFACE_DESIGN_V2 must map text helpers to ISSLConnectionTextIO"
require_fixed "$design_v2" '| `SetTimeout` / `GetTimeout` / `SetBlocking` / `GetBlocking` | 4 | `ISSLConnectionControl` |' \
  "INTERFACE_DESIGN_V2 must map runtime control helpers to ISSLConnectionControl"
require_fixed "$design_v2" '| `GetConnectionInfo` / `GetContext` / `GetSelectedALPNProtocol` / `GetStateString` | 4 | `ISSLConnectionInfo` |' \
  "INTERFACE_DESIGN_V2 must map connection-info mirrors to ISSLConnectionInfo"
require_fixed "$design_v2" '| `GetHealthStatus` / `IsHealthy` / `GetDiagnosticInfo` / `GetPerformanceMetrics` | 4 | `ISSLDiagnostics` |' \
  "INTERFACE_DESIGN_V2 must map diagnostics mirrors to ISSLDiagnostics"
require_fixed "$design_v2" '| `GetSession` / `SetSession` / `IsSessionReused` | 3 | `ISSLSessionResumption` |' \
  "INTERFACE_DESIGN_V2 must map session mirrors to ISSLSessionResumption"
require_fixed "$design_v2" '| `GetPeerCertificateChain` / `GetVerifyResult` / `GetVerifyResultString` | 3 | `ISSLCertificateVerification` |' \
  "INTERFACE_DESIGN_V2 must map certificate-verification mirrors to ISSLCertificateVerification"
require_fixed "$design_v2" '| `GetOCSPStaplingEnabled` / `GetOCSPResponse` / `IsOCSPResponseVerified` / `GetOCSPResponseStatus` | 4 | `ISSLOCSPStapling` |' \
  "INTERFACE_DESIGN_V2 must map OCSP mirrors to ISSLOCSPStapling"
require_fixed "$design_v2" '`ISSLClientConnection` 与 `ISSLNativeHandleAccess` 是相邻 optional surfaces，不计入这 41 个方法的 partition。' \
  "INTERFACE_DESIGN_V2 must keep adjacent optional surfaces outside the 41-method partition"

printf '[PASS] ISSLConnection whole-surface taxonomy contract passed\n'
