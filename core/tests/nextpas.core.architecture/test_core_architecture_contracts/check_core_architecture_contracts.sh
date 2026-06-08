#!/usr/bin/env bash
set -euo pipefail

CORE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$CORE_ROOT"

fail() {
  echo "[FAIL] $*" >&2
  exit 1
}

require_file() {
  local path="$1"
  [[ -s "$path" ]] || fail "required non-empty file missing: core/$path"
}

require_token() {
  local path="$1"
  local token="$2"
  rg -F --quiet -- "$token" "$path" || fail "core/$path missing token: $token"
}

reject_token() {
  local path="$1"
  local token="$2"
  if rg -F --quiet -- "$token" "$path"; then
    fail "core/$path must not contain token: $token"
  fi
}

top_module() {
  local unit="$1"
  unit="${unit#nextpas.core.}"
  unit="${unit%%.*}"
  printf '%s\n' "$unit"
}

list_pascal_uses_units() {
  awk '
    function trim(s) {
      gsub(/^[ \t\r\n]+|[ \t\r\n]+$/, "", s)
      return s
    }
    function emit_units(line, parts, i, unit) {
      gsub(/\{[^}]*\}/, "", line)
      sub(/\/\/.*/, "", line)
      gsub(/^[ \t]*uses[ \t]*/, "", line)
      split(line, parts, /[,;]/)
      for (i in parts) {
        unit = trim(parts[i])
        if (unit != "" && unit !~ /^\$/) {
          print unit
        }
      }
    }
    /^[ \t]*uses[ \t]*/ {
      in_uses = 1
      emit_units($0)
      if ($0 ~ /;/) in_uses = 0
      next
    }
    in_uses {
      emit_units($0)
      if ($0 ~ /;/) in_uses = 0
    }
  ' "$1"
}

require_file "docs/module-registry.md"
require_file "docs/l1-goal-tree.md"
require_file "docs/platform/README.md"
require_file "docs/platform/master-spec.md"
require_file "docs/platform/goal-tree.md"
require_file "docs/platform/consumer-contract-audit.md"
require_file "docs/platform/runtime-truth-matrix.md"

for tier in source-contract forced-compile focused-runtime ci-runtime-matrix; do
  require_token "docs/module-registry.md" "$tier"
  require_token "docs/l1-goal-tree.md" "$tier"
  require_token "docs/platform/master-spec.md" "$tier"
done

for module_name in base errors platform mem system atomic math simd; do
  require_token "docs/module-registry.md" "| \`$module_name\` |"
done

reject_token "docs/l1-goal-tree.md" "✅ 完成"
reject_token "docs/l1-goal-tree.md" "All tests passed"
reject_token "docs/l1-goal-tree.md" "100% 接口测试覆盖"
reject_token "docs/platform-goal-tree.md" "✅"
reject_token "docs/platform-goal-tree.md" "100% 接口测试覆盖"
reject_token "docs/platform/goal-tree.md" "runtime ready"

require_token "docs/design-conventions.md" "docs/module-registry.md"
require_token "docs/platform/master-spec.md" "Readiness and completion stay split"
require_token "docs/platform/master-spec.md" "not runtime ready"
require_token "docs/platform/consumer-contract-audit.md" "readiness lane"
require_token "docs/platform/consumer-contract-audit.md" "completion lane"
require_token "docs/platform/runtime-truth-matrix.md" "AsyncRead/AsyncWrite file completion"

ALLOWED_L0_TOP_MODULES=(
  "base"
  "contracts"
  "errors"
  "exception"
  "platform"
  "mem"
  "system"
  "atomic"
  "math"
  "simd"
)

KNOWN_L0_DEPENDENCY_DEBT=(
  "src/nextpas.core.mem.allocator.mimalloc.pas|nextpas.core.os.env"
  "src/nextpas.core.mem.allocator.mimalloc.pas|nextpas.core.path"
  "src/nextpas.core.mem.mapped_ring_buffer.pas|nextpas.core.fs.util"
  "src/nextpas.core.mem.mapped_ring_buffer.sharded.pas|nextpas.core.text.conv"
  "src/nextpas.core.mem.mapped_slab_pool.pas|nextpas.core.fs.util"
  "src/nextpas.core.simd.cpuinfo.lazy.pas|nextpas.core.os.env"
  "src/nextpas.core.system.sysutils.pas|nextpas.core.text.conv"
)

RAW_HOST_UNITS=(
  "windows"
  "baseunix"
  "unix"
  "dynlibs"
  "ctypes"
)

RAW_HOST_ALLOWLIST=(
  "src/nextpas.core.fs.util.pas|BaseUnix"
  "src/nextpas.core.git.libgit2.backend.pas|ctypes"
  "src/nextpas.core.git.libgit2.binding.pas|ctypes"
  "src/nextpas.core.git.libgit2.binding.pas|Dynlibs"
  "src/nextpas.core.git.libgit2.ffi.pas|ctypes"
  "src/nextpas.core.io.uring.pas|BaseUnix"
  "src/nextpas.core.mem.allocator.mimalloc.pas|dynlibs"
  "src/nextpas.core.mem.mimalloc.binding.pas|DynLibs"
  "src/nextpas.core.mem.secure.pas|Windows"
  "src/nextpas.core.mem.secure.pas|BaseUnix"
  "src/nextpas.core.simd.cpuinfo.darwin.pas|BaseUnix"
  "src/nextpas.core.simd.cpuinfo.darwin.pas|ctypes"
  "src/nextpas.core.simd.cpuinfo.diagnostic.pas|Windows"
  "src/nextpas.core.simd.cpuinfo.unix.pas|Unix"
  "src/nextpas.core.simd.cpuinfo.windows.pas|Windows"
  "src/nextpas.core.tls.crypto.utils.pas|Windows"
  "src/nextpas.core.tls.dialer.pas|BaseUnix"
  "src/nextpas.core.tls.dns.ldns.pas|dynlibs"
  "src/nextpas.core.tls.factory.pas|Windows"
  "src/nextpas.core.tls.freepascal.connection.pas|Windows"
  "src/nextpas.core.tls.freepascal.connection.pas|BaseUnix"
  "src/nextpas.core.tls.freepascal.connection.pas|Unix"
  "src/nextpas.core.tls.freepascal.earlydatareplay.dirstore.pas|Unix"
  "src/nextpas.core.tls.freepascal.earlydatareplay.fileprovider.pas|Unix"
  "src/nextpas.core.tls.mbedtls.api.pas|dynlibs"
  "src/nextpas.core.tls.nonblocking.pas|BaseUnix"
  "src/nextpas.core.tls.nonblocking.pas|Unix"
  "src/nextpas.core.tls.openssl.api.asn1.pas|dynlibs"
  "src/nextpas.core.tls.openssl.api.async.pas|Windows"
  "src/nextpas.core.tls.openssl.api.async.pas|BaseUnix"
  "src/nextpas.core.tls.openssl.api.bio.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.bio.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.bn.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.cms.pas|dynlibs"
  "src/nextpas.core.tls.openssl.api.core.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.core.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.crypto.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.dh.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.dh.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.dsa.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.dsa.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.ecdh.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.ecdh.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.ecdsa.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.ecdsa.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.err.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.hmac.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.hmac.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.ocsp.pas|dynlibs"
  "src/nextpas.core.tls.openssl.api.pem.pas|dynlibs"
  "src/nextpas.core.tls.openssl.api.pkcs.pas|dynlibs"
  "src/nextpas.core.tls.openssl.api.rand.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.rand.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.rsa.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.rsa.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.ssl.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.ssl.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.thread.pas|Windows"
  "src/nextpas.core.tls.openssl.api.x509.pas|DynLibs"
  "src/nextpas.core.tls.openssl.api.x509.pas|ctypes"
  "src/nextpas.core.tls.openssl.api.x509v3.pas|DynLibs"
  "src/nextpas.core.tls.openssl.backed.pas|DynLibs"
  "src/nextpas.core.tls.openssl.base.pas|ctypes"
  "src/nextpas.core.tls.openssl.connection.pas|ctypes"
  "src/nextpas.core.tls.openssl.loader.pas|ctypes"
  "src/nextpas.core.tls.openssl.loader.pas|Windows"
  "src/nextpas.core.tls.openssl.loader.pas|dynlibs"
  "src/nextpas.core.tls.openssl.session.pas|ctypes"
  "src/nextpas.core.tls.pkcs11.api.pas|DynLibs"
  "src/nextpas.core.tls.pkcs11.loader.pas|DynLibs"
  "src/nextpas.core.tls.random.pas|Windows"
  "src/nextpas.core.tls.session.cache.pas|BaseUnix"
  "src/nextpas.core.tls.timeout.pas|BaseUnix"
  "src/nextpas.core.tls.timeout.pas|Unix"
  "src/nextpas.core.tls.transport.pas|BaseUnix"
  "src/nextpas.core.tls.winssl.api.pas|Windows"
  "src/nextpas.core.tls.winssl.base.pas|Windows"
  "src/nextpas.core.tls.winssl.certificate.pas|Windows"
  "src/nextpas.core.tls.winssl.certstore.pas|Windows"
  "src/nextpas.core.tls.winssl.connection.pas|Windows"
  "src/nextpas.core.tls.winssl.context.pas|Windows"
  "src/nextpas.core.tls.winssl.enterprise.pas|Windows"
  "src/nextpas.core.tls.winssl.errors.pas|Windows"
  "src/nextpas.core.tls.winssl.lib.pas|Windows"
  "src/nextpas.core.tls.winssl.session.pas|Windows"
  "src/nextpas.core.tls.winssl.utils.pas|Windows"
  "src/nextpas.core.tls.wolfssl.api.pas|dynlibs"
  "src/nextpas.core.tls.wolfssl.api.pas|ctypes"
  "src/nextpas.core.tls.wolfssl.session.pas|ctypes"
  "src/nextpas.core.tui.clipboard.pas|BaseUnix"
  "src/nextpas.core.tui.clipboard.pas|Unix"
)

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

is_l0_source() {
  local file="$1"
  [[ "$file" =~ ^src/nextpas\.core\.(base|errors|platform|mem|system|atomic|math|simd)(\.|$) ]]
}

tmp_l0_unknown="$(mktemp)"
tmp_raw_unknown="$(mktemp)"
trap 'rm -f "$tmp_l0_unknown" "$tmp_raw_unknown"' EXIT

while IFS= read -r file; do
  file="${file#./}"
  while IFS= read -r unit; do
    [[ "$unit" == nextpas.core.* ]] || continue
    dep="$(top_module "$unit")"
    if is_l0_source "$file" &&
       ! array_contains "$dep" "${ALLOWED_L0_TOP_MODULES[@]}" &&
       ! array_contains "$file|$unit" "${KNOWN_L0_DEPENDENCY_DEBT[@]}"; then
      printf '%s|%s\n' "$file" "$unit" >> "$tmp_l0_unknown"
    fi
  done < <(list_pascal_uses_units "$file")
done < <(find src -maxdepth 1 -type f -name 'nextpas.core.*.pas' | sort)

while IFS= read -r file; do
  file="${file#./}"
  case "$file" in
    src/nextpas.core.platform.*.pas) continue ;;
  esac
  while IFS= read -r unit; do
    unit_lc="$(printf '%s' "$unit" | tr '[:upper:]' '[:lower:]')"
    if array_contains "$unit_lc" "${RAW_HOST_UNITS[@]}" &&
       ! array_contains "$file|$unit" "${RAW_HOST_ALLOWLIST[@]}"; then
      printf '%s|%s\n' "$file" "$unit" >> "$tmp_raw_unknown"
    fi
  done < <(list_pascal_uses_units "$file")
done < <(find src -maxdepth 1 -type f -name 'nextpas.core.*.pas' | sort)

if [[ -s "$tmp_l0_unknown" ]]; then
  echo "Unexpected L0 dependency boundary violations:"
  sort -u "$tmp_l0_unknown"
  exit 1
fi

if [[ -s "$tmp_raw_unknown" ]]; then
  echo "Unexpected raw host FFI import violations:"
  sort -u "$tmp_raw_unknown"
  exit 1
fi

echo "core architecture source contracts passed"
echo "L0 known dependency debt entries allowed: ${#KNOWN_L0_DEPENDENCY_DEBT[@]}"
echo "raw host FFI allowlist entries allowed: ${#RAW_HOST_ALLOWLIST[@]}"
