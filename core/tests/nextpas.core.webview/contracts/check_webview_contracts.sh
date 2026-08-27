#!/usr/bin/env bash
# nextpas.core.webview source-contract 门禁（INV-4 + INV-5 家族内复核）
#
# INV-4: base/intf 禁止 uses bridge/fake/factory/gtk/webview2/wk 单元。
# bridge: 禁止 uses 任何后端/factory 单元（依赖方向 base←intf←bridge←后端）。
# INV-5 复核: 家族生产单元禁 raw host units（DynLibs/ctypes/BaseUnix/
#         Windows/Unix）；动态装载真相归 platform.dl（全局架构检查器
#         已有同规则，此处做家族内快速失败）。
# ffi 预置（S3 启用）: *.ffi.pas 出现后禁止 external 声明（loader 拥有绑定）。
#
# 用法: ./check_webview_contracts.sh [core_root]   # 缺省 = 脚本位置推算

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="${1:-$(cd "$SCRIPT_DIR/../../.." && pwd)}"
SRC="$CORE_ROOT/src"

fail=0

echo "== webview source contracts =="

# --- INV-4: 契约层纯净性 ---
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
done

# --- 门面存在性 ---
if [[ ! -f "$SRC/nextpas.core.webview.pas" ]]; then
  echo "FAIL: missing facade nextpas.core.webview.pas"
  fail=1
fi

# --- bridge 依赖方向（BRIDGE_PROTOCOL/CONTRACT §1）：
#     bridge 禁止 uses 任何后端/factory/vfs 单元——它只认识 intf 的契约。
if [[ -f "$SRC/nextpas.core.webview.bridge.pas" ]]; then
  for token in fake factory gtk webview2 wk vfs; do
    hits="$(grep -Ec "nextpas\.core\.webview\.${token}\b" \
      "$SRC/nextpas.core.webview.bridge.pas" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: bridge references nextpas.core.webview.$token, $hits hit(s)"
      fail=1
    fi
  done
fi

# --- INV-5 家族内复核：raw host units 缺席（先剥注释再扫描） ---
strip_comments() {
  # 剥离 {..} 块注释与 // 行注释；(*..*) 一并处理
  perl -0777 -pe 's/\{.*?\}//gs; s/\(\*.*?\*\)//gs; s{//[^\n]*}{}g' "$1"
}

for token in DynLibs ctypes BaseUnix Windows Unix; do
  for f in "$SRC"/nextpas.core.webview*.pas; do
    [[ -e "$f" ]] || continue
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
