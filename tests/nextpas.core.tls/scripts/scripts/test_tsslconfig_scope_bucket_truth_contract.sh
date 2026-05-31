#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
factory_file="src/nextpas.core.tls.factory.pas"
openssl_file="src/nextpas.core.tls.openssl.backed.pas"
api_ref="docs/reference/API_REFERENCE.md"

require_rg() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg -n --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed() {
  local pattern="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_rg "BufferSize: Integer;[[:space:]]+// Connection-scoped buffering hint; factory paths reject custom values" \
  "$base_file" "TSSLConfig.BufferSize source comment no longer states its connection-scoped truth"
require_rg "HandshakeTimeout: Integer;[[:space:]]+// Connection-scoped timeout; use connector/acceptor/connection timeout APIs" \
  "$base_file" "TSSLConfig.HandshakeTimeout source comment no longer points to connection-scoped timeout APIs"
require_rg "SessionCacheSize: Integer;[[:space:]]+// Context-scoped session cache sizing" \
  "$base_file" "TSSLConfig.SessionCacheSize source comment no longer states its context-scoped truth"
require_rg "SessionTimeout: Integer;[[:space:]]+// Context-scoped session lifetime" \
  "$base_file" "TSSLConfig.SessionTimeout source comment no longer states its context-scoped truth"
require_rg "ALPNProtocols: string;[[:space:]]+// Context-scoped ALPN defaults" \
  "$base_file" "TSSLConfig.ALPNProtocols source comment no longer states its context-scoped truth"
require_rg "EnableCompression: Boolean;[[:space:]]+// Compatibility-only option-bridge flag; prefer Options; normalized into Options" \
  "$base_file" "TSSLConfig.EnableCompression source comment no longer states option-bridge normalization"
require_rg "EnableSessionTickets: Boolean;[[:space:]]+// Compatibility-only option-bridge flag; prefer Options; normalized into Options" \
  "$base_file" "TSSLConfig.EnableSessionTickets source comment no longer states option-bridge normalization"
require_rg "EnableOCSPStapling: Boolean;[[:space:]]+// Compatibility-only option-bridge flag; prefer Options; normalized into Options" \
  "$base_file" "TSSLConfig.EnableOCSPStapling source comment no longer states option-bridge normalization"
require_rg "ClientEarlyDataEnabled: Boolean;[[:space:]]+// Context-scoped TLS 1\\.3 client early-data default" \
  "$base_file" "TSSLConfig.ClientEarlyDataEnabled source comment no longer states its context scope"
require_rg "ServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;[[:space:]]+// Context-scoped TLS 1\\.3 server early-data policy" \
  "$base_file" "TSSLConfig.ServerEarlyDataPolicy source comment no longer states its context scope"
require_rg "ServerMaxEarlyDataSize: Cardinal;[[:space:]]+// Context-scoped TLS 1\\.3 server early-data limit" \
  "$base_file" "TSSLConfig.ServerMaxEarlyDataSize source comment no longer states its context scope"
require_rg "ServerEarlyDataReplayStoreFile: string;[[:space:]]+// Server-context-scoped replay-store file opt-in" \
  "$base_file" "TSSLConfig.ServerEarlyDataReplayStoreFile source comment no longer states its server-context scope"
require_rg "ServerEarlyDataReplayStoreDirectory: string;[[:space:]]+// Server-context-scoped replay-store directory opt-in" \
  "$base_file" "TSSLConfig.ServerEarlyDataReplayStoreDirectory source comment no longer states its server-context scope"
require_rg "LogLevel: TSSLLogLevel;[[:space:]]+// Library-scoped default log level; factory request paths reject overrides" \
  "$base_file" "TSSLConfig.LogLevel source comment no longer states its library scope"
require_rg "LogCallback: TSSLLogCallback;[[:space:]]+// Library-scoped callback snapshot; SetLogCallback owns replacements and factory request paths reject callbacks" \
  "$base_file" "TSSLConfig.LogCallback source comment no longer states its library scope"

require_fixed '## TSSLConfig Scope Buckets' "$api_ref" \
  "API reference no longer contains the TSSLConfig scope bucket section"
require_fixed '- `LogLevel`' "$api_ref" \
  "API reference no longer lists LogLevel inside the TSSLConfig scope buckets"
require_fixed '- `LogCallback`' "$api_ref" \
  "API reference no longer lists LogCallback inside the TSSLConfig scope buckets"
require_fixed '- `SessionCacheSize`' "$api_ref" \
  "API reference no longer lists SessionCacheSize inside the TSSLConfig scope buckets"
require_fixed '- `SessionTimeout`' "$api_ref" \
  "API reference no longer lists SessionTimeout inside the TSSLConfig scope buckets"
require_fixed '- `HandshakeTimeout`' "$api_ref" \
  "API reference no longer lists HandshakeTimeout inside the TSSLConfig scope buckets"
require_fixed '- `BufferSize`' "$api_ref" \
  "API reference no longer lists BufferSize inside the TSSLConfig scope buckets"
require_fixed '- `ServerName`' "$api_ref" \
  "API reference no longer lists ServerName inside the TSSLConfig scope buckets"
require_fixed '- `EnableCompression`' "$api_ref" \
  "API reference no longer lists EnableCompression inside the TSSLConfig scope buckets"
require_fixed '- `EnableSessionTickets`' "$api_ref" \
  "API reference no longer lists EnableSessionTickets inside the TSSLConfig scope buckets"
require_fixed '- `EnableOCSPStapling`' "$api_ref" \
  "API reference no longer lists EnableOCSPStapling inside the TSSLConfig scope buckets"
require_fixed 'factory 与 direct-library default-config path 会先把它们归一化进 `Options`' "$api_ref" \
  "API reference no longer states that option-bridge flags normalize into Options"

require_fixed "LogLevel is library-scoped. Configure logging through ISSLLibrary defaults instead of TSSLFactory.CreateContext(const AConfig)." \
  "$factory_file" "factory no longer rejects request-scoped LogLevel overrides as library-scoped"
require_fixed "LogCallback is library-scoped. Configure logging through ISSLLibrary defaults instead of TSSLFactory.CreateContext(const AConfig)." \
  "$factory_file" "factory no longer rejects request-scoped LogCallback overrides as library-scoped"
require_fixed "HandshakeTimeout is connection-scoped. Use TSSLConnector.WithTimeout, " \
  "$factory_file" "factory no longer names HandshakeTimeout as connection-scoped"
require_fixed "ISSLConnectionControl.SetTimeout instead of " \
  "$factory_file" "factory no longer points HandshakeTimeout callers at the current runtime owner"
require_fixed "BufferSize is not a context-scoped factory option. Configure buffering in the surrounding " \
  "$factory_file" "factory no longer rejects BufferSize as a non-context-scoped option"
require_fixed "received TSSLConfig.ServerName as deprecated context-level SNI compatibility" \
  "$factory_file" "factory no longer emits the context-level ServerName compatibility warning"
require_fixed "if AConfig.EnableCompression then" "$factory_file" \
  "factory no longer normalizes EnableCompression into Options"
require_fixed "if AConfig.EnableSessionTickets then" "$factory_file" \
  "factory no longer normalizes EnableSessionTickets into Options"
require_fixed "if AConfig.EnableOCSPStapling then" "$factory_file" \
  "factory no longer normalizes EnableOCSPStapling into Options"
require_fixed "Result.SetSessionCacheSize(LConfig.SessionCacheSize);" "$factory_file" \
  "factory no longer applies SessionCacheSize on the context path"
require_fixed "Result.SetSessionTimeout(LConfig.SessionTimeout);" "$factory_file" \
  "factory no longer applies SessionTimeout on the context path"
require_fixed "Result.SetALPNProtocols(LConfig.ALPNProtocols);" "$factory_file" \
  "factory no longer applies ALPNProtocols on the context path"
require_fixed "procedure ApplyEarlyDataContextValues(" "$factory_file" \
  "factory no longer routes early-data application through the context-value helper"
require_fixed "AClientEnabled: Boolean;" "$factory_file" \
  "factory early-data helper no longer accepts ClientEarlyDataEnabled as an input"
require_fixed "AServerPolicy: TSSLEarlyDataServerPolicy;" "$factory_file" \
  "factory early-data helper no longer accepts ServerEarlyDataPolicy as an input"
require_fixed "AServerMaxEarlyDataSize: Cardinal" "$factory_file" \
  "factory early-data helper no longer accepts ServerMaxEarlyDataSize as an input"
require_fixed "LEarlyDataContext.SetClientEarlyDataEnabled(AClientEnabled);" "$factory_file" \
  "factory no longer applies ClientEarlyDataEnabled through the context-value helper"
require_fixed "LEarlyDataContext.SetServerMaxEarlyDataSize(AServerMaxEarlyDataSize);" "$factory_file" \
  "factory no longer applies ServerMaxEarlyDataSize through the context-value helper"
require_fixed "LEarlyDataContext.SetServerEarlyDataPolicy(AServerPolicy);" "$factory_file" \
  "factory no longer applies ServerEarlyDataPolicy through the context-value helper"
require_fixed "AConfig.ClientEarlyDataEnabled" "$factory_file" \
  "factory no longer passes ClientEarlyDataEnabled from config into early-data context application"
require_fixed "AConfig.ServerEarlyDataPolicy" "$factory_file" \
  "factory no longer passes ServerEarlyDataPolicy from config into early-data context application"
require_fixed "AConfig.ServerMaxEarlyDataSize" "$factory_file" \
  "factory no longer passes ServerMaxEarlyDataSize from config into early-data context application"
require_fixed "Configured server_early_data_replay_store_file requires a backend that implements IFreePascalContextEarlyDataReplayInstaller" \
  "$factory_file" "factory no longer documents the server replay-store file backend seam"
require_fixed "Configured server_early_data_replay_store_directory requires a backend that implements IFreePascalContextEarlyDataReplayDirectoryInstaller" \
  "$factory_file" "factory no longer documents the server replay-store directory backend seam"

require_fixed "Result.SetSessionCacheSize(LConfig.SessionCacheSize);" "$openssl_file" \
  "OpenSSL direct-library path no longer applies SessionCacheSize on the context path"
require_fixed "Result.SetSessionTimeout(LConfig.SessionTimeout);" "$openssl_file" \
  "OpenSSL direct-library path no longer applies SessionTimeout on the context path"
require_fixed "Result.SetALPNProtocols(LConfig.ALPNProtocols);" "$openssl_file" \
  "OpenSSL direct-library path no longer applies ALPNProtocols on the context path"

echo "[PASS] TSSLConfig scope buckets stay aligned across source comments, docs, factory, and direct backend paths"
