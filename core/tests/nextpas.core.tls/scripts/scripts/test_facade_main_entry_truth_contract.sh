#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

readme_file="docs/README.md"
facade_file="src/nextpas.core.tls.pas"
factory_file="src/nextpas.core.tls.factory.pas"
integration_file="docs/INTEGRATION_GUIDE.md"

for file in "$readme_file" "$facade_file" "$factory_file" "$integration_file"; do
  if rg -n --quiet '\bsslClient\b|\bsslServer\b' "$file"; then
    echo "[FAIL] stale context enum names remain in $file"
    exit 1
  fi
done

if ! rg -F -n --quiet 'TSSLConnector.FromContext(Ctx)' "$readme_file"; then
  echo "[FAIL] docs/README.md no longer shows the recommended connector entry"
  exit 1
fi

if ! rg -F -n --quiet "ClientConn.SetServerName('example.com')" "$readme_file"; then
  echo "[FAIL] docs/README.md no longer shows per-connection SNI on the direct path"
  exit 1
fi

if rg -F -n --quiet 'uses nextpas.core.tls.factory, nextpas.core.tls.base;' "$readme_file"; then
  echo "[FAIL] docs/README.md still teaches the old split-unit main entry"
  exit 1
fi

if ! rg -F -n --quiet 'TSSLConnector.FromContext(LContext)' "$facade_file"; then
  echo "[FAIL] src/nextpas.core.tls.pas header example no longer shows the facade connector path"
  exit 1
fi

if ! rg -F -n --quiet 'TSSLContextBuilder' "$facade_file"; then
  echo "[FAIL] src/nextpas.core.tls.pas must mention TSSLContextBuilder as the ordinary entrypoint"
  exit 1
fi

if ! rg -F -n --quiet 'nextpas.core.tls.context.builder' "$facade_file"; then
  echo "[FAIL] src/nextpas.core.tls.pas must reference nextpas.core.tls.context.builder as the ordinary builder unit"
  exit 1
fi

if ! rg -F -n --quiet 'BuildClient' "$facade_file"; then
  echo "[FAIL] src/nextpas.core.tls.pas header example must show BuildClient as the ordinary builder call"
  exit 1
fi

if ! rg -F -n --quiet 'TSSLFactory.CreateContext(sslCtxClient' "$factory_file"; then
  echo "[FAIL] src/nextpas.core.tls.factory.pas examples no longer use sslCtxClient truth"
  exit 1
fi

if ! rg -F -n --quiet 'sslCtxServer' "$factory_file"; then
  echo "[FAIL] src/nextpas.core.tls.factory.pas examples/params no longer mention sslCtxServer truth"
  exit 1
fi

echo "[PASS] facade/main-entry truth is aligned across README, facade header, factory comments, and integration guide"
