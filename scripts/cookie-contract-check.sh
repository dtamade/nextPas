#!/usr/bin/env bash
# cookie-contract-check.sh — cookie 模块契约完备性门禁
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.cookie"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }
printf "\n${BOLD}C1: 源文件${NC}\n"
PAS_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.cookie*.pas' 2>/dev/null | wc -l)
ok "源文件: $PAS_COUNT 个"
printf "\n${BOLD}C2: 核心类型${NC}\n"
for type in "TCookie" "TCookieJar"; do
  if grep -rql "\b$type\b" "$SRC_DIR"/nextpas.core.cookie*.pas 2>/dev/null; then ok "类型: $type"; else warn_check "类型未发现: $type"; fi
done
printf "\n${BOLD}C3: 门面+测试${NC}\n"
[ -f "$SRC_DIR/nextpas.core.cookie.pas" ] && ok "门面文件存在" || warn_check "cookie.pas 门面缺失"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT"; else warn_check "无测试"; fi
printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
