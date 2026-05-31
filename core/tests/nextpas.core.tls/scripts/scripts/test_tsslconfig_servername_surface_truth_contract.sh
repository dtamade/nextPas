#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="src/nextpas.core.tls.base.pas"
factory_file="src/nextpas.core.tls.factory.pas"
openssl_file="src/nextpas.core.tls.openssl.backed.pas"
api_ref="docs/reference/API_REFERENCE.md"

if ! rg -n --quiet \
  "ServerName: string;[[:space:]]+// Deprecated compatibility-only context-level SNI; prefer ISSLClientConnection.SetServerName" \
  "$base_file"; then
  echo "[FAIL] TSSLConfig.ServerName source comment no longer states compatibility-only per-connection guidance"
  exit 1
fi

if ! rg -n --quiet "received TSSLConfig\\.ServerName as deprecated context-level SNI compatibility" "$factory_file"; then
  echo "[FAIL] factory no longer names TSSLConfig.ServerName as deprecated context-level SNI compatibility"
  exit 1
fi

if ! rg -n --quiet "ISSLClientConnection\\.SetServerName or TSSLConnector\\.Connect\\*\\(\\.\\.\\., ServerName\\)" "$factory_file"; then
  echo "[FAIL] factory warning no longer points callers to the per-connection SNI path"
  exit 1
fi

if ! rg -n --quiet "TOpenSSLLibrary\\.CreateContext received TSSLConfig\\.ServerName as deprecated context-level" "$openssl_file"; then
  echo "[FAIL] OpenSSL direct-library path no longer names TSSLConfig.ServerName in its compatibility warning"
  exit 1
fi

if ! rg -F -n --quiet '`TSSLConfig.ServerName` 仍然保留为向后兼容入口' "$api_ref"; then
  echo "[FAIL] API reference no longer states that TSSLConfig.ServerName is a compatibility-only entry"
  exit 1
fi

if ! rg -F -n --quiet '`TSSLFactory.CreateContext(...)` 现在也不再把这个字段写进新建 context；若传入 `TSSLConfig.ServerName`，factory 会发出 warning 并忽略它。' "$api_ref"; then
  echo "[FAIL] API reference no longer records the factory warning+ignore truth for TSSLConfig.ServerName"
  exit 1
fi

mapfile -t active_doc_hits < <(
  rg -l "TSSLConfig\\.ServerName" docs/guides docs/reference docs/ARCHITECTURE.md || true
)

for file in "${active_doc_hits[@]}"; do
  if [[ "$file" != "$api_ref" ]]; then
    echo "[FAIL] active doc unexpectedly teaches TSSLConfig.ServerName outside API reference: $file"
    rg -n "TSSLConfig\\.ServerName" "$file" || true
    exit 1
  fi
done

echo "[PASS] TSSLConfig.ServerName source/doc truth stays frozen as a compatibility-only surface"
