#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$root_dir"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -F -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

root_guide="docs/INTEGRATION_GUIDE.md"
shadow_guide="docs/guides/INTEGRATION_GUIDE.md"
readme="docs/README.md"
index_file="docs/DOCUMENTATION_INDEX.md"
facade_contract="tests/scripts/test_facade_main_entry_truth_contract.sh"
landing_sni_contract="tests/scripts/test_landing_docs_connection_level_sni_guidance_contract.sh"
import_contract="tests/scripts/test_public_unit_import_guidance_truth_contract.sh"

echo "[TEST] integration guide canonical path truth contract"

[[ -f "$root_guide" ]] || fail "canonical integration guide is missing at $root_guide"
[[ ! -f "$shadow_guide" ]] || fail "stale shadow integration guide still exists at $shadow_guide"

require_fixed "$readme" "[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)" \
  "README must keep pointing at the canonical root integration guide"
require_fixed "$index_file" "[INTEGRATION_GUIDE.md](INTEGRATION_GUIDE.md)" \
  "documentation index must keep pointing at the canonical root integration guide"

require_fixed "$facade_contract" 'integration_file="docs/INTEGRATION_GUIDE.md"' \
  "facade main-entry contract must target the canonical root integration guide"
require_absent "$facade_contract" "docs/guides/INTEGRATION_GUIDE.md" \
  "facade main-entry contract must stop targeting the stale guides shadow copy"

require_fixed "$landing_sni_contract" "docs/INTEGRATION_GUIDE.md|ClientConn: ISSLClientConnection;" \
  "landing-docs SNI contract must target the canonical root integration guide"
require_absent "$landing_sni_contract" "docs/guides/INTEGRATION_GUIDE.md" \
  "landing-docs SNI contract must stop targeting the stale guides shadow copy"

require_fixed "$import_contract" 'integration_guide="docs/INTEGRATION_GUIDE.md"' \
  "public unit/import guidance contract must cover the canonical root integration guide"
require_absent "$import_contract" "docs/guides/INTEGRATION_GUIDE.md" \
  "public unit/import guidance contract must not treat the stale guides shadow copy as active"

echo "[PASS] integration guide canonical path truth contract passed"
