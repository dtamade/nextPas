#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

fail() {
  echo "[FAIL] $*"
  exit 1
}

pass() {
  echo "[PASS] $*"
}

echo "[TEST] active root entry metadata and install guidance truth contract"

for stale_lpi in examples/test_winssl.lpi examples/test_openssl.lpi; do
  if [[ -e "$stale_lpi" ]]; then
    fail "stale root example project must be retired: $stale_lpi"
  fi
done
pass "stale root example lpi metadata retired"

if ! rg -n --quiet 'fafafa\.ssl\.pas\s+# 主门面 / 当前普通入口' README.md; then
  fail "README architecture entry must publish nextpas.core.tls.pas as the ordinary public entry"
fi

if ! rg -n --quiet 'fafafa\.ssl\.context\.builder\.pas\s+# 推荐 context builder 入口' README.md; then
  fail "README architecture entry must publish nextpas.core.tls.context.builder.pas as the recommended builder entry"
fi

if rg -n --quiet 'fafafa\.ssl\.factory\.pas\s+# 工厂模式入口' README.md; then
  fail "README must not keep publishing nextpas.core.tls.factory.pas as the primary entry"
fi
pass "README root entry guidance aligned"

if rg -n --quiet 'fafafa\.ssl,\s*fafafa\.ssl\.base' docs/zh/安装配置.md; then
  fail "zh install guide must not require split import fafafa.ssl + nextpas.core.tls.base for ordinary setup"
fi

if ! rg -n --quiet '^\s*fafafa\.ssl;\s*$' docs/zh/安装配置.md; then
  fail "zh install guide must show fafafa.ssl as the ordinary public import"
fi
pass "zh install guide ordinary import aligned"

if rg -n --quiet 'fafafa\.ssl\.base;\s*// 或直接使用 base 单元' docs/zh/编译指南.md; then
  fail "zh compile guide must not recommend nextpas.core.tls.base as the default companion import"
fi

if ! rg -n --quiet '^\s*fafafa\.ssl;\s*// 包含 ProtocolVersionToString' docs/zh/编译指南.md; then
  fail "zh compile guide must show fafafa.ssl as the source of ProtocolVersionToString"
fi
pass "zh compile guide ordinary import aligned"

echo "[PASS] active root entry metadata and install guidance truth contract passed"
