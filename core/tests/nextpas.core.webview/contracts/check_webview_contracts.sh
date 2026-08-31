#!/usr/bin/env bash
# nextpas.core.webview source-contract 门禁（INV-4 + INV-5 家族内复核）— M7 has-a 收口
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
SRC="$CORE_ROOT/src"

fail=0

echo "== webview source contracts =="

# --- INV-4: 契约层纯净性（M7 has-a） ---
# base 仍禁 window；intf 仅允 window.intf
for unit in nextpas.core.webview.base.pas nextpas.core.webview.intf.pas; do
  path="$SRC/$unit"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: missing contract unit $unit"
    fail=1
    continue
  fi
  for token in bridge fake factory gtk webview2 wk vfs mime; do
    hits="$(grep -Ec "nextpas\.core\.webview\.${token}\b" "$path" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: $unit references nextpas.core.webview.$token (INV-4), $hits hit(s)"
      fail=1
    fi
  done
  # window 隔离：base 禁 window.*；intf 仅允 window.intf 单点
  if [[ "$unit" == "nextpas.core.webview.base.pas" ]]; then
    hits="$(grep -Ec "nextpas\.core\.window\." "$path" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: $unit references nextpas.core.window.* (INV-4 M7), $hits hit(s)"
      fail=1
    fi
  else
    # intf：允许 window.intf，禁止其他 window 子单元
    hits="$(grep -Ec "nextpas\.core\.window\.(?!intf\b)" "$path" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: $unit references non-intf window subunit (INV-4 M7), $hits hit(s)"
      fail=1
    fi
  fi
done

# --- 门面存在性 ---
if [[ ! -f "$SRC/nextpas.core.webview.pas" ]]; then
  echo "FAIL: missing facade nextpas.core.webview.pas"
  fail=1
fi

# --- bridge 依赖方向（BRIDGE_PROTOCOL/CONTRACT §1；M7 has-a）：
#     bridge 禁止 uses 任何后端/factory/vfs/window 单元——它只认识 intf 的契约。
if [[ -f "$SRC/nextpas.core.webview.bridge.pas" ]]; then
  for token in fake factory gtk webview2 wk vfs; do
    hits="$(grep -Ec "nextpas\.core\.webview\.${token}\b" \
      "$SRC/nextpas.core.webview.bridge.pas" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: bridge references nextpas.core.webview.$token, $hits hit(s)"
      fail=1
    fi
  done
  hits="$(grep -Ec "nextpas\.core\.window\." "$SRC/nextpas.core.webview.bridge.pas" || true)"
  if [[ "$hits" -ne 0 ]]; then
    echo "FAIL: bridge references nextpas.core.window.* (INV-3 M7 bridge must stay pure), $hits hit(s)"
    fail=1
  fi
fi

# --- M7 has-a：生产单元允许 uses window.*（L3→L2），ffi/loader 仍仅经 platform.dl ---
# 校验：gtk/webview2/wk 的 ffi/loader 不直触 window.*（仅后端实现与 factory 可 has-a）
for ff in "$SRC"/nextpas.core.webview.*.ffi.pas "$SRC"/nextpas.core.webview.*.loader.pas; do
  [[ -e "$ff" ]] || continue
  if grep -Eq "nextpas\.core\.window\." "$ff"; then
    echo "FAIL: $(basename "$ff") references nextpas.core.window.* — ffi/loader must stay platform.dl only (M7)"
    fail=1
  fi
done

# --- INV-5 家族内复核：raw host units 缺席（先剥注释再扫描） ---
strip_comments() {
  # 剥离 {..} 块注释与 // 行注释；(*..*) 一并处理
  perl -0777 -pe 's/\{.*?\}//gs; s/\(\*.*?\*\)//gs; s{//[^\n]*}{}g' "$1"
}

for token in DynLibs ctypes BaseUnix Windows Unix; do
  for f in "$SRC"/nextpas.core.webview*.pas; do
    [[ -e "$f" ]] || continue
    # win 壳（gtk.win / webview2.win）是窗口真相的 FFI 宿主，允许直接 Windows/Win32 API
    if [[ "$token" == "Windows" && "$(basename "$f")" == *".win.pas" ]]; then
      continue
    fi
    hits="$(strip_comments "$f" | grep -Ec "\b${token}\b" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: raw host unit token '$token' in $(basename "$f") (INV-5), $hits hit(s)"
      fail=1
    fi
  done
done

# --- *.ffi 规则预置 ---
for ff in "$SRC"/nextpas.core.webview.*.ffi.pas; do
  [[ -e "$ff" ]] || continue
  if strip_comments "$ff" | grep -Eq "^[[:space:]]*external\b"; then
    echo "FAIL: ffi unit $(basename "$ff") contains external declaration (loader owns binding)"
    fail=1
  fi
done

if [[ "$fail" -eq 0 ]]; then
  echo "webview-source-contracts=pass"
else
  echo "webview-source-contracts=FAIL"
  exit 1
fi
