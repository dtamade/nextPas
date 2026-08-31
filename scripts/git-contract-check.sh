#!/usr/bin/env bash
# git-contract-check.sh — git 模块契约完备性门禁
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.git"
CONTRACT_FILE="$REPO_ROOT/core/docs/git/CONTRACT.md"
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
NATIVE_HITS=$(grep -R "nextpas\.core\.git\.libgit2" "$SRC_DIR"/nextpas.core.git.native.*.pas 2>/dev/null || true)
if [ -n "$NATIVE_HITS" ]; then
  fail_check "C4.2 native.* 闭包含 libgit2"
  printf "%s\n" "$NATIVE_HITS" | sed 's/^/  /'
else
  ok "C4.2 native.* 闭包零 libgit2"
fi
PURE_TEST_LPR="$TEST_DIR/test_git_pure_manager/test_git_pure_manager.lpr"
if [ -f "$PURE_TEST_LPR" ]; then
  if grep -Rqi "libgit2" "$PURE_TEST_LPR" 2>/dev/null; then
    fail_check "C4.3 test_git_pure_manager.lpr 含 libgit2 引用"
  else
    ok "C4.3 test_git_pure_manager.lpr 零 libgit2（grep 版）"
  fi
  warn_check "C4.3 fpc -va 产物检查 TODO（待 Phase 3 纯测试落地后启用）"
else
  ok "C4.3 纯编译零 libgit2（test_git_pure_manager 未创建，Phase 3 前跳过；TODO: fpc -va Loading 检查）"
fi
printf "\n${BOLD}C5: 新增行为契约覆盖${NC}\n"
INTF_FILE="$SRC_DIR/nextpas.core.git.intf.pas"
for sym in "DiscoverRepository" "CloneRepository" "CommitOnHead" "AddWorktree" "SetVerifySSL"; do
  if [ -f "$INTF_FILE" ] && grep -q "\b$sym\b" "$INTF_FILE"; then
    ok "C5.1 接口存在: $sym"
  else
    fail_check "C5.1 接口缺失: $sym (nextpas.core.git.intf.pas)"
  fi
done
if grep -q "\bVerifySSL\b" "$INTF_FILE" 2>/dev/null; then
  ok "C5.1 接口存在: VerifySSL"
else
  fail_check "C5.1 接口缺失: VerifySSL"
fi
for sym in "DiscoverRepository" "CloneRepository" "CommitOnHead" "AddWorktree" "SetVerifySSL" "VerifySSL"; do
  if grep -q "\b$sym\b" "$CONTRACT_FILE" 2>/dev/null; then
    ok "C5.2 契约覆盖: $sym"
  else
    fail_check "C5.2 契约未覆盖: $sym (CONTRACT.md §2-§5 需声明)"
  fi
done
if grep -q "40.*hex\|40 字符" "$CONTRACT_FILE" 2>/dev/null; then
  ok "C5.3 不变量含 40-hex 约束"
else
  fail_check "C5.3 不变量缺 40-hex 约束"
fi
if grep -q "EGitError" "$CONTRACT_FILE" 2>/dev/null; then
  ok "C5.3 错误处理含 EGitError"
else
  fail_check "C5.3 错误处理缺 EGitError"
fi
if grep -q "线程安全" "$CONTRACT_FILE" 2>/dev/null; then
  ok "C5.3 线程安全章节存在"
else
  fail_check "C5.3 线程安全章节缺失"
fi
if grep -q "IGitManager.*线程安全" "$CONTRACT_FILE" 2>/dev/null; then
  ok "C5.4 IGitManager 线程安全声明"
else
  fail_check "C5.4 IGitManager 线程安全未声明"
fi
if grep -q "IGitRepository.*非线程安全" "$CONTRACT_FILE" 2>/dev/null; then
  ok "C5.4 IGitRepository 非线程安全声明"
else
  fail_check "C5.4 IGitRepository 非线程安全未声明"
fi
if grep -q "单源复用\|wildmatch\|bytes\.ops\|adler32" "$CONTRACT_FILE" 2>/dev/null; then
  ok "C5.5 单源复用声明"
else
  warn_check "C5.5 单源复用声明缺失（应声明 wildmatch/bytes.ops 复用）"
fi
printf "\n${BOLD}C6: 子模块/捆绑/搜索/二分覆盖（可选）${NC}\n"
NATIVE_LPR="$TEST_DIR/test_git_native/test_git_native.lpr"
if [ -f "$NATIVE_LPR" ]; then
  for kw in "submodule" "bundle" "grep" "bisect"; do
    if grep -qi "$kw" "$NATIVE_LPR" 2>/dev/null; then ok "C6 native $kw 覆盖"; else warn_check "C6 native $kw 缺失（可选）"; fi
  done
else
  warn_check "C6 native.lpr 缺失，跳过子模块/捆绑/搜索/二分检查"
fi
printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
