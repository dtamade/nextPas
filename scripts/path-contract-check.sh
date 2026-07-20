#!/usr/bin/env bash

# path-contract-check.sh — path 模块契约完备性门禁
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/path/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.path"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }

printf "\n${BOLD}C1: 契约文件结构${NC}\n"
if [ ! -f "$CONTRACT" ]; then fail_check "CONTRACT.md 不存在"; exit 1; fi
for section in "接口契约" "不变量" "测试覆盖" "变更记录"; do
  if grep -q "$section" "$CONTRACT"; then ok "章节 '$section'"; else fail_check "章节 '$section' 缺失"; fi
done

printf "\n${BOLD}C2: 源文件完备性${NC}\n"
if [ -f "$SRC_DIR/nextpas.core.path.pas" ]; then ok "文件: nextpas.core.path.pas"; else fail_check "文件缺失: nextpas.core.path.pas"; fi

printf "\n${BOLD}C3: 核心函数${NC}\n"
for fn in "PathJoin" "PathDir" "PathBase" "PathExt" "PathIsAbsolute" "PathNormalize"; do
  if grep -rql "\b$fn\b" "$SRC_DIR"/nextpas.core.path*.pas 2>/dev/null; then ok "函数: $fn"; else warn_check "函数未发现: $fn"; fi
done

printf "\n${BOLD}C4: 门面单元${NC}\n"
FACADE="$SRC_DIR/nextpas.core.path.pas"
if [ -f "$FACADE" ]; then ok "门面文件存在"; else fail_check "path.pas 门面缺失"; fi

printf "\n${BOLD}C5: 测试完备性${NC}\n"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' -exec basename {} \; 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT 个"; else warn_check "无 test_* 目录"; fi

printf "\n${BOLD}C6: Path 双轨锚点 / mix-use 审计${NC}\n"
AUDIT="$SCRIPT_DIR/path-mixuse-audit.sh"
if [ -x "$AUDIT" ] || [ -f "$AUDIT" ]; then
  if bash "$AUDIT" >/tmp/path-mixuse-audit.out 2>&1; then
    ok "path-mixuse-audit.sh OK"
  else
    fail_check "path-mixuse-audit.sh failed (anchors?)"
    sed -n '1,40p' /tmp/path-mixuse-audit.out || true
  fi
else
  fail_check "scripts/path-mixuse-audit.sh missing"
fi

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
