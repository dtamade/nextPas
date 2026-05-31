#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

TARGET="src/nextpas.core.tls.context.builder.pas"
MESSAGE="Use per-connection hostname via TSSLConnectionBuilder.WithHostname or ISSLClientConnection.SetServerName"

count=$(perl -0ne "
  my \$n = () = /function WithSNI\\(const AServerName: string\\): ISSLContextBuilder;\\s*deprecated '\\Q$MESSAGE\\E';/g;
  print \$n;
" "$TARGET")

if [[ "$count" != "2" ]]; then
  echo "[FAIL] expected both public WithSNI declarations to be compiler-deprecated in $TARGET"
  echo "       matched declarations: $count"
  exit 1
fi

echo "[PASS] WithSNI declarations are compiler-deprecated in source"
