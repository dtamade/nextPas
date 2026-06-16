#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SOURCE="$CORE_ROOT/src/nextpas.core.base.utils.pas"

fail() {
  echo "[base-utils-source-contract] FAIL: $*" >&2
  exit 1
}

require_token() {
  local token="$1"
  rg -F --quiet -- "$token" "$SOURCE" || fail "missing source token: $token"
}

require_token "procedure ClearOutInterface(out AIntf);"
require_token "IInterface(AIntf) := nil;"

object_supports_section="$(awk '
  /^[[:space:]]*implementation[[:space:]]*$/ { in_implementation = 1 }
  !in_implementation { next }
  /function Supports\(const AInstance: TObject; const AIID: TGuid; out AIntf\): Boolean;/ { in_section = 1 }
  in_section { print }
  in_section && /function Supports\(const AInstance: IInterface; const AIID: TGuid; out AIntf\): Boolean;/ { exit }
' "$SOURCE")"

interface_supports_section="$(awk '
  /^[[:space:]]*implementation[[:space:]]*$/ { in_implementation = 1 }
  !in_implementation { next }
  /function Supports\(const AInstance: IInterface; const AIID: TGuid; out AIntf\): Boolean;/ { in_section = 1 }
  in_section { print }
  in_section && /^end\.$/ { exit }
' "$SOURCE")"

printf '%s\n' "$object_supports_section" | rg -F --quiet "if AInstance = nil then" ||
  fail "object Supports must branch on nil input"
printf '%s\n' "$object_supports_section" | rg -F --quiet "Result := AInstance.GetInterface(AIID, AIntf);" ||
  fail "object Supports must query the requested interface"
printf '%s\n' "$object_supports_section" | rg -F --quiet "if not Result then" ||
  fail "object Supports must branch on unsupported query result"
printf '%s\n' "$object_supports_section" | rg -F --quiet "ClearOutInterface(AIntf);" ||
  fail "object Supports must explicitly clear failed out interface"

printf '%s\n' "$interface_supports_section" | rg -F --quiet "if AInstance = nil then" ||
  fail "interface Supports must branch on nil input"
printf '%s\n' "$interface_supports_section" | rg -F --quiet "Result := AInstance.QueryInterface(AIID, AIntf) = S_OK;" ||
  fail "interface Supports must query the requested interface"
printf '%s\n' "$interface_supports_section" | rg -F --quiet "if not Result then" ||
  fail "interface Supports must branch on unsupported query result"
printf '%s\n' "$interface_supports_section" | rg -F --quiet "ClearOutInterface(AIntf);" ||
  fail "interface Supports must explicitly clear failed out interface"

echo "base-utils-source-contract=pass"
