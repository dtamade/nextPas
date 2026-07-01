#!/usr/bin/env bash

# fs-contract-check.sh — fs 模块契约完备性门禁
# 用法: scripts/fs-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/fs/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.fs"

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

# ── C2: 源文件完备性 (9 个) ─────────────────────────────

printf "\n${BOLD}C2: 源文件完备性${NC}\n"

FS_FILES=("nextpas.core.fs.pas" "nextpas.core.fs.base.pas" "nextpas.core.fs.intf.pas"
          "nextpas.core.fs.path.pas" "nextpas.core.fs.dir.pas" "nextpas.core.fs.stream.pas"
          "nextpas.core.fs.glob.pas" "nextpas.core.fs.util.pas" "nextpas.core.fs.errors.pas")
for f in "${FS_FILES[@]}"; do
  if [ -f "$SRC_DIR/$f" ]; then
    ok "文件: $f"
  else
    fail_check "文件缺失: $f"
  fi
done

# ── C3: 核心函数域 ──────────────────────────────────────

printf "\n${BOLD}C3: 核心函数域${NC}\n"

# Path functions
for fn in "FsPathJoin" "FsPathBase" "FsPathExt" "FsPathChangeExt" "FsPathIsAbs"; do
  if grep -rql "\b$fn\b" "$SRC_DIR"/nextpas.core.fs*.pas 2>/dev/null; then
    ok "路径函数: $fn"
  else
    fail_check "路径函数缺失: $fn"
  fi
done

# File read/write
for fn in "FsReadFile" "FsReadFileText" "FsWriteFile" "FsWriteAtomic"; do
  if grep -rql "\b$fn\b" "$SRC_DIR"/nextpas.core.fs*.pas 2>/dev/null; then
    ok "文件读写: $fn"
  else
    fail_check "文件读写缺失: $fn"
  fi
done

# File operations
for fn in "FsCopyFile" "FsExists" "FsStat" "FsFileSize"; do
  if grep -rql "\b$fn\b" "$SRC_DIR"/nextpas.core.fs*.pas 2>/dev/null; then
    ok "文件操作: $fn"
  else
    fail_check "文件操作缺失: $fn"
  fi
done

# Directory operations
for fn in "FsMkdir" "FsMkdirAll" "FsRmdir" "FsIsDir" "FsGetCwd"; do
  if grep -rql "\b$fn\b" "$SRC_DIR"/nextpas.core.fs*.pas 2>/dev/null; then
    ok "目录操作: $fn"
  else
    warn_check "目录操作未发现: $fn"
  fi
done

# Glob
for fn in "GlobMatch" "FsGlob"; do
  if grep -rql "\b$fn\b" "$SRC_DIR"/nextpas.core.fs*.pas 2>/dev/null; then
    ok "Glob: $fn"
  else
    fail_check "Glob 缺失: $fn"
  fi
done

# ── C4: 错误类型 ────────────────────────────────────────

printf "\n${BOLD}C4: 错误类型引用${NC}\n"

for err in "ENotFoundError" "EPermissionError" "EIOError" "EAlreadyExistsError"; do
  if grep -rql "\b$err\b" "$SRC_DIR"/nextpas.core.fs*.pas 2>/dev/null; then
    ok "错误类型: $err"
  else
    warn_check "未发现错误类型: $err"
  fi
done

# ── C5: IStream 集成 ────────────────────────────────────

printf "\n${BOLD}C5: IStream 集成${NC}\n"

if grep -rql "\bIStream\b" "$SRC_DIR"/nextpas.core.fs*.pas 2>/dev/null; then
  ok "IStream 引用"
else
  warn_check "未发现 IStream 引用"
fi

# ── C6: 平台适配 ────────────────────────────────────────

printf "\n${BOLD}C6: 平台适配${NC}\n"

if grep -rql "fpOpen\|fpStat\|BaseUnix\|SysUtils" "$SRC_DIR"/nextpas.core.fs*.pas 2>/dev/null; then
  ok "平台 API 调用"
else
  warn_check "未检测到平台 API 调用"
fi

# ── C7: 门面单元 ────────────────────────────────────────

printf "\n${BOLD}C7: 门面单元${NC}\n"

FACADE="$SRC_DIR/nextpas.core.fs.pas"
if [ -f "$FACADE" ]; then
  ok "门面文件存在"
  for fn in "FsPathJoin" "FsReadFileText" "FsExists" "FsMkdir" "GlobMatch"; do
    if grep -q "\b$fn\b" "$FACADE"; then
      ok "门面导出: $fn"
    else
      warn_check "门面未导出: $fn"
    fi
  done
else
  fail_check "fs.pas 门面缺失"
fi

# ── C8: 测试目录完备性 ──────────────────────────────────

printf "\n${BOLD}C8: 测试目录完备性${NC}\n"

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
