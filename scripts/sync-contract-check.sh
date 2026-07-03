#!/usr/bin/env bash

# sync-contract-check.sh — sync 模块契约完备性门禁
# 用法: scripts/sync-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/sync/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.sync"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }

# ── C1: 契约文件结构 ────────────────────────────────────

printf "\n${BOLD}C1: 契约文件结构${NC}\n"

if [ ! -f "$CONTRACT" ]; then
  fail_check "CONTRACT.md 不存在"; exit 1
fi

for section in "接口契约" "不变量" "错误处理" "线程安全" "内存管理" "测试覆盖"; do
  if grep -q "$section" "$CONTRACT"; then
    ok "章节 '$section'"
  else
    fail_check "章节 '$section' 缺失"
  fi
done

# ── C2: 源文件完备性 (13 个) ────────────────────────────

printf "\n${BOLD}C2: 源文件完备性${NC}\n"

SYNC_FILES=("nextpas.core.sync.pas" "nextpas.core.sync.base.pas" "nextpas.core.sync.intf.pas"
            "nextpas.core.sync.mutex.pas" "nextpas.core.sync.rwlock.pas" "nextpas.core.sync.semaphore.pas"
            "nextpas.core.sync.event.pas" "nextpas.core.sync.condvar.pas" "nextpas.core.sync.barrier.pas"
            "nextpas.core.sync.spinlock.pas" "nextpas.core.sync.once.pas" "nextpas.core.sync.waitgroup.pas"
            "nextpas.core.sync.pool.pas")
for f in "${SYNC_FILES[@]}"; do
  if [ -f "$SRC_DIR/$f" ]; then
    ok "文件: $f"
  else
    fail_check "文件缺失: $f"
  fi
done

# ── C3: 同步原语 ────────────────────────────────────────

printf "\n${BOLD}C3: 10 个同步原语${NC}\n"

for prim in "TMutex" "TRWLock" "TSemaphore" "IEvent" "TCondVar" \
            "TBarrier" "TSpinLock" "TOnceProc" "TWaitGroup" "TSyncPool"; do
  if grep -rql "$prim" "$SRC_DIR"/nextpas.core.sync*.pas 2>/dev/null; then
    ok "原语: $prim"
  else
    fail_check "原语缺失: $prim"
  fi
done

# ── C4: 接口定义 ────────────────────────────────────────

printf "\n${BOLD}C4: 核心接口${NC}\n"

INTF_FILE="$SRC_DIR/nextpas.core.sync.intf.pas"
if [ -f "$INTF_FILE" ]; then
  for iface in "ILock" "IMutex" "IRWLock" "IEvent"; do
    if grep -q "$iface" "$INTF_FILE"; then
      ok "接口: $iface"
    else
      fail_check "接口缺失: $iface"
    fi
  done

  # ILock 方法
  if grep -q "\bLock\b" "$INTF_FILE"; then
    ok "ILock.Lock"
  else
    fail_check "ILock.Lock 缺失"
  fi

  # ILockGuard
  if grep -q "ILockGuard" "$INTF_FILE"; then
    ok "ILockGuard 接口"
  else
    fail_check "ILockGuard 缺失"
  fi
else
  fail_check "sync.intf.pas 缺失"
fi

# ── C5: 平台适配 ────────────────────────────────────────

printf "\n${BOLD}C5: 平台适配${NC}\n"

MUTEX_FILE="$SRC_DIR/nextpas.core.sync.mutex.pas"
if [ -f "$MUTEX_FILE" ]; then
  if grep -q "pthread_mutex\|RTLThreadsSync\|CriticalSection" "$MUTEX_FILE"; then
    ok "TMutex 平台适配"
  else
    warn_check "TMutex 平台适配未识别"
  fi
fi

POOL_FILE="$SRC_DIR/nextpas.core.sync.pool.pas"
if [ -f "$POOL_FILE" ]; then
  if grep -q "threadvar\|TLS\|Freelist" "$POOL_FILE"; then
    ok "TSyncPool TLS freelist"
  else
    fail_check "TSyncPool TLS freelist 缺失"
  fi
fi

# ── C6: 门面重导出 ──────────────────────────────────────

printf "\n${BOLD}C6: 门面重导出${NC}\n"

FACADE="$SRC_DIR/nextpas.core.sync.pas"
if [ -f "$FACADE" ]; then
  for type in "TMutex" "TRWLock" "TWaitGroup" "TCondVar" "TOnceProc" "TBarrierWaitResult"; do
    if grep -q "\b$type\b" "$FACADE"; then
      ok "门面导出: $type"
    else
      fail_check "门面未导出: $type"
    fi
  done
  for fn in "Mutex" "RWLock" "WaitGroup" "CondVar" "Once" "SpinLock"; do
    if grep -q "\b$fn\b" "$FACADE"; then
      ok "工厂函数: $fn"
    else
      warn_check "工厂函数缺失: $fn"
    fi
  done
else
  fail_check "sync.pas 门面缺失"
fi

# ── C7: 测试目录完备性 ──────────────────────────────────

printf "\n${BOLD}C7: 测试目录完备性${NC}\n"

CONTRACT_TESTS=$(grep -oP 'test_[a-z0-9_]+' "$CONTRACT" | sort -u)
ACTUAL_TESTS=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' -exec basename {} \; | sort -u)

MISSING_TESTS=""
for t in $CONTRACT_TESTS; do
  if ! echo "$ACTUAL_TESTS" | grep -qx "$t"; then
    MISSING_TESTS="$MISSING_TESTS $t"
  fi
done

if [ -z "$MISSING_TESTS" ]; then
  ok "契约声明的测试全部存在"
else
  for t in $MISSING_TESTS; do
    fail_check "契约声明但缺失的测试: $t"
  done
fi

UNDECLARED=""
for t in $ACTUAL_TESTS; do
  if ! echo "$CONTRACT_TESTS" | grep -qx "$t"; then
    UNDECLARED="$UNDECLARED $t"
  fi
done

if [ -z "$UNDECLARED" ]; then
  ok "无未声明的测试目录"
else
  for t in $UNDECLARED; do
    warn_check "实际存在但契约未声明的测试: $t"
  done
fi

# ── 结果汇总 ─────────────────────────────────────────────

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"

if [ "$fail" -gt 0 ]; then
  printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then
  printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else
  printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0
fi
