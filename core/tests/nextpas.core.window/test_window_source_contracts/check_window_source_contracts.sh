#!/usr/bin/env bash
# nextpas.core.window source-contract 门禁（INV-3/4/5 家族内复核）

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

# --- INV-4 家族内复核：raw host units 缺席 ---
strip_comments() {
  perl -0777 -pe 's/\{.*?\}//gs; s/\(\*.*?\*\)//gs; s{//[^\n]*}{}g' "$1"
}

for token in DynLibs ctypes BaseUnix Windows Unix; do
  for f in "$SRC"/nextpas.core.window*.pas; do
    [[ -e "$f" ]] || continue
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
done

# --- *.loader 唯一触 platform.dl ---
for lf in "$SRC"/nextpas.core.window.*.loader.pas; do
  [[ -e "$lf" ]] || continue
  if strip_comments "$lf" | grep -Eq "\bDynLibs\b"; then
    echo "FAIL: loader unit $(basename "$lf") uses DynLibs (must use platform.dl)"
    fail=1
  fi
done

for unit in nextpas.core.window.base.pas nextpas.core.window.intf.pas; do
  path="$SRC/$unit"
  [[ -f "$path" ]] || continue
  hits="$(strip_comments "$path" | grep -Ec "platform\.dl" || true)"
  if [[ "$hits" -ne 0 ]]; then
    echo "FAIL: $unit references platform.dl (base/intf must not touch loader)"
    fail=1
  fi
done

# --- INV-RTL: L2 生产单元禁止直接 uses FPC RTL（SysUtils/Math/TypInfo/Classes） ---
# 必须经 nextpas.core 反哺：system.sysutils / system.typinfo / math / text.*
for f in "$SRC"/nextpas.core.window*.pas; do
  [[ -e "$f" ]] || continue
  case "$(basename "$f")" in
    *.loader.pas|*.ffi.pas) continue;;
  esac
  content="$(strip_comments "$f" | tr '\n' ' ')"
  # SysUtils
  if echo "$content" | grep -Eq "\bSysUtils\b" && ! echo "$content" | grep -Eq "nextpas\.core\.system\.sysutils"; then
    if echo "$content" | grep -Eq "uses[^;]*\bSysUtils\b"; then
      echo "FAIL: $(basename "$f") directly uses SysUtils (INV-RTL, must via nextpas.core.system.sysutils/text)"
      fail=1
    fi
  fi
  # Math
  if echo "$content" | grep -Eq "\bMath\b" && ! echo "$content" | grep -Eq "nextpas\.core\.math\b"; then
    if echo "$content" | grep -Eq "uses[^;]*\bMath\b"; then
      echo "FAIL: $(basename "$f") directly uses Math (INV-RTL, must via nextpas.core.math)"
      fail=1
    fi
  fi
  # TypInfo
  if echo "$content" | grep -Eq "\bTypInfo\b" && ! echo "$content" | grep -Eq "nextpas\.core\.system\.typinfo"; then
    if echo "$content" | grep -Eq "uses[^;]*\bTypInfo\b"; then
      echo "FAIL: $(basename "$f") directly uses TypInfo (INV-RTL, must via nextpas.core.system.typinfo)"
      fail=1
    fi
  fi
  # Classes
  if echo "$content" | grep -Eq "\bClasses\b" && ! echo "$content" | grep -Eq "nextpas\.core\."; then
    if echo "$content" | grep -Eq "uses[^;]*\bClasses\b"; then
      echo "FAIL: $(basename "$f") directly uses Classes (INV-RTL, must via nextpas.core.*)"
      fail=1
    fi
  fi
done

if [[ "$fail" -eq 0 ]]; then
  echo "window-source-contracts=pass"
else
  echo "window-source-contracts=FAIL"
  exit 1
fi
