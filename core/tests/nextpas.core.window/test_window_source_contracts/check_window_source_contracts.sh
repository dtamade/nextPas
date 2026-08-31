#!/usr/bin/env bash
# nextpas.core.window source-contract 门禁（INV-3/4/5 家族内复核）
#
# INV-3: base/intf 禁止 uses 任何 window.<backend>*、window.fake、window.factory
# INV-4: 生产单元（非 loader）禁止出现 raw host units（DynLibs/Windows/BaseUnix/Unix/ctypes/X/CocoaAll）
# INV-5: *.ffi 无逻辑无 external（S1 无 ffi 单元，但预置检查）
# 额外：门面存在性、动态装载原语归属（window 家族暂无 loader，预置）
#
# 用法: ./check_window_source_contracts.sh [core_root]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORE_ROOT="${1:-$(cd "$SCRIPT_DIR/../../../.." && pwd)}"
SRC="$CORE_ROOT/src"

fail=0

echo "== window source contracts =="

# --- INV-3: 契约层纯净性 ---
for unit in nextpas.core.window.base.pas nextpas.core.window.intf.pas; do
  path="$SRC/$unit"
  if [[ ! -f "$path" ]]; then
    echo "FAIL: missing contract unit $unit"
    fail=1
    continue
  fi
  for token in fake factory gtk sdl2 win32 cocoa android uikit wasm; do
    hits="$(grep -Ec "nextpas\.core\.window\.${token}\b" "$path" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: $unit references nextpas.core.window.$token (INV-3), $hits hit(s)"
      fail=1
    fi
  done
  # also forbid direct backend qualifiers like window.gtk.ffi
  for token in "window\.gtk" "window\.sdl2" "window\.win32" "window\.cocoa" "window\.android" "window\.uikit" "window\.wasm"; do
    hits="$(grep -Ec "nextpas\.core\.${token}\b" "$path" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: $unit references nextpas.core.$token (INV-3), $hits hit(s)"
      fail=1
    fi
  done
done

# --- 门面存在性 ---
if [[ ! -f "$SRC/nextpas.core.window.pas" ]]; then
  echo "FAIL: missing facade nextpas.core.window.pas"
  fail=1
fi
if [[ ! -f "$SRC/nextpas.core.window.fake.pas" ]]; then
  echo "FAIL: missing fake unit nextpas.core.window.fake.pas"
  fail=1
fi
if [[ ! -f "$SRC/nextpas.core.window.factory.pas" ]]; then
  echo "FAIL: missing factory unit nextpas.core.window.factory.pas"
  fail=1
fi

# --- INV-6: legacy window.gtk shim freeze (4.0) — 禁止新 uses window.gtk 裸名 ---
for f in "$SRC"/nextpas.core.window*.pas; do
  [[ -e "$f" ]] || continue
  bn="$(basename "$f")"
  if [[ "$bn" == "nextpas.core.window.gtk.pas" || "$bn" == "nextpas.core.window.gtk.ffi.pas" || "$bn" == "nextpas.core.window.gtk.loader.pas" ]]; then
    continue
  fi
  hits="$(strip_comments "$f" | grep -Ec "nextpas\.core\.window\.gtk\b" || true)"
  if [[ "$hits" -ne 0 ]]; then
    echo "FAIL: legacy shim 'window.gtk' used in $bn (INV-6, use window.gtk3), $hits hit(s)"
    fail=1
  fi
done
if [[ ! -f "$SRC/nextpas.core.window.pas" ]]; then
  echo "FAIL: missing facade nextpas.core.window.pas"
  fail=1
fi
if [[ ! -f "$SRC/nextpas.core.window.fake.pas" ]]; then
  echo "FAIL: missing fake unit nextpas.core.window.fake.pas"
  fail=1
fi
if [[ ! -f "$SRC/nextpas.core.window.factory.pas" ]]; then
  echo "FAIL: missing factory unit nextpas.core.window.factory.pas"
  fail=1
fi

# --- INV-4 家族内复核：raw host units 缺席（先剥注释再扫描） ---
strip_comments() {
  perl -0777 -pe 's/\{.*?\}//gs; s/\(\*.*?\*\)//gs; s{//[^\n]*}{}g' "$1"
}

for token in DynLibs ctypes BaseUnix Windows Unix; do
  for f in "$SRC"/nextpas.core.window*.pas; do
    [[ -e "$f" ]] || continue
    # loader 是唯一允许触 platform.dl 的单元；S1 暂无 loader，全部视为生产单元
    # 因此一律禁止 raw host units
    hits="$(strip_comments "$f" | grep -Ec "\b${token}\b" || true)"
    if [[ "$hits" -ne 0 ]]; then
      echo "FAIL: raw host unit token '$token' in $(basename "$f") (INV-4), $hits hit(s)"
      fail=1
    fi
  done
done

# --- INV-5: *.ffi 无逻辑无 external ---
for ff in "$SRC"/nextpas.core.window.*.ffi.pas; do
  [[ -e "$ff" ]] || continue
  if strip_comments "$ff" | grep -Eq "^[[:space:]]*external\b"; then
    echo "FAIL: ffi unit $(basename "$ff") contains external declaration (INV-5, loader owns binding)"
    fail=1
  fi
  # extra: ffi should not contain implementation logic beyond type/var
  # we only enforce external here; fuller check deferred to S2
done

# --- *.loader 唯一触 platform.dl 的预置检查（S1 暂无 loader，验证不触 DynLibs） ---
for lf in "$SRC"/nextpas.core.window.*.loader.pas; do
  [[ -e "$lf" ]] || continue
  if strip_comments "$lf" | grep -Eq "\bDynLibs\b"; then
    echo "FAIL: loader unit $(basename "$lf") uses DynLibs (must use platform.dl)"
    fail=1
  fi
done

# Ensure no window unit uses DynLibs via raw token already covered; also verify platform.dl not misused in base/intf
for unit in nextpas.core.window.base.pas nextpas.core.window.intf.pas; do
  path="$SRC/$unit"
  [[ -f "$path" ]] || continue
  hits="$(strip_comments "$path" | grep -Ec "platform\.dl" || true)"
  if [[ "$hits" -ne 0 ]]; then
    echo "FAIL: $unit references platform.dl (base/intf must not touch loader)"
    fail=1
  fi
done

if [[ "$fail" -eq 0 ]]; then
  echo "window-source-contracts=pass"
else
  echo "window-source-contracts=FAIL"
  exit 1
fi
