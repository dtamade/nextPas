#!/usr/bin/env bash
# platform-contract-check.sh — platform 模块契约完备性门禁
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/platform/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.platform"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }
printf "\n${BOLD}C1: 契约文件${NC}\n"
if [ ! -f "$CONTRACT" ]; then warn_check "CONTRACT.md 不存在（待创建）"; else ok "CONTRACT.md 存在"; fi
printf "\n${BOLD}C2: 源文件规模${NC}\n"
PAS_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.platform*.pas' 2>/dev/null | wc -l)
INC_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.platform*.inc' 2>/dev/null | wc -l)
ok "源文件: $PAS_COUNT .pas + $INC_COUNT .inc"
printf "\n${BOLD}C3: 核心子系统${NC}\n"
for sub in "io" "socket" "thread" "sync" "fs" "env" "time" "ffi" "signal"; do
  if find "$SRC_DIR" -name "nextpas.core.platform.$sub*.pas" 2>/dev/null | grep -q .; then ok "子系统: $sub"; else warn_check "子系统未发现: $sub"; fi
done
printf "\n${BOLD}C4: 平台适配${NC}\n"
for plat in "linux" "darwin" "win" "posix"; do
  if find "$SRC_DIR" -name "nextpas.core.platform*$plat*.pas" 2>/dev/null | grep -q .; then ok "平台: $plat"; else warn_check "平台未发现: $plat"; fi
done
printf "\n${BOLD}C5: 门面+测试${NC}\n"
[ -f "$SRC_DIR/nextpas.core.platform.pas" ] && ok "门面文件存在" || fail_check "platform.pas 门面缺失"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT"; else warn_check "无测试"; fi
printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
