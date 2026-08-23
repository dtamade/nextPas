#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$repo_root"

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

builder_src="core/src/nextpas.core.tls.context.builder.pas"

printf '[TEST] active server example verify-intent truth contract\n'

require_fixed "$builder_src" 'Result := WithAutoBackendSelection(CreatePerformanceFirstRequirements);' \
  "WithPerformanceFirst source truth must remain backend-selection-only"
require_fixed "$builder_src" 'Result := WithAutoBackendSelection(CreateSecurityFirstRequirements);' \
  "WithSecurityFirst source truth must remain backend-selection-only"
require_fixed "$builder_src" 'Result := WithAutoBackendSelection(CreateCompatibilityFirstRequirements);' \
  "WithCompatibilityFirst source truth must remain backend-selection-only"





printf '[PASS] active server example verify-intent truth contract passed\n'
