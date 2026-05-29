#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

api_ref="docs/reference/API_REFERENCE.md"

require_pattern() {
  local pattern="$1"
  local message="$2"
  if ! rg -F -n --quiet -- "$pattern" "$api_ref"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

echo "[TEST] API reference optional public interface coverage"

require_pattern '当前 public Pascal source 尚未声明 `ISSLServerConnection`；服务端特有能力主要通过可选 context 扩展接口暴露。' \
  'API reference must record the current ISSLServerConnection absence and server-side context-surface truth'

require_pattern 'ISSLHttpHooksAccess = interface' \
  'API reference must include ISSLHttpHooksAccess'
require_pattern 'procedure SetHTTPGetCallback(ACallback: TSSLHTTPGetCallback);' \
  'API reference must include ISSLHttpHooksAccess HTTP GET setter'
require_pattern 'function GetHTTPPostCallback: TSSLHTTPPostCallback;' \
  'API reference must include ISSLHttpHooksAccess HTTP POST getter'

require_pattern 'ISSLServerOCSPStaplingContext = interface' \
  'API reference must include ISSLServerOCSPStaplingContext'
require_pattern 'procedure ClearServerStapledOCSPResponse;' \
  'API reference must include server stapled OCSP clear surface'
require_pattern 'procedure SetServerStapledOCSPResponse(const AResponseDER: TBytes);' \
  'API reference must include server stapled OCSP set-bytes surface'
require_pattern 'procedure LoadServerStapledOCSPResponseFile(const AFileName: string);' \
  'API reference must include server stapled OCSP load-file surface'
require_pattern 'function HasServerStapledOCSPResponse: Boolean;' \
  'API reference must include server stapled OCSP presence surface'
require_pattern 'function GetServerStapledOCSPResponse: TBytes;' \
  'API reference must include server stapled OCSP bytes surface'

require_pattern 'ISSLEarlyDataContext = interface' \
  'API reference must include ISSLEarlyDataContext'
require_pattern 'procedure SetClientEarlyDataEnabled(AEnabled: Boolean);' \
  'API reference must include client early-data enable surface'
require_pattern 'function GetClientEarlyDataEnabled: Boolean;' \
  'API reference must include client early-data getter'
require_pattern 'procedure SetServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy);' \
  'API reference must include server early-data policy setter'
require_pattern 'function GetServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;' \
  'API reference must include server early-data policy getter'
require_pattern 'procedure SetServerMaxEarlyDataSize(ASize: Cardinal);' \
  'API reference must include server early-data max-size setter'
require_pattern 'function GetServerMaxEarlyDataSize: Cardinal;' \
  'API reference must include server early-data max-size getter'

require_pattern 'ISSLEarlyDataConnection = interface' \
  'API reference must include ISSLEarlyDataConnection'
require_pattern 'function SetEarlyData(const AData: TBytes): TSSLOperationResult;' \
  'API reference must include queued early-data surface'
require_pattern 'function GetEarlyDataStatus: TSSLEarlyDataStatus;' \
  'API reference must include early-data status surface'
require_pattern 'function GetEarlyDataLimit: Cardinal;' \
  'API reference must include early-data limit surface'

require_pattern 'ISSLConnectionInfo = interface' \
  'API reference must include ISSLConnectionInfo'
require_pattern 'function GetConnectionInfo: TSSLConnectionInfo;' \
  'API reference must include ISSLConnectionInfo.GetConnectionInfo'
require_pattern 'function GetContext: ISSLContext;' \
  'API reference must include ISSLConnectionInfo.GetContext'
require_pattern 'function GetSelectedALPNProtocol: string;' \
  'API reference must include ISSLConnectionInfo.GetSelectedALPNProtocol'
require_pattern 'function GetStateString: string;' \
  'API reference must include ISSLConnectionInfo.GetStateString'

require_pattern 'ISSLDiagnostics = interface' \
  'API reference must include ISSLDiagnostics'
require_pattern 'function GetHealthStatus: TSSLHealthStatus;' \
  'API reference must include diagnostics health surface'
require_pattern 'function IsHealthy: Boolean;' \
  'API reference must include diagnostics boolean health surface'
require_pattern 'function GetPerformanceMetrics: TSSLPerformanceMetrics;' \
  'API reference must include diagnostics performance surface'
require_pattern 'function GetDiagnosticInfo: TSSLDiagnosticInfo;' \
  'API reference must include diagnostics info surface'

require_pattern 'ISSLSessionResumption = interface' \
  'API reference must include ISSLSessionResumption'
require_pattern 'function GetSession: ISSLSession;' \
  'API reference must include session-resumption getter'
require_pattern 'procedure SetSession(ASession: ISSLSession);' \
  'API reference must include session-resumption setter'
require_pattern 'function IsSessionReused: Boolean;' \
  'API reference must include session-resumption reuse surface'

require_pattern 'ISSLCertificateVerification = interface' \
  'API reference must include ISSLCertificateVerification'
require_pattern 'function GetPeerCertificateChain: TSSLCertificateArray;' \
  'API reference must include certificate-verification chain surface'
require_pattern 'function GetVerifyResult: Integer;' \
  'API reference must include certificate-verification result surface'
require_pattern 'function GetVerifyResultString: string;' \
  'API reference must include certificate-verification result-string surface'

require_pattern 'ISSLOCSPStapling = interface' \
  'API reference must include ISSLOCSPStapling'
require_pattern 'function GetOCSPStaplingEnabled: Boolean;' \
  'API reference must include OCSP stapling enabled surface'
require_pattern 'function GetOCSPResponse: TBytes;' \
  'API reference must include OCSP stapling bytes surface'
require_pattern 'function IsOCSPResponseVerified: Boolean;' \
  'API reference must include OCSP stapling verified surface'
require_pattern 'function GetOCSPResponseStatus: string;' \
  'API reference must include OCSP stapling status surface'

echo "[PASS] API reference covers the current optional public interface surface"
