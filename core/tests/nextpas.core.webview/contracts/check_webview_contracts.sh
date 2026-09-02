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

# -- bridge.js → bridge.script.inc generated vs hand-written hygiene gate --
# Hygiene 零产物显式标注：.script.inc 为意向跟踪生成源（AUTO-GENERATED），非构建产物；
# 校验门以 JS 真值重生成 body 并与已提交 .inc body diff，确保已跟踪产物严格由单一源派生。
echo "== webview bridge.js → bridge.script.inc generation check =="
BRIDGE_JS="$CORE_ROOT/core/src/nextpas.core.webview.bridge.js"
BRIDGE_INC="$CORE_ROOT/core/src/nextpas.core.webview.bridge.script.inc"
if [[ ! -f "$BRIDGE_JS" ]]; then
  echo "FAIL: bridge JS source missing: $BRIDGE_JS"
  echo "webview-bridge-generation=FAIL"
  exit 1
fi
if [[ ! -f "$BRIDGE_INC" ]]; then
  echo "FAIL: bridge script inc missing: $BRIDGE_INC"
  echo "webview-bridge-generation=FAIL"
  exit 1
fi
if ! grep -q "AUTO-GENERATED" "$BRIDGE_INC"; then
  echo "FAIL: bridge script inc must contain AUTO-GENERATED marker (design-conventions §1 generated vs hand-written)"
  echo "webview-bridge-generation=FAIL"
  exit 1
fi
if ! grep -q "Source of truth" "$BRIDGE_INC"; then
  echo "FAIL: bridge script inc must annotate Source of truth"
  echo "webview-bridge-generation=FAIL"
  exit 1
fi
if ! "$PYTHON" - "$BRIDGE_JS" "$BRIDGE_INC" << 'PY'
import sys
js_path, inc_path = sys.argv[1], sys.argv[2]
with open(js_path, 'r', encoding='utf-8') as f:
    js_lines = f.read().splitlines()
# expected body: each JS line escaped '' and wrapped as '...' #10 (+ except last)
expected = []
for i, line in enumerate(js_lines):
    esc = line.replace("'", "''")
    if i < len(js_lines) - 1:
        expected.append(f"'{esc}'#10 +")
    else:
        expected.append(f"'{esc}'#10")
# actual body: lines in inc that start with "'" (Pascal string lines), strip whitespace
with open(inc_path, 'r', encoding='utf-8') as f:
    inc_lines = f.read().splitlines()
actual = [l.strip() for l in inc_lines if l.strip().startswith("'")]
if expected != actual:
    print("FAIL: bridge script inc body out of sync with JS source", file=sys.stderr)
    print(f"  expected {len(expected)} body lines, actual {len(actual)}", file=sys.stderr)
    # show first mismatch
    for idx, (e, a) in enumerate(zip(expected, actual)):
        if e != a:
            print(f"  mismatch at js line {idx+1}:", file=sys.stderr)
            print(f"    expected: {e!r}", file=sys.stderr)
            print(f"    actual  : {a!r}", file=sys.stderr)
            break
    if len(expected) != len(actual):
        print(f"  length mismatch expected={len(expected)} actual={len(actual)}", file=sys.stderr)
        extra = expected[len(actual):] if len(expected) > len(actual) else actual[len(expected):]
        for line in extra[:3]:
            print(f"    extra: {line!r}", file=sys.stderr)
    sys.exit(1)
print("bridge generation body matches JS source")
PY
then
  echo "webview-bridge-generation=FAIL"
  exit 1
fi
echo "webview-bridge-generation=pass"
