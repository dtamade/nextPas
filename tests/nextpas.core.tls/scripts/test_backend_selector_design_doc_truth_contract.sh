#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SELECTOR_SRC="$ROOT_DIR/src/nextpas.core.tls.backend.selector.pas"
BUILDER_SRC="$ROOT_DIR/src/nextpas.core.tls.context.builder.pas"
FREEPASCAL_LIB="$ROOT_DIR/src/nextpas.core.tls.freepascal.lib.pas"
WINSSL_LIB="$ROOT_DIR/src/nextpas.core.tls.winssl.lib.pas"
TOP_MATRIX="$ROOT_DIR/docs/BACKEND_CAPABILITY_MATRIX.md"
ABSTRACTION_DOC="$ROOT_DIR/docs/reference/BACKEND_ABSTRACTION_LAYER_DESIGN.md"
SELECTOR_DOC="$ROOT_DIR/docs/reference/BACKEND_SELECTOR_DESIGN.md"

fail() {
  echo "[FAIL] $1"
  exit 1
}

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    echo "[PASS] $message"
  else
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    fail "$message"
  else
    echo "[PASS] $message"
  fi
}

echo "[TEST] backend selector design doc truth contract"

require_fixed "$SELECTOR_SRC" \
  "function SelectBestBackend(" \
  "Selector source must keep the function-based single-selection API"
require_fixed "$SELECTOR_SRC" \
  "function SelectBestBackends(" \
  "Selector source must keep the function-based ranked-selection API"
require_fixed "$SELECTOR_SRC" \
  "RequiredFeatures: TSSLFeatures;" \
  "Selector source must keep TSSLRequirements.RequiredFeatures"
require_fixed "$BUILDER_SRC" \
  "function WithAutoBackendSelection(const ARequirements: TSSLRequirements): ISSLContextBuilder;" \
  "Builder source must keep WithAutoBackendSelection as the public auto-selection entry"
require_fixed "$BUILDER_SRC" \
  "function WithSecurityFirst: ISSLContextBuilder;" \
  "Builder source must keep WithSecurityFirst convenience API"
require_fixed "$BUILDER_SRC" \
  "function WithPerformanceFirst: ISSLContextBuilder;" \
  "Builder source must keep WithPerformanceFirst convenience API"
require_fixed "$BUILDER_SRC" \
  "function WithCompatibilityFirst: ISSLContextBuilder;" \
  "Builder source must keep WithCompatibilityFirst convenience API"
require_fixed "$BUILDER_SRC" \
  "function RequireTLS13: ISSLContextBuilder;" \
  "Builder source must keep RequireTLS13 convenience API"
require_fixed "$BUILDER_SRC" \
  "function RequireCipher(ACipher: TSSLCipher): ISSLContextBuilder;" \
  "Builder source must keep RequireCipher convenience API"
require_fixed "$BUILDER_SRC" \
  "function RequirePKCS11Support: ISSLContextBuilder;" \
  "Builder source must keep RequirePKCS11Support convenience API"
require_fixed "$BUILDER_SRC" \
  "function PreferOSNative: ISSLContextBuilder;" \
  "Builder source must keep PreferOSNative convenience API"

require_fixed "$FREEPASCAL_LIB" \
  "Result.BackendType := sslFreePascal;" \
  "FreePascal source must remain an active backend"
require_fixed "$WINSSL_LIB" \
  "Result.OCSPStaplingSupport := sslSupportNone;" \
  "WinSSL source must keep OCSP stapling at none-published capability"
require_fixed "$WINSSL_LIB" \
  "Result.EarlyDataSupport := sslSupportNone;" \
  "WinSSL source must keep early-data at none-published capability"
require_fixed "$TOP_MATRIX" \
  "| **Early Data (0-RTT)**       | ⚠️         | ✅      | ❌     | ❌      | ⚠️      |" \
  "Top-level matrix must continue to classify WinSSL early-data as unavailable"
require_fixed "$TOP_MATRIX" \
  "| **OCSP Stapling**            | ⚠️         | ✅      | ❌     | ❌      | ⚠️      |" \
  "Top-level matrix must continue to classify WinSSL OCSP stapling as unavailable"

require_fixed "$ABSTRACTION_DOC" \
  '`FreePascal` 不是 future backend，当前已是活跃 backend；当前 capability truth 统一以 `docs/BACKEND_CAPABILITY_MATRIX.md` 为准。' \
  "Abstraction design doc must state that FreePascal is active and defer capability truth to the canonical matrix"
require_fixed "$ABSTRACTION_DOC" \
  ".WithAutoBackendSelection(Requirements)" \
  "Abstraction design doc must use the current auto-selection builder entry"
require_fixed "$ABSTRACTION_DOC" \
  "Requirements.RequiredProtocols := [sslProtocolTLS13];" \
  "Abstraction design doc must express TLS 1.3 requirements with TSSLRequirements"
require_fixed "$ABSTRACTION_DOC" \
  "Requirements.RequiredFeatures := [sslFeatOCSPStapling];" \
  "Abstraction design doc must express OCSP requirements with TSSLFeatures"
require_absent "$ABSTRACTION_DOC" \
  ".WithRequirements([brTLS13, brOCSPStapling])" \
  "Abstraction design doc must stop using the retired WithRequirements/br* draft API"
require_absent "$ABSTRACTION_DOC" \
  "(Future)" \
  "Abstraction design doc must stop presenting FreePascal as a future backend"

require_fixed "$SELECTOR_DOC" \
  '当前公开 selector API 以 `SelectBestBackend(...)` / `SelectBestBackends(...)` 与 `TSSLContextBuilder.WithAutoBackendSelection(...)` 为准。' \
  "Selector design doc must point to the current public selector API"
require_fixed "$SELECTOR_DOC" \
  '当前 source 尚未发布 `TBackendSelector` / `TBackendSelectionResult` / `WithPreferredBackend(...)` / `WithFallbackBackend(...)` / `WithAllowPartialMatch` 这组草案 surface，也没有 dedicated `FAFAFA_SSL_BACKEND` / `FAFAFA_SSL_DISABLE_BACKEND` / `FAFAFA_SSL_SELECTOR_DEBUG` selector entrypoint。' \
  "Selector design doc must record the retired draft API surface as unpublished"
require_fixed "$SELECTOR_DOC" \
  'WinSSL 当前 `OCSPStaplingSupport=sslSupportNone`、`EarlyDataSupport=sslSupportNone`，因此 requirement 不能把它算成支持 server OCSP / early-data 的 backend。' \
  "Selector design doc must keep WinSSL none-capability truth"
require_fixed "$SELECTOR_DOC" \
  "Results := SelectBestBackends(Requirements, 3);" \
  "Selector design doc must use the current ranked-selection API"
require_fixed "$SELECTOR_DOC" \
  "Requirements.RequiredFeatures := [sslFeatOCSPStapling];" \
  "Selector design doc must describe feature requirements with TSSLFeatures"
require_absent "$SELECTOR_DOC" \
  "TBackendRequirement = (" \
  "Selector design doc must stop publishing the retired TBackendRequirement enum"
require_absent "$SELECTOR_DOC" \
  ".WithAutoBackend  // 自动选择" \
  "Selector design doc must stop using the retired WithAutoBackend draft API"
require_absent "$SELECTOR_DOC" \
  ".WithPreferredBackend(sslOpenSSL)" \
  "Selector design doc must stop publishing WithPreferredBackend as a live builder API"
require_absent "$SELECTOR_DOC" \
  ".WithFallbackBackend(sslMbedTLS)" \
  "Selector design doc must stop publishing WithFallbackBackend as a live builder API"
require_absent "$SELECTOR_DOC" \
  ".WithAllowPartialMatch" \
  "Selector design doc must stop publishing WithAllowPartialMatch as a live builder API"
require_absent "$SELECTOR_DOC" \
  "export FAFAFA_SSL_BACKEND=openssl" \
  "Selector design doc must stop publishing nonexistent selector env vars"

echo "[PASS] backend selector design doc truth contract passed"
