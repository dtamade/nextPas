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

require_pcre() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if ! python3 - "$file" "$pattern" <<'PY' >/dev/null; then
import re
import sys
from pathlib import Path

text = Path(sys.argv[1]).read_text(encoding="utf-8")
pattern = sys.argv[2]
sys.exit(0 if re.search(pattern, text, re.S) else 1)
PY
    fail "$message"
  fi
}

source_file="src/nextpas.core.tls.winssl.connection.pas"
matrix_doc="docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
guide_doc="docs/guides/WINSSL_USER_GUIDE.md"
selector_doc="docs/BACKEND_SELECTION_GUIDE.md"
api_ref="docs/reference/API_REFERENCE.md"

echo "[TEST] WinSSL session-injection semantics truth contract"

require_fixed "$api_ref" '> 按当前 Schannel truth，client-side reconnect/cache lookup 仍主要取决于相同的 `target name` 与相同的 context-level `credential handle`；' \
  "API reference must keep the canonical WinSSL reconnect truth"
require_fixed "$api_ref" '> `ISSLSessionResumption.SetSession(...)` 在 WinSSL 上当前更接近 compatibility metadata surface，而不是 native session-handle injection 点。' \
  "API reference must keep the canonical WinSSL SetSession semantic boundary"

require_fixed "$source_file" "// WinSSL currently keeps caller-supplied sessions as compatibility metadata." \
  "WinSSL source must document that SetSession is currently metadata-only"
require_fixed "$source_file" "// Shared client reconnects still follow Schannel's automatic cache key" \
  "WinSSL source must document that shared reconnects follow Schannel's automatic cache key"
require_fixed "$source_file" "// (target name + credential handle), not a native session-handle injection path." \
  "WinSSL source must document the concrete reconnect key"
require_pcre "$source_file" 'procedure TWinSSLConnection\.DoSetSession\(ASession: ISSLSession\);\s*begin\s*// WinSSL currently keeps caller-supplied sessions as compatibility metadata\.\s*// Shared client reconnects still follow Schannel'\
  "WinSSL SetSession implementation must keep the semantic-boundary comment adjacent to the implementation"
require_pcre "$source_file" 'procedure TWinSSLConnection\.DoSetSession\(ASession: ISSLSession\);\s*begin.*?FCurrentSession := ASession;\s*FSessionReused := False;\s*end;' \
  "WinSSL SetSession implementation must remain a metadata store plus false reuse reset"

require_fixed "$matrix_doc" 'Resumption2.SetSession(Session);  // 保存 compatibility metadata；Schannel reconnect 仍主要取决于 target name + credential handle' \
  "WinSSL backend matrix example must demote SetSession to compatibility metadata"
require_fixed "$matrix_doc" '> 注意：按当前实现，WinSSL 的 `ISSLSessionResumption.SetSession(...)` 更接近' \
  "WinSSL backend matrix must explain the current SetSession semantic boundary"
require_fixed "$matrix_doc" '> compatibility metadata surface；client-side reconnect/cache lookup 仍主要取决于' \
  "WinSSL backend matrix must explain the reconnect key boundary"

require_fixed "$guide_doc" '- ⚠️ `ISSLSessionResumption.SetSession(...)` 当前更接近 compatibility metadata surface；client-side reconnect/cache lookup 仍主要取决于相同的 `target name` 与相同的 context-level `credential handle`' \
  "WinSSL user guide must explain the current SetSession semantic boundary"

require_fixed "$selector_doc" '- 把 session resumption / tickets 当成已稳定 runtime-proven 能力' \
  "Backend selection guide must keep the WinSSL session-runtime caveat visible in the Windows scenario"
require_fixed "$selector_doc" '则不要只因为“Windows + 零依赖”就默认停在 WinSSL；这类路线当前仍应优先重新评估 OpenSSL。' \
  "Backend selection guide must steer capability-sensitive Windows users back to OpenSSL when needed"

echo "[PASS] WinSSL session-injection semantics truth contract passed"
