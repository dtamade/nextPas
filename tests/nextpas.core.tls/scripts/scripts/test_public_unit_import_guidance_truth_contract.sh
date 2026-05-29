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

user_guide="docs/guides/USER_GUIDE.md"
integration_guide="docs/INTEGRATION_GUIDE.md"
faq_guide="docs/guides/FAQ.md"
architecture_doc="docs/ARCHITECTURE.md"
reference_architecture="docs/reference/ARCHITECTURE.md"
migration_v11="docs/MIGRATION_GUIDE_V1.1.md"
winssl_quickstart="docs/guides/WINSSL_QUICKSTART.md"
winssl_guide="docs/guides/WINSSL_USER_GUIDE.md"
mbedtls_guide="docs/guides/MBEDTLS_USER_GUIDE.md"
troubleshooting="docs/guides/TROUBLESHOOTING.md"
api_reference="docs/reference/API_REFERENCE.md"
docs_readme="docs/README.md"

echo "[TEST] public unit/import guidance truth contract"

# docs/README.md quick-start must teach builder as the ordinary entrypoint
require_fixed "$docs_readme" "nextpas.core.tls.context.builder" \
  "docs/README.md quick-start must import nextpas.core.tls.context.builder"
require_fixed "$docs_readme" "TSSLContextBuilder" \
  "docs/README.md quick-start must use TSSLContextBuilder"
require_absent "$docs_readme" 'Ctx := TSSLFactory.CreateContext(sslCtxClient);' \
  "docs/README.md quick-start must not teach factory-direct as the primary context creation"

require_fixed "$user_guide" "SysUtils, fafafa.ssl;" \
  "USER_GUIDE must use the current public facade unit in active examples"
require_fixed "$user_guide" "LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);" \
  "USER_GUIDE must use TSSLFactory.GetLibraryInstance for OpenSSL-focused examples"

require_fixed "$integration_guide" "nextpas.core.tls.context.builder;" \
  "INTEGRATION_GUIDE must keep the current builder unit in hook/client setup examples"
require_fixed "$integration_guide" "  fafafa.ssl;" \
  "INTEGRATION_GUIDE must use the current public facade unit in active examples"

require_fixed "$faq_guide" '普通新代码推荐直接 `uses fafafa.ssl, nextpas.core.tls.context.builder;`，然后通过 `TSSLContextBuilder` / `TSSLConnector` 建立 TLS；只有在你明确固定某个 backend 时，才需要关心 backend-specific 依赖。' \
  "FAQ must state the current facade-plus-builder import truth"
require_fixed "$architecture_doc" '普通新代码优先使用 `uses fafafa.ssl, nextpas.core.tls.context.builder;`，然后通过 `TSSLContextBuilder` / `TSSLConnector` 建立 TLS' \
  "ARCHITECTURE must state the current facade-plus-builder import truth"
require_fixed "$reference_architecture" '普通新代码优先使用 `uses fafafa.ssl, nextpas.core.tls.context.builder;`，然后通过 `TSSLContextBuilder` / `TSSLConnector` 建立 TLS' \
  "reference ARCHITECTURE must state the current facade-plus-builder import truth"
require_fixed "$migration_v11" '普通新代码优先使用 `uses fafafa.ssl, nextpas.core.tls.context.builder;`，然后通过 `TSSLContextBuilder` / `TSSLConnector` 建立 TLS' \
  "MIGRATION_GUIDE_V1.1 must state the current facade-plus-builder import truth"

require_fixed "$winssl_quickstart" "fafafa.ssl;" \
  "WINSSL_QUICKSTART must use the current public facade unit"
require_fixed "$winssl_quickstart" "Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);" \
  "WINSSL_QUICKSTART must use the current WinSSL library entrypoint"
require_fixed "$winssl_quickstart" "Ctx := Lib.CreateContext(sslCtxClient);" \
  "WINSSL_QUICKSTART must use the current context enum name"
require_fixed "$winssl_quickstart" "WriteLn('Using backend: ', LibraryTypeToString(LLib.GetLibraryType));" \
  "WINSSL_QUICKSTART must use current library-type reporting instead of stale GetLibraryName"

require_fixed "$winssl_guide" "fafafa.ssl;" \
  "WINSSL_USER_GUIDE must use the current public facade unit in examples"
require_fixed "$winssl_guide" "Lib := TSSLFactory.GetLibraryInstance(sslWinSSL);" \
  "WINSSL_USER_GUIDE must use the current WinSSL library entrypoint"

require_fixed "$mbedtls_guide" "Lib := TSSLFactory.GetLibraryInstance(sslMbedTLS);" \
  "MBEDTLS_USER_GUIDE must use the current MbedTLS library entrypoint"
require_fixed "$mbedtls_guide" "fafafa.ssl;" \
  "MBEDTLS_USER_GUIDE must use the current public facade unit"

require_fixed "$troubleshooting" "if not TSSLFactory.IsLibraryAvailable(sslOpenSSL) then" \
  "TROUBLESHOOTING must use current factory availability checks instead of manual OpenSSL loader guidance"
require_fixed "$troubleshooting" "LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);" \
  "TROUBLESHOOTING must use current OpenSSL library entrypoint"

require_fixed "$api_reference" "TSSLFactory.GetLibraryInstance(ALibType: TSSLLibraryType = sslAutoDetect): ISSLLibrary;" \
  "API_REFERENCE must publish the current public library-entrypoint truth"
require_fixed "$api_reference" "backend-specific low-level creators" \
  "API_REFERENCE must classify backend-specific creators as low-level entrypoints"
require_fixed "$api_reference" "LLib := TSSLFactory.GetLibraryInstance(sslOpenSSL);" \
  "API_REFERENCE examples must use the current public library-entrypoint truth"
require_fixed "$api_reference" "SysUtils, fafafa.ssl;" \
  "API_REFERENCE capability examples must use the current public facade unit"
require_fixed "$api_reference" "WriteLn('Backend not available: ', LibraryTypeToString(ABackend));" \
  "API_REFERENCE capability examples must use the public LibraryTypeToString helper for backend names"
require_fixed "$api_reference" "WriteLn('Backend: ', LibraryTypeToString(Caps.BackendType));" \
  "API_REFERENCE capability examples must use the public LibraryTypeToString helper for capability backend names"

for file in \
  "$integration_guide" \
  "$user_guide" \
  "$winssl_quickstart" \
  "$winssl_guide" \
  "$mbedtls_guide" \
  "$troubleshooting" \
  "$api_reference"; do
  require_absent "$file" "nextpas.core.tls.abstract.intf" \
    "$file must stop using removed abstract.intf"
  require_absent "$file" "nextpas.core.tls.abstract.types" \
    "$file must stop using removed abstract.types"
done

require_absent "$integration_guide" "nextpas.core.tls.base," \
  "INTEGRATION_GUIDE must stop teaching direct base-unit imports in active examples"
require_absent "$integration_guide" "nextpas.core.tls.tls;" \
  "INTEGRATION_GUIDE must stop teaching direct tls-unit imports in active examples"
for file in \
  "$faq_guide" \
  "$architecture_doc" \
  "$reference_architecture" \
  "$migration_v11"; do
  require_absent "$file" '`uses fafafa.ssl;` + `TSSLContextBuilder` / `TSSLConnector`' \
    "$file must stop implying TSSLContextBuilder comes from the main facade alone"
done
require_absent "$user_guide" "nextpas.core.tls.openssl" \
  "USER_GUIDE must stop teaching nonexistent nextpas.core.tls.openssl facade unit"
require_absent "$troubleshooting" "nextpas.core.tls.openssl;" \
  "TROUBLESHOOTING must stop recommending nonexistent nextpas.core.tls.openssl facade unit"
require_absent "$api_reference" "nextpas.core.tls.openssl," \
  "API_REFERENCE examples must stop using nonexistent nextpas.core.tls.openssl facade unit"
require_absent "$api_reference" "SysUtils, nextpas.core.tls.base, nextpas.core.tls.factory;" \
  "API_REFERENCE capability examples must stop teaching split base/factory imports"
require_absent "$api_reference" "SSL_LIBRARY_NAMES[" \
  "API_REFERENCE capability examples must stop teaching base-only SSL_LIBRARY_NAMES in facade-only examples"

for file in \
  "$integration_guide" \
  "$winssl_quickstart" \
  "$winssl_guide" \
  "$mbedtls_guide" \
  "$api_reference"; do
  require_absent "$file" "CreateSSLLibrary(" \
    "$file must stop teaching nonexistent CreateSSLLibrary(...)"
done

for file in \
  "$winssl_quickstart" \
  "$winssl_guide"; do
  require_absent "$file" "sslLibraryWinSSL" \
    "$file must stop using stale sslLibraryWinSSL enum name"
  require_absent "$file" "sslLibraryOpenSSL" \
    "$file must stop using stale sslLibraryOpenSSL enum name"
  require_absent "$file" "sslLibraryAutoDetect" \
    "$file must stop using stale sslLibraryAutoDetect enum name"
done

require_absent "$winssl_quickstart" "sslContextClient" \
  "WINSSL_QUICKSTART must stop using stale sslContextClient enum name"
require_absent "$winssl_quickstart" "GetLibraryName" \
  "WINSSL_QUICKSTART must stop using nonexistent GetLibraryName"

for file in \
  "$troubleshooting" \
  "$api_reference"; do
  require_absent "$file" "LoadOpenSSL" \
    "$file must stop teaching manual LoadOpenSSL as a high-entry public step"
done

echo "[PASS] public unit/import guidance truth contract passed"
