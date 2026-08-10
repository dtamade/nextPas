#!/bin/bash
# win64-wine-smoke.sh — 本地 Windows 侧交叉验证（Wine runtime smoke）
# =====================================================================
# 用途：在 Linux 开发机上，用 fpcupdeluxe 的 ppcrossx64 把 nextpas.core 的
#       *_wine 测试交叉编译为 Win64 PE 并在 Wine 下运行，作为本地快速回归。
#       truth tier 与 common.mk 的 wine-runtime-smoke 一致：这是 Wine 模拟
#       证据，不是真 Windows runtime 证据（真机证据走 core/scripts/*-ci-matrix.sh）。
#
# 用法：
#   win64-wine-smoke.sh <test-dir> [<test-dir> ...]
#     test-dir 是 core/tests 下的相对或绝对目录，例如：
#       core/tests/nextpas.core.io.uring/test_reactor_iocp_wine
#
# 环境变量（可覆盖）：
#   FPC_WIN64      交叉编译器路径（默认探测 fpcupdeluxe 安装 + PATH）
#   FPC_WIN64_CFG  fpcupdeluxe 安装级 fpc.cfg（默认与编译器同目录 fpc.cfg）
#   MINGW_PREFIX   交叉 binutils 前缀（默认 x86_64-w64-mingw32-）
#   WINECMD        wine 可执行（默认 wine）
#
# 依赖：ppcrossx64、win64 交叉单元树（fpcupdeluxe 装的 fpc/units/x86_64-win64）、
#       x86_64-w64-mingw32-as/ld、wine。全部缺失时脚本报 SKIP，不伪装 PASS。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CORE_ROOT="$REPO_ROOT/core"

COLOR_PASS="$(printf '\033[32m')"
COLOR_FAIL="$(printf '\033[31m')"
COLOR_SKIP="$(printf '\033[33m')"
COLOR_RESET="$(printf '\033[0m')"

# ---- 探测工具链 ------------------------------------------------------------

find_ppcrossx64() {
  if [ -n "${FPC_WIN64:-}" ]; then
    [ -x "$FPC_WIN64" ] && { printf '%s' "$FPC_WIN64"; return 0; }
    return 1
  fi
  # fpcupdeluxe 常见安装布局（~ 前缀展开）
  local cand
  for base in "$HOME/fpcupdeluxe" "$HOME/freepascal" "$HOME/fpcupdeluxe/fpc" \
              "$HOME/freepascal/fpc"; do
    for cand in "$base/bin/x86_64-linux/ppcrossx64" "$base/bin/ppcrossx64"; do
      if [ -x "$cand" ]; then
        printf '%s' "$cand"
        return 0
      fi
    done
  done
  # PATH
  if command -v ppcrossx64 >/dev/null 2>&1; then
    command -v ppcrossx64
    return 0
  fi
  return 1
}

find_fpc_cfg() {
  if [ -n "${FPC_WIN64_CFG:-}" ]; then
    [ -f "$FPC_WIN64_CFG" ] && { printf '%s' "$FPC_WIN64_CFG"; return 0; }
    return 1
  fi
  # 与编译器同目录的 fpcupdeluxe 安装级 cfg
  local bin_dir
  bin_dir="$(dirname "$FPC_WIN64")"
  if [ -f "$bin_dir/fpc.cfg" ]; then
    printf '%s' "$bin_dir/fpc.cfg"
    return 0
  fi
  return 1
}

FPC_WIN64="$(find_ppcrossx64 || true)"
FPC_WIN64_CFG="$(find_fpc_cfg || true)"
MINGW_PREFIX="${MINGW_PREFIX:-x86_64-w64-mingw32-}"
WINECMD="${WINECMD:-wine}"

if [ -z "$FPC_WIN64" ]; then
  echo "SKIP: ppcrossx64 not found (set FPC_WIN64 or install fpcupdeluxe cross)"
  exit 0
fi
if [ -z "$FPC_WIN64_CFG" ]; then
  echo "SKIP: fpcupdeluxe fpc.cfg not found next to $FPC_WIN64 (set FPC_WIN64_CFG)"
  exit 0
fi
if ! command -v "$WINECMD" >/dev/null 2>&1; then
  echo "SKIP: wine not found (this is not real Windows runtime evidence)"
  exit 0
fi
if ! command -v "${MINGW_PREFIX}as" >/dev/null 2>&1 || \
   ! command -v "${MINGW_PREFIX}ld" >/dev/null 2>&1; then
  echo "SKIP: mingw binutils (${MINGW_PREFIX}as/ld) not found"
  exit 0
fi

if [ "$#" -eq 0 ]; then
  echo "usage: win64-wine-smoke.sh <test-dir> [<test-dir> ...]"
  exit 2
fi

# ---- 单测试目录：交叉编译 + Wine 运行 --------------------------------------

run_one() {
  local test_dir="$1"
  local abs_dir
  local program
  local module_name
  local build_dir
  local log_path
  local summary
  local rc

  abs_dir="$REPO_ROOT/$test_dir"
  if [ ! -d "$abs_dir" ]; then
    printf '%s %s\n' "${COLOR_FAIL}FAIL${COLOR_RESET}" "$test_dir: missing directory"
    return 1
  fi

  module_name="$(basename "$(dirname "$test_dir")")"
  program="$(sed -n 's/^PROGRAM[[:space:]]*:=[[:space:]]*\([A-Za-z0-9_]*\).*/\1/p' \
    "$abs_dir/Makefile" 2>/dev/null | head -n1)"
  if [ -z "$program" ]; then
    program="$(basename "$abs_dir")"
  fi

  build_dir="$CORE_ROOT/build/projects/$module_name/${program}_wine_win64"
  log_path="$(mktemp "/tmp/${program}.wine.XXXXXX.log")"

  # 编译到独立目录；flags 与 common.mk wine-build 一致，另加安装级 cfg +
  # mingw binutils 前缀（本脚本本地适配层，CI 的 make wine-runtime-smoke 不受影响）
  mkdir -p "$build_dir"
  if ! "$FPC_WIN64" -n @"$FPC_WIN64_CFG" -MObjFPC -Sh -Sg -O2 -gl -gh \
       -dHEAPTRC_ACTIVE -Twin64 -Px86_64 -XP"$MINGW_PREFIX" -FD/usr/bin \
       -FU"$build_dir" -FE"$build_dir" \
       -Fu"$CORE_ROOT/src" -Fi"$CORE_ROOT/src" -Fu"$CORE_ROOT/tests/shared" \
       "$abs_dir/$program.lpr" >"$log_path" 2>&1; then
    summary="$(grep -E -- 'Fatal:|Error:' "$log_path" | head -n1 || true)"
    summary="${summary:-cross-compile failed}"
    printf '%s %s\n' "${COLOR_FAIL}FAIL${COLOR_RESET}" "$test_dir: $summary"
    return 1
  fi

  if ! "$WINECMD" "$build_dir/$program.exe" >>"$log_path" 2>&1; then
    rc=$?
    summary="$(grep -E -- '[0-9]+ passed, [0-9]+ failed' "$log_path" | tail -n1 || true)"
    summary="${summary:-wine run failed (exit $rc)}"
    printf '%s %s\n' "${COLOR_FAIL}FAIL${COLOR_RESET}" "$test_dir: $summary"
    return 1
  fi

  summary="$(grep -E -- '[0-9]+ passed, [0-9]+ failed' "$log_path" | tail -n1 || true)"
  if grep -qE -- '[1-9][0-9]* failed' "$log_path"; then
    printf '%s %s\n' "${COLOR_FAIL}FAIL${COLOR_RESET}" "$test_dir: ${summary:-test failures}"
    return 1
  fi
  printf '%s %s\n' "${COLOR_PASS}PASS${COLOR_RESET}" \
    "$test_dir: ${summary:-ok}"
  return 0
}

pass_count=0
fail_count=0
for test_dir in "$@"; do
  if run_one "$test_dir"; then
    pass_count=$((pass_count + 1))
  else
    fail_count=$((fail_count + 1))
  fi
done

echo
echo "summary: pass=$pass_count fail=$fail_count total=$#"
[ "$fail_count" -eq 0 ]
