#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

fail() {
  echo "[tls-rtl-dependency-contract] FAIL: $*" >&2
  exit 1
}

require_token() {
  local path="$1"
  local token="$2"
  rg -F --quiet -- "$token" "$CORE_ROOT/$path" || fail "$path missing token: $token"
}

reject_token() {
  local path="$1"
  local token="$2"
  if rg -F --quiet -- "$token" "$CORE_ROOT/$path"; then
    fail "$path must not contain token: $token"
  fi
}

reject_regex() {
  local path="$1"
  local regex="$2"
  if rg --quiet -- "$regex" "$CORE_ROOT/$path"; then
    fail "$path must not match regex: $regex"
  fi
}

interface_uses_block() {
  local path="$1"
  awk '
    /^[ \t]*interface[ \t]*$/ {
      in_interface = 1
      next
    }
    /^[ \t]*implementation[ \t]*$/ {
      exit
    }
    !in_interface {
      next
    }
    /^[ \t]*uses[ \t]*/ {
      in_uses = 1
    }
    in_uses {
      print
      if ($0 ~ /;/) {
        exit
      }
    }
  ' "$CORE_ROOT/$path"
}

CERTCHAIN="src/nextpas.core.tls.certchain.pas"
ASN1="src/nextpas.core.tls.asn1.pas"
CRYPTO_UTILS="src/nextpas.core.tls.crypto.utils.pas"
BACKEND_SELECTOR="src/nextpas.core.tls.backend.selector.pas"
SYSTEM_CLASSES="src/nextpas.core.system.classes.pas"

require_token "$CERTCHAIN" "Classes,"
reject_token "$CERTCHAIN" "SysUtils"
reject_token "$CERTCHAIN" "Math"
require_token "$CERTCHAIN" "nextpas.core.text.conv"
reject_regex "$CERTCHAIN" '(^|[^.[:alnum:]_])Format\('
reject_regex "$CERTCHAIN" '(^|[^.[:alnum:]_])Trim\('
reject_regex "$CERTCHAIN" '(^|[^.[:alnum:]_])SameText\('
require_token "$CERTCHAIN" "nextpas.core.text.conv.Format("
require_token "$CERTCHAIN" "nextpas.core.text.conv.Trim("
require_token "$CERTCHAIN" "nextpas.core.text.conv.SameText("

require_token "$ASN1" "Classes, Contnrs,"
reject_token "$ASN1" "SysUtils, Classes, Contnrs"
if interface_uses_block "$ASN1" | grep -F --quiet "SysUtils"; then
  fail "$ASN1 interface uses must not depend on SysUtils"
fi
require_token "$ASN1" "nextpas.core.text.conv"
reject_regex "$ASN1" '(^|[^.[:alnum:]_])Format\('
require_token "$ASN1" "nextpas.core.text.conv.Format("

reject_token "$CRYPTO_UTILS" "SysUtils, Classes"
reject_token "$CRYPTO_UTILS" "SysUtils,"
reject_token "$CRYPTO_UTILS" "Classes,"
require_token "$CRYPTO_UTILS" "nextpas.core.system"
require_token "$CRYPTO_UTILS" "nextpas.core.system.classes"

reject_token "$BACKEND_SELECTOR" "SysUtils"

require_token "$SYSTEM_CLASSES" "TStream = Classes.TStream;"

echo "tls-rtl-dependency-contract=pass"
