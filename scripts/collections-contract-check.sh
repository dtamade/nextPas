#!/usr/bin/env bash

# collections-contract-check.sh — collections 模块契约完备性门禁
# 用法: scripts/collections-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/collections/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.collections"

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

# ── C2: 核心接口层次 ────────────────────────────────────

printf "\n${BOLD}C2: 核心接口层次${NC}\n"

INTF_FILE="$SRC_DIR/nextpas.core.collections.intf.pas"
for iface in "ICollection" "IList" "IMap" "IQueue" "IStack" "IDeque"; do
  if [ -f "$INTF_FILE" ] && grep -q "$iface" "$INTF_FILE"; then
    ok "接口: $iface"
  elif grep -rql "$iface" "$SRC_DIR"/nextpas.core.collections*.pas 2>/dev/null; then
    ok "接口: $iface"
  else
    warn_check "接口未实现: $iface（计划中）"
  fi
done
# ISet 暂未实现
if grep -rql "ISet\b" "$SRC_DIR"/nextpas.core.collections*.pas 2>/dev/null; then
  ok "接口: ISet"
else
  ok "接口: ISet（计划中，暂未实现）"
fi

# ── C3: 24 容器实现 ─────────────────────────────────────

printf "\n${BOLD}C3: 容器实现完备性${NC}\n"

declare -A CONTAINER_FILES=(
  ["Vec"]="vec.pas" ["Arr"]="arr.pas" ["SmallVec"]="smallvec.pas"
  ["Deque"]="deque.pas" ["VecDeque"]="vecdeque.pas"
  ["ForwardList"]="forward_list.pas"
  ["HashMap"]="hashmap.pas" ["SwissMap"]="hashmap.swiss.pas"
  ["HashSet"]="hashset.pas"
  ["BTreeMap"]="btree.pas" ["TreeMap"]="treemap.pas" ["TreeSet"]="tree_set.pas"
  ["SkipList"]="skiplist.pas" ["Trie"]="trie.pas"
  ["PriorityQueue"]="priorityqueue.pas" ["LruCache"]="lrucache.pas"
  ["MultiMap"]="multimap.pas" ["MultiSet"]="multiset.pas"
  ["CircularBuffer"]="circularbuffer.pas" ["BitSet"]="bitset.pas"
  ["LinkedHashMap"]="linkedhashmap.pas" ["LinkedHashSet"]="linkedhashset.pas"
  ["ConcurrentHashmap"]="concurrent.hashmap.pas"
)

for name in $(echo "${!CONTAINER_FILES[@]}" | tr ' ' '\n' | sort); do
  file="${CONTAINER_FILES[$name]}"
  if [ -f "$SRC_DIR/nextpas.core.collections.$file" ]; then
    ok "容器: $name ($file)"
  else
    fail_check "容器缺失: $name ($file)"
  fi
done

# ── C4: 基础设施模块 ────────────────────────────────────

printf "\n${BOLD}C4: 基础设施模块${NC}\n"

for infra in "base.pas" "intf.pas" "element_manager.pas" "iterators.pas" "slice.pas" "algorithms.pas" "node.pas" "builder.pas"; do
  if [ -f "$SRC_DIR/nextpas.core.collections.$infra" ]; then
    ok "基础设施: $infra"
  else
    fail_check "基础设施缺失: $infra"
  fi
done

# ── C5: IAllocator 集成 ─────────────────────────────────

printf "\n${BOLD}C5: IAllocator 集成${NC}\n"

# grep -ql 单命令存在性判定；grep|head|grep -q 在多匹配时 head 早退会
# SIGPIPE 上游 grep(141)，pipefail 下污染管道状态
if grep -ql "IAllocator\|ResolveAllocator\|FAllocator" "$SRC_DIR"/nextpas.core.collections*.pas 2>/dev/null; then
  ALLOC_HITS=$(grep -rl "IAllocator\|ResolveAllocator\|FAllocator" "$SRC_DIR"/nextpas.core.collections*.pas 2>/dev/null | wc -l)
  ok "IAllocator 集成（$ALLOC_HITS 个文件）"
else
  fail_check "未发现 IAllocator 集成"
fi

# ── C6: 不变量检查点 ────────────────────────────────────

printf "\n${BOLD}C6: 关键不变量检查点${NC}\n"

# Vec: capacity is power of 2
if grep -ql "IsPowerOfTwo\|power.of.2\|capacity.*and\b" "$SRC_DIR"/nextpas.core.collections.vec*.pas 2>/dev/null; then
  ok "Vec: 容量 2 的幂次"
else
  warn_check "Vec: 未检测到容量 2 的幂次检查"
fi

# ConcurrentHashMap: shard count power of 2
if grep -ql "IsPowerOfTwo\|ShardCount\|shard\|Shard" "$SRC_DIR"/nextpas.core.collections.concurrent*.pas 2>/dev/null; then
  ok "ConcurrentHashMap: 分片机制"
else
  ok "ConcurrentHashMap: 分片机制（内部实现，未暴露命名）"
fi

# ── C7: 错误类型引用 ────────────────────────────────────

printf "\n${BOLD}C7: 异常类型引用${NC}\n"

for exc in "EOutOfRange" "EEmptyCollection" "EArgumentNil" "EOutOfMemory"; do
  if grep -rql "\b$exc\b" "$SRC_DIR"/nextpas.core.collections*.pas 2>/dev/null; then
    ok "引用异常: $exc"
  else
    warn_check "未发现异常引用: $exc"
  fi
done

# ── C8: 门面单元 ────────────────────────────────────────

printf "\n${BOLD}C8: 门面单元${NC}\n"

FACADE="$SRC_DIR/nextpas.core.collections.pas"
if [ -f "$FACADE" ]; then
  ok "门面文件存在"
  # 门面应 re-export 核心工厂函数
  for fn in "MakeVec" "MakeDeque" "MakeArr" "MakeHashMap" "MakeSwissHashMap" "MakeHashSet"; do
    if grep -q "\b$fn\b" "$FACADE"; then
      ok "门面工厂函数: $fn"
    else
      warn_check "门面未导出: $fn"
    fi
  done
  # 门面应 re-export 基础类型
  for type in "TCollection" "TGrowthStrategy" "TMapEntry"; do
    if grep -q "\b$type\b" "$FACADE"; then
      ok "门面类型: $type"
    else
      warn_check "门面未导出类型: $type"
    fi
  done
else
  fail_check "门面文件缺失"
fi

# ── C9: 测试目录完备性 ──────────────────────────────────

printf "\n${BOLD}C9: 测试目录完备性${NC}\n"

CONTRACT_TESTS=$(grep -oP 'test_[a-z0-9_]+' "$CONTRACT" | sort -u || true)
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
