#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
api_ref="docs/reference/API_REFERENCE.md"
security_test="tests/security/test_session_security.pas"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_absent() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed "EnableCompression: Boolean;              // Compatibility-only option-bridge flag; prefer Options; normalized into Options" \
  "$base_file" \
  "TSSLConfig.EnableCompression source comment no longer marks the field as compatibility-only"
require_fixed "EnableSessionTickets: Boolean;           // Compatibility-only option-bridge flag; prefer Options; normalized into Options" \
  "$base_file" \
  "TSSLConfig.EnableSessionTickets source comment no longer marks the field as compatibility-only"
require_fixed "EnableOCSPStapling: Boolean;             // Compatibility-only option-bridge flag; prefer Options; normalized into Options" \
  "$base_file" \
  "TSSLConfig.EnableOCSPStapling source comment no longer marks the field as compatibility-only"

require_fixed "- compatibility-only option-bridge flags" \
  "$api_ref" \
  "API reference no longer classifies the option-bridge booleans as compatibility-only"
require_fixed '新代码应优先直接写 `Options`。' \
  "$api_ref" \
  "API reference no longer steers callers toward Options as the preferred surface"
require_fixed 'legacy boolean 赢，先回写对应 option bit，再把最终 `Options` 真相投影回这三个 boolean 字段。' \
  "$api_ref" \
  "API reference no longer records the frozen option-bridge precedence truth"

require_fixed "option-bridge boolean field surface" \
  "tests/test_factory_logic.pas" \
  "test_factory_logic no longer declares its option-bridge compatibility coverage"
require_fixed "option-bridge boolean field surface" \
  "tests/test_data_structures.pas" \
  "test_data_structures no longer declares its option-bridge compatibility coverage"
require_fixed "INTENTIONAL_COMPAT: this file intentionally keeps option-bridge boolean" \
  "tests/test_tsslconfig_option_bridge_default_truth.pas" \
  "default-truth option-bridge coverage lost its compatibility label"
require_fixed "INTENTIONAL_COMPAT: this file intentionally freezes the remaining" \
  "tests/test_tsslconfig_option_bridge_precedence_freeze.pas" \
  "precedence-freeze option-bridge coverage lost its compatibility label"
require_fixed "INTENTIONAL_COMPAT: this file intentionally covers the direct-library" \
  "tests/test_direct_library_default_config_parity.pas" \
  "direct-library default-config parity lost its option-bridge compatibility label"

require_absent "EnableSessionTickets :=" \
  "$security_test" \
  "active session security test should not keep teaching EnableSessionTickets as the primary write surface"

echo "[PASS] TSSLConfig option-bridge surface truth stays narrowed to compatibility-only source/docs/tests"
