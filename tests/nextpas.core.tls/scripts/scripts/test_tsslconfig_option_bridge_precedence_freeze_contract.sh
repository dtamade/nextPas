#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

factory_file="src/nextpas.core.tls.factory.pas"
api_ref="docs/reference/API_REFERENCE.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed "Option-bridge compatibility inputs keep their historical write-through behavior:" \
  "$factory_file" \
  "factory source no longer documents option-bridge write-through precedence"
require_fixed "if AConfig.EnableCompression then" \
  "$factory_file" \
  "factory no longer applies EnableCompression before final option projection"
require_fixed "if AConfig.EnableSessionTickets then" \
  "$factory_file" \
  "factory no longer applies EnableSessionTickets before final option projection"
require_fixed "if AConfig.EnableOCSPStapling then" \
  "$factory_file" \
  "factory no longer applies EnableOCSPStapling before final option projection"
require_fixed "AConfig.EnableCompression := not (ssoDisableCompression in AConfig.Options);" \
  "$factory_file" \
  "factory no longer projects final compression truth back to legacy boolean"
require_fixed "AConfig.EnableSessionTickets := ssoEnableSessionTickets in AConfig.Options;" \
  "$factory_file" \
  "factory no longer projects final session-ticket truth back to legacy boolean"
require_fixed "AConfig.EnableOCSPStapling := ssoEnableOCSPStapling in AConfig.Options;" \
  "$factory_file" \
  "factory no longer projects final OCSP stapling truth back to legacy boolean"

require_fixed '当调用方同时传入冲突的 `Options` 与 option-bridge booleans 时，当前冻结规则是：' \
  "$api_ref" \
  "API reference no longer records option-bridge conflict precedence"
require_fixed 'legacy boolean 赢，先回写对应 option bit，再把最终 `Options` 真相投影回这三个 boolean 字段。' \
  "$api_ref" \
  "API reference no longer explains the final option-truth projection"

require_fixed "TSSLFactory.NormalizeConfig(LConfig);" \
  "src/nextpas.core.tls.openssl.backed.pas" \
  "OpenSSL SetDefaultConfig no longer normalizes conflicting option-bridge input"
require_fixed "TSSLFactory.NormalizeConfig(LConfig);" \
  "src/nextpas.core.tls.freepascal.lib.pas" \
  "FreePascal SetDefaultConfig no longer normalizes conflicting option-bridge input"
require_fixed "TSSLFactory.NormalizeConfig(LConfig);" \
  "src/nextpas.core.tls.winssl.lib.pas" \
  "WinSSL SetDefaultConfig no longer normalizes conflicting option-bridge input"
require_fixed "TSSLFactory.NormalizeConfig(LConfig);" \
  "src/nextpas.core.tls.mbedtls.lib.pas" \
  "MbedTLS SetDefaultConfig no longer normalizes conflicting option-bridge input"
require_fixed "TSSLFactory.NormalizeConfig(LConfig);" \
  "src/nextpas.core.tls.wolfssl.lib.pas" \
  "WolfSSL SetDefaultConfig no longer normalizes conflicting option-bridge input"

echo "[PASS] TSSLConfig option-bridge precedence truth remains frozen across source and docs"
