#!/usr/bin/env bash
# bytes-contract-check.sh — bytes 模块契约完备性门禁
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/bytes/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.bytes"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }
printf "\n${BOLD}C1: 契约文件结构${NC}\n"
if [ ! -f "$CONTRACT" ]; then fail_check "CONTRACT.md 不存在"; exit 1; fi
for section in "接口契约" "不变量" "错误处理" "线程安全" "内存管理" "测试覆盖"; do
  if grep -q "$section" "$CONTRACT"; then ok "章节 '$section'"; else warn_check "章节 '$section' 缺失"; fi
done
printf "\n${BOLD}C2: 源文件完备性${NC}\n"
for f in nextpas.core.bytes.pas nextpas.core.bytes.base.pas nextpas.core.bytes.binary.pas nextpas.core.bytes.builder.pas nextpas.core.bytes.ops.pas nextpas.core.bytes.cursor.pas nextpas.core.bytes.stream.pas; do
  if [ -f "$SRC_DIR/$f" ]; then ok "文件: $f"; else fail_check "文件缺失: $f"; fi
done
printf "\n${BOLD}C3: 核心类型${NC}\n"
for type in "IBytesBuilder" "IByteCursor" "TByteStreamBuf"; do
  if grep -rql "\b$type\b" "$SRC_DIR"/nextpas.core.bytes*.pas 2>/dev/null; then ok "类型: $type"; else fail_check "类型未发现: $type"; fi
done
printf "\n${BOLD}C4: 门面+测试${NC}\n"
[ -f "$SRC_DIR/nextpas.core.bytes.pas" ] && ok "门面文件存在" || fail_check "bytes.pas 门面缺失"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT"; else warn_check "无测试"; fi
printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
