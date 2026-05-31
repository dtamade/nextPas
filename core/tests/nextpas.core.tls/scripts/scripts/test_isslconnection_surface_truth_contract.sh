#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

doc_file="docs/reference/API_REFERENCE.md"
source_file="src/nextpas.core.tls.base.pas"

section="$(
  awk '
    /^### ISSLConnection$/ {in_section=1}
    /^### TSSLLibraryType$/ {in_section=0}
    in_section {print}
  ' "$doc_file"
)"

if [[ -z "$section" ]]; then
  echo "[FAIL] failed to extract ISSLConnection/API session section from $doc_file"
  exit 1
fi

if ! grep -F -q 'ISSLConnection = interface' "$source_file"; then
  echo "[FAIL] source no longer declares ISSLConnection in $source_file"
  exit 1
fi

declare -a forbidden_patterns=(
  'function GetCipherBits: Integer;'
  'function VerifyPeerCertificate: Boolean;'
  'function GetSessionID: string;'
  'function IsSessionResumed: Boolean;'
  'function GetSessionData: TBytes;'
  'procedure SetSessionData(const aData: TBytes);'
)

for pattern in "${forbidden_patterns[@]}"; do
  if grep -F -q "$pattern" <<<"$section"; then
    echo "[FAIL] active ISSLConnection/API session docs still mention stale surface: $pattern"
    exit 1
  fi
done

declare -a required_patterns=(
  'function Shutdown: Boolean;'
  'function DoHandshake: TSSLHandshakeState;'
  'function IsHandshakeComplete: Boolean;'
  'function Renegotiate: Boolean;'
  'function WantRead: Boolean;'
  'function WantWrite: Boolean;'
  'function GetError(ARet: Integer): TSSLErrorCode;'
  'function GetSelectedALPNProtocol: string;'
  'procedure SetTimeout(ATimeout: Integer);'
  'function GetTimeout: Integer;'
  'procedure SetBlocking(ABlocking: Boolean);'
  'function GetBlocking: Boolean;'
  'function GetContext: ISSLContext;'
  'function GetState: string;'
  'function GetStateString: string;'
  'function GetSession: ISSLSession;'
  'procedure SetSession(ASession: ISSLSession);'
  'function IsSessionReused: Boolean;'
  'function GetVerifyResult: Integer;'
  'function GetVerifyResultString: string;'
  'function GetOCSPStaplingEnabled: Boolean;'
  'function GetOCSPResponse: TBytes;'
  'function IsOCSPResponseVerified: Boolean;'
  'function GetOCSPResponseStatus: string;'
  'ISSLClientConnection = interface(ISSLConnection)'
  'function GetID: string;'
  'function Serialize: TBytes;'
  'ISSLNativeHandleAccess'
  'ISSLConnectionInfo'
  'ISSLDiagnostics'
  'ISSLSessionResumption'
  'ISSLCertificateVerification'
  'ISSLOCSPStapling'
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -F -q "$pattern" <<<"$section"; then
    echo "[FAIL] active ISSLConnection/API session docs missing current truth: $pattern"
    exit 1
  fi
done

echo "[PASS] active ISSLConnection/API session docs match current source truth"
