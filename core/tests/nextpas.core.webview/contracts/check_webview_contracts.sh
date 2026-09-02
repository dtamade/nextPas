#!/usr/bin/env bash
# nextpas.core.webview source-contract 门禁（INV-4 + INV-5 家族内复核）— M7 has-a 收口
# 单源真相：tests/architecture/source_contracts/check_architecture_source_contracts.py --check webview
# 本脚本仅为兼容薄代理（legacy entry），不再自含 grep 扫描，避免双轨校验；hygiene/CI 均以统一门禁为准。
#
# INV-4: base 禁止 uses bridge/fake/factory/gtk/webview2/wk/window 单元；
#        intf 仅允许 uses window.intf 以暴露 IWindow/Window 组合面，仍禁止
#        bridge/fake/factory/gtk/webview2/wk/vfs/mime 等后端。
#        bridge: 禁止 uses 任何后端/factory/vfs/window 单元（依赖方向 base←intf←bridge←后端；M7 起 webview→window 为 L3→L2 has-a）。
#        生产单元（fake/gtk/webview2/wk/factory/vfs）允许 uses window.*（M6 has-a，L3→L2）。
# INV-5 复核: 家族生产单元禁 raw host units（DynLibs/ctypes/BaseUnix/
#         Windows/Unix）；动态装载真相归 platform.dl（全局架构检查器
#         已有同规则，此处做家族内快速失败）；gtk/webview2/wk 的 ffi/loader
#         仍仅经 platform.dl，不直触 DynLibs。
# ffi 预置（S3 启用）: *.ffi.pas 出现后禁止 external 声明（loader 拥有绑定）。
#
# 用法: ./check_webview_contracts.sh [core_root]   # 缺省 = 脚本位置推算

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="${1:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
PYTHON="${PYTHON:-python3}"
UNIFIED="$CORE_ROOT/core/tests/architecture/source_contracts/check_architecture_source_contracts.py"

echo "== webview source contracts (via tests/architecture/source_contracts) =="

if [[ ! -f "$UNIFIED" ]]; then
  echo "FAIL: unified gate not found: $UNIFIED"
  exit 1
fi

# 单源委托：所有 INV-4/INV-5/M7/ffi 规则由统一门禁执行，本脚本不复刻扫描逻辑
if ! "$PYTHON" "$UNIFIED" --core-root "$CORE_ROOT" --check webview --summary-line; then
  echo "webview-source-contracts=FAIL"
  exit 1
fi

echo "webview-source-contracts=pass"
