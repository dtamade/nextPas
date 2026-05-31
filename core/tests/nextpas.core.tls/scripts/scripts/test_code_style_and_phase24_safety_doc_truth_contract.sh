#!/usr/bin/env bash
set -euo pipefail

STYLE_DOC="docs/guides/CODE_STYLE.md"
PHASE_DOC="docs/guides/MIGRATION_GUIDE_PHASE_2.4.md"
SAFETY_UNIT="src/nextpas.core.tls.safety.pas"

require_contains_in() {
  local file="$1"
  local pattern="$2"
  if ! rg -F -q "$pattern" "$file"; then
    echo "[FAIL] missing pattern in $file: $pattern" >&2
    exit 1
  fi
}

require_absent_in() {
  local file="$1"
  local pattern="$2"
  if rg -F -q "$pattern" "$file"; then
    echo "[FAIL] unexpected pattern present in $file: $pattern" >&2
    exit 1
  fi
}

require_contains_in "$STYLE_DOC" 'LContext.CreateConnection(YourConnectedSocket)'
require_absent_in "$STYLE_DOC" 'LContext.CreateConnection;'
require_contains_in "$STYLE_DOC" '  fafafa.ssl,'
require_contains_in "$STYLE_DOC" '  nextpas.core.tls.context.builder;'
require_absent_in "$STYLE_DOC" 'nextpas.core.tls.base;'

require_contains_in "$PHASE_DOC" '历史阶段说明'
require_contains_in "$PHASE_DOC" 'MIGRATION_GUIDE.md'
require_contains_in "$PHASE_DOC" 'nextpas.core.tls.safety'
require_contains_in "$PHASE_DOC" 'src/nextpas.core.tls.safety.pas'
require_absent_in "$PHASE_DOC" 'nextpas.core.tls.types.safe'

require_contains_in "$SAFETY_UNIT" 'Unit: nextpas.core.tls.safety'
require_absent_in "$SAFETY_UNIT" 'Unit: nextpas.core.tls.types.safe'

echo "[PASS] code style and phase2.4 safety doc truth contract passed"
