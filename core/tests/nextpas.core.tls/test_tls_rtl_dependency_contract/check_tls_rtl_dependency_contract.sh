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

# text formatting may use either the legacy conv.Format entry (deprecated,
# internal forwarder) or the current format.TextFormat entry. Both are core
# text helpers; the contract forbids bare/SysUtils Format, not this upgrade.
require_any_token() {
  local path="$1"
  local token_a="$2"
  local token_b="$3"
  if ! rg -F --quiet -- "$token_a" "$CORE_ROOT/$path" && \
     ! rg -F --quiet -- "$token_b" "$CORE_ROOT/$path"; then
    fail "$path missing either token: $token_a or $token_b"
  fi
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
ASN1="src/nextpas.core.crypto.asn1.pas"
ASN1_SHIM="src/nextpas.core.tls.asn1.pas"
CRYPTO_UTILS="src/nextpas.core.tls.crypto.utils.pas"
BACKEND_SELECTOR="src/nextpas.core.tls.backend.selector.pas"
SYSTEM_CLASSES="src/nextpas.core.system.classes.pas"

# certchain: IStream-era — dynamic arrays + owner units, no shim; text ops via text.conv
reject_token "$CERTCHAIN" "nextpas.core.system.classes"
require_token "$CERTCHAIN" "nextpas.core.base"
reject_token "$CERTCHAIN" "Classes,"
reject_token "$CERTCHAIN" "SysUtils"
reject_token "$CERTCHAIN" "Math"
require_token "$CERTCHAIN" "nextpas.core.text.conv"
reject_regex "$CERTCHAIN" '(^|[^.[:alnum:]_])Format\('
reject_regex "$CERTCHAIN" '(^|[^.[:alnum:]_])Trim\('
reject_regex "$CERTCHAIN" '(^|[^.[:alnum:]_])SameText\('
require_any_token "$CERTCHAIN" "nextpas.core.text.conv.Format(" "TextFormat("
require_token "$CERTCHAIN" "nextpas.core.text.conv.Trim("
require_token "$CERTCHAIN" "nextpas.core.text.conv.SameText("

# asn1 implementation lives under crypto; tls.asn1 is a re-export shim
require_token "$ASN1" "nextpas.core.collections.vec"
require_token "$ASN1" "nextpas.core.io.intf"
reject_token "$ASN1" "Classes,"
reject_token "$ASN1" "Contnrs,"
reject_token "$ASN1" "SysUtils, Classes, Contnrs"
if interface_uses_block "$ASN1" | grep -F --quiet "SysUtils"; then
  fail "$ASN1 interface uses must not depend on SysUtils"
fi
require_token "$ASN1" "nextpas.core.text.conv"
reject_regex "$ASN1" '(^|[^.[:alnum:]_])Format\('
require_any_token "$ASN1" "nextpas.core.text.conv.Format(" "TextFormat("
require_token "$ASN1_SHIM" "nextpas.core.crypto.asn1"
reject_token "$ASN1_SHIM" "Classes,"
reject_token "$ASN1_SHIM" "Contnrs,"

# crypto.utils: no bare SysUtils/Classes; stream via io/fs, not system.classes
reject_token "$CRYPTO_UTILS" "SysUtils, Classes"
reject_token "$CRYPTO_UTILS" "SysUtils,"
reject_token "$CRYPTO_UTILS" "Classes,"
require_token "$CRYPTO_UTILS" "nextpas.core.system"
require_token "$CRYPTO_UTILS" "nextpas.core.io.intf"
require_token "$CRYPTO_UTILS" "nextpas.core.fs.stream"

reject_token "$BACKEND_SELECTOR" "SysUtils"

require_token "$SYSTEM_CLASSES" "TStream = Classes.TStream;"

echo "tls-rtl-dependency-contract=pass"
