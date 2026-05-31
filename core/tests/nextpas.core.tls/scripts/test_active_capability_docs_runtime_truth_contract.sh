#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
migration_doc="${MIGRATION_GUIDE_V11_DOC:-$root_dir/docs/MIGRATION_GUIDE_V1.1.md}"
selection_doc="$root_dir/docs/BACKEND_SELECTION_GUIDE.md"
capability_guide="$root_dir/docs/CAPABILITY_MATRIX_GUIDE.md"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_present() {
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

require_absent "$migration_doc" "| **PKCS#11**  | ✅        | ⚠️        | ⚠️        | ✅          |" \
  "Migration guide still advertises the stale PKCS#11 capability table"
require_absent "$migration_doc" "| **TPM**      | ❌        | ❌        | ❌        | ✅          |" \
  "Migration guide still advertises WinSSL TPM capability as published truth"
require_absent "$migration_doc" "| **FIPS**     | ✅        | ❌        | ❌        | ✅          |" \
  "Migration guide still advertises OpenSSL default-build FIPS capability as published truth"

require_present "$migration_doc" "| **PKCS#11**  | ⚠️ 依赖运行时 | ❌        | ❌        | ❌          |" \
  "Migration guide no longer records runtime-aware PKCS#11 truth"
require_present "$migration_doc" "| **TPM**      | ❌        | ❌        | ❌        | ❌          |" \
  "Migration guide no longer records that TPM capability is currently unpublished across active backends"
require_present "$migration_doc" "| **FIPS**     | ❌        | ❌        | ❌        | ❌          |" \
  "Migration guide no longer records that FIPS capability is currently unpublished across active backends"
require_present "$migration_doc" "OpenSSL 的 PKCS#11 capability 取决于 Provider / ENGINE runtime surface readiness；默认构建也不发布 FIPS capability。" \
  "Migration guide no longer records the runtime-aware OpenSSL PKCS#11/FIPS note"
require_present "$migration_doc" 'WinSSL 的 `nextpas.core.tls.winssl.enterprise` 当前只提供系统 FIPS policy/helper 检测，不等于已发布 `SupportsFIPSMode=True` capability。' \
  "Migration guide no longer records the WinSSL FIPS helper-vs-capability boundary"
require_present "$migration_doc" "WriteLn('Selected backend: ', LibraryTypeToString(Result)," \
  "Migration guide must use the public LibraryTypeToString helper for facade-only backend-name output"
require_absent "$migration_doc" "SSL_LIBRARY_NAMES[" \
  "Migration guide must stop teaching base-only SSL_LIBRARY_NAMES in facade-only capability examples"

require_absent "$selection_doc" "- SupportsPKCS11: Yes" \
  "Backend selection guide still presents OpenSSL PKCS#11 as unconditional truth"
require_present "$selection_doc" "- SupportsPKCS11: Runtime-dependent (requires Provider / ENGINE readiness)" \
  "Backend selection guide no longer records runtime-aware OpenSSL PKCS#11 truth"
require_present "$selection_doc" "平台分数 5.5/10 假设当前 OpenSSL runtime 已发布 PKCS#11 capability；若 Provider / ENGINE surface 不就绪，该项会更低。" \
  "Backend selection guide no longer bounds the PKCS#11-dependent scoring example"

require_absent "$capability_guide" "if Caps.SupportsSystemCertStore and Caps.SupportsTPM then" \
  "Capability matrix guide still uses stale WinSSL TPM recommendation logic"
require_absent "$capability_guide" "Recommended for Windows: full system integration" \
  "Capability matrix guide still uses stale full-system-integration wording tied to TPM"
require_present "$capability_guide" "if Caps.SupportsSystemCertStore then" \
  "Capability matrix guide no longer records the current Windows system-cert recommendation gate"
require_present "$capability_guide" "WriteLn('Recommended for Windows: system certificate integration available');" \
  "Capability matrix guide no longer records the current Windows recommendation wording"

echo "[PASS] active capability docs remain aligned with current runtime-aware truth"
