#!/usr/bin/env bash
set -euo pipefail

# 2026-08-23 布局修复：契约以仓库根相对路径取文件
cd "$(dirname "$0")/../../../.."

check_backend() {
  local file="$1"

  if rg -n --quiet 'FLogCallback := LConfig\.LogCallback;' "$file"; then
    echo "[FAIL] $file still lets SetDefaultConfig install the runtime log callback"
    exit 1
  fi

  if ! rg -n --quiet 'FLogCallback := ACallback;' "$file"; then
    echo "[FAIL] $file no longer updates the runtime callback through SetLogCallback"
    exit 1
  fi

  if ! rg -n --quiet 'FDefaultConfig\.LogCallback := ACallback;' "$file"; then
    echo "[FAIL] $file no longer mirrors SetLogCallback into GetDefaultConfig truth"
    exit 1
  fi
}

check_backend "core/src/nextpas.core.tls.openssl.backed.pas"
check_backend "core/src/nextpas.core.tls.freepascal.lib.pas"
check_backend "core/src/nextpas.core.tls.winssl.lib.pas"
check_backend "core/src/nextpas.core.tls.mbedtls.lib.pas"
check_backend "core/src/nextpas.core.tls.wolfssl.lib.pas"

echo "[PASS] library-default log callback detachment remains aligned across backend library paths"
