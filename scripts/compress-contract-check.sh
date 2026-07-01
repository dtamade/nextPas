#!/usr/bin/env bash
# compress-contract-check.sh — compress 模块契约完备性门禁
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/compress/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.compress"
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
PAS_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.compress*.pas' 2>/dev/null | wc -l)
ok "源文件: $PAS_COUNT 个"
printf "\n${BOLD}C3: 核心接口${NC}\n"
for type in "ICompressWriter" "IDecompressReader" "TDeflateWriter"; do
  if grep -rql "\b$type\b" "$SRC_DIR"/nextpas.core.compress*.pas 2>/dev/null; then ok "类型: $type"; else warn_check "类型未发现: $type"; fi
done
printf "\n${BOLD}C4: 算法支持${NC}\n"
for alg in "Deflate" "Gzip" "Zlib" "LZ4" "Zstd"; do
  if grep -rql "\b$alg\b" "$SRC_DIR"/nextpas.core.compress*.pas 2>/dev/null; then
    ok "算法: $alg"
  elif [ "$alg" = "Zstd" ]; then
    ok "算法: $alg（计划中，暂未实现）"
  else
    warn_check "算法未发现: $alg"
  fi
done
printf "\n${BOLD}C5: 门面+测试${NC}\n"
[ -f "$SRC_DIR/nextpas.core.compress.pas" ] && ok "门面文件存在" || fail_check "compress.pas 门面缺失"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT"; else warn_check "无测试"; fi
printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
