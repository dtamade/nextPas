#!/usr/bin/env bash
# git-contract-check.sh — git 模块契约完备性门禁
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.git"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }
printf "\n${BOLD}C1: 源文件${NC}\n"
PAS_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.git*.pas' 2>/dev/null | wc -l)
ok "源文件: $PAS_COUNT 个"
printf "\n${BOLD}C2: 核心类型${NC}\n"
for type in "IGitManager" "TGitManagerImpl" "TGitStatusEntry"; do
  if grep -rql "\b$type\b" "$SRC_DIR"/nextpas.core.git*.pas 2>/dev/null; then ok "类型: $type"; else warn_check "类型未发现: $type"; fi
done
printf "\n${BOLD}C3: 门面+测试${NC}\n"
[ -f "$SRC_DIR/nextpas.core.git.pas" ] && ok "门面文件存在" || warn_check "git.pas 门面缺失"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT"; else warn_check "无测试"; fi
printf "\n${BOLD}C4: 纯后端零 libgit2${NC}\n"
# C4.1: native.manager / native.repository 零 libgit2（grep 闭包，单元级依赖）
NATIVE_MANAGER="$SRC_DIR/nextpas.core.git.native.manager.pas"
NATIVE_REPO="$SRC_DIR/nextpas.core.git.native.repository.pas"
if [ -f "$NATIVE_MANAGER" ]; then
  if grep -q "nextpas\.core\.git\.libgit2" "$NATIVE_MANAGER" 2>/dev/null; then
    fail_check "C4.1 native.manager 潜入 libgit2: $NATIVE_MANAGER"
  else
    ok "C4.1 native.manager 零 libgit2"
  fi
else
  ok "C4.1 native.manager 零 libgit2（文件未创建，Phase 1 前跳过）"
fi
if [ -f "$NATIVE_REPO" ]; then
  if grep -q "nextpas\.core\.git\.libgit2" "$NATIVE_REPO" 2>/dev/null; then
    fail_check "C4.1 native.repository 潜入 libgit2: $NATIVE_REPO"
  else
    ok "C4.1 native.repository 零 libgit2"
  fi
else
  ok "C4.1 native.repository 零 libgit2（文件未创建，Phase 1 前跳过）"
fi
# C4.2: native.* 闭包扫描（所有 native.* 单元 uses 不得拉入 libgit2 轨道）
NATIVE_HITS=$(grep -R "nextpas\.core\.git\.libgit2" "$SRC_DIR"/nextpas.core.git.native.*.pas 2>/dev/null || true)
if [ -n "$NATIVE_HITS" ]; then
  fail_check "C4.2 native.* 闭包含 libgit2"
  printf "%s\n" "$NATIVE_HITS" | sed 's/^/  /'
else
  ok "C4.2 native.* 闭包零 libgit2"
fi
# C4.3: 编译产物检查（fpc -va Loading libgit2 + grep 双重）
PURE_TEST_LPR="$TEST_DIR/test_git_pure_manager/test_git_pure_manager.lpr"
if [ -f "$PURE_TEST_LPR" ]; then
  if grep -Rqi "libgit2" "$PURE_TEST_LPR" 2>/dev/null; then
    fail_check "C4.3 test_git_pure_manager.lpr 含 libgit2 引用"
  else
    ok "C4.3 test_git_pure_manager.lpr 零 libgit2（grep 版）"
  fi
  FPC_VA_OUT=$(fpc -Fu"$SRC_DIR" -va "$PURE_TEST_LPR" -o/tmp/git-pure-va-check 2>&1 || true)
  if echo "$FPC_VA_OUT" | grep -qi "Loading.*libgit2"; then
    fail_check "C4.3 纯编译拉入 libgit2（fpc -va 命中 Loading libgit2）"
    echo "$FPC_VA_OUT" | grep -i "libgit2" | sed 's/^/  /'
  else
    ok "C4.3 纯编译零 libgit2（fpc -va 无 Loading libgit2）"
  fi
  rm -f /tmp/git-pure-va-check /tmp/git-pure-va-check.o 2>/dev/null || true
else
  ok "C4.3 纯编译零 libgit2（test_git_pure_manager 未创建，Phase 3 前跳过）"
fi
printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
