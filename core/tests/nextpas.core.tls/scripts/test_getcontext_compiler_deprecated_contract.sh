#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"

cd "$PROJECT_ROOT"

base_file="core/src/nextpas.core.tls.base.pas"
message="Use ISSLConnectionInfo.GetContext"

count=$(perl -0ne "
  my \$n = () = /function GetContext\\: ISSLContext;\\s*deprecated '\\Q$message\\E';/g;
  print \$n;
" "$base_file")

if [[ "$count" != "1" ]]; then
  echo "[FAIL] expected exactly one compiler-deprecated core GetContext declaration in $base_file"
  echo "       matched declarations: $count"
  exit 1
fi




echo "[PASS] GetContext compiler deprecation is aligned across source, docs, and residual mirror proof"
