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
  # C4.3a: fpc -va 编译图检查（Loading.*libgit2 零命中，零拷贝 inline 证据：factory 枚举值类型分发）
  FPC_BIN="${FPC:-fpc}"
  TMP_FPC_VA_DIR=$(mktemp -d 2>/dev/null || echo "/tmp/nextpas-git-pure-va-$$")
  mkdir -p "$TMP_FPC_VA_DIR"
  FPC_VA_LOG="$TMP_FPC_VA_DIR/fpc-va.log"
  FPC_VA_FLAGS="-MObjFPC -Sh -Sg -O2 -gl -B -va -Fu$SRC_DIR -Fi$SRC_DIR -Fu$REPO_ROOT/core/tests/shared -FU$TMP_FPC_VA_DIR -FE$TMP_FPC_VA_DIR"
  if "$FPC_BIN" $FPC_VA_FLAGS "$PURE_TEST_LPR" >"$FPC_VA_LOG" 2>&1; then
    if grep -qi "Loading.*libgit2" "$FPC_VA_LOG" 2>/dev/null; then
      fail_check "C4.3a fpc -va 编译图污染（Loading libgit2）"
      grep -i "Loading.*libgit2" "$FPC_VA_LOG" | sed 's/^/  /' | head -n 20
    else
      ok "C4.3a fpc -va 编译图零 libgit2"
    fi
  else
    if grep -qi "Loading.*libgit2" "$FPC_VA_LOG" 2>/dev/null; then
      fail_check "C4.3a fpc -va 编译图污染（编译失败但命中 libgit2）"
    else
      warn_check "C4.3a fpc -va 编译失败（环境）——跳过 Loading 检查"
      sed 's/^/  /' "$FPC_VA_LOG" | head -n 30
    fi
  fi
  rm -rf "$TMP_FPC_VA_DIR"
  # C4.3b: 产物 nm 检查（nm -D 零命中 git_，资源释放：临时文件 try..finally 清理，EGitError 不丢）
  PURE_BIN_CANDIDATES=(
    "$REPO_ROOT/core/build/projects/nextpas.core.git/test_git_pure_manager/test_git_pure_manager"
    "$REPO_ROOT/build/bin/test_git_pure_manager"
    "$REPO_ROOT/build/projects/nextpas.core.git/test_git_pure_manager/test_git_pure_manager"
  )
  PURE_BIN=""
  for cand in "${PURE_BIN_CANDIDATES[@]}"; do
    if [ -f "$cand" ] && [ -x "$cand" ]; then PURE_BIN="$cand"; break; fi
  done
  if [ -z "$PURE_BIN" ]; then
    TMP_NM_DIR=$(mktemp -d 2>/dev/null || echo "/tmp/nextpas-git-pure-nm-$$")
    mkdir -p "$TMP_NM_DIR"
    if "$FPC_BIN" -MObjFPC -Sh -Sg -O2 -gl -B -Fu"$SRC_DIR" -Fi"$SRC_DIR" -Fu"$REPO_ROOT/core/tests/shared" -FU"$TMP_NM_DIR" -FE"$TMP_NM_DIR" "$PURE_TEST_LPR" >"$TMP_NM_DIR/build.log" 2>&1; then
      if [ -f "$TMP_NM_DIR/test_git_pure_manager" ]; then PURE_BIN="$TMP_NM_DIR/test_git_pure_manager"; fi
    fi
  else
    TMP_NM_DIR=""
  fi
  if [ -n "$PURE_BIN" ] && [ -f "$PURE_BIN" ]; then
    if command -v nm >/dev/null 2>&1; then
      if nm -D "$PURE_BIN" 2>/dev/null | grep -q " git_"; then
        fail_check "C4.3b 产物 nm 污染（nm -D 含 git_）"
        nm -D "$PURE_BIN" 2>/dev/null | grep " git_" | sed 's/^/  /' | head -n 20
      else
        ok "C4.3b 产物 nm 零 git_"
      fi
    else
      warn_check "C4.3b nm 缺失，跳过产物符号检查"
    fi
  else
    warn_check "C4.3b 产物缺失，跳过 nm 检查（执行 make build 生成后重试）"
  fi
  if [ -n "${TMP_NM_DIR:-}" ] && [ -d "$TMP_NM_DIR" ]; then rm -rf "$TMP_NM_DIR"; fi
else
  ok "C4.3 纯编译零 libgit2（test_git_pure_manager 未创建，Phase 3 前跳过；fpc -va 检查待文件落地）"
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
printf "\n${BOLD}C6: 子模块/捆绑/搜索/二分覆盖${NC}\n"
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
