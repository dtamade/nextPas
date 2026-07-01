#!/usr/bin/env bash
# system-contract-check.sh — system 模块契约完备性门禁
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/system/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.system"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }
printf "\n${BOLD}C1: 契约文件${NC}\n"
if [ ! -f "$CONTRACT" ]; then warn_check "CONTRACT.md 不存在（待创建）"; else ok "CONTRACT.md 存在"; fi
printf "\n${BOLD}C2: 源文件完备性${NC}\n"
for f in nextpas.core.system.pas nextpas.core.system.contracts.pas nextpas.core.system.typinfo.pas nextpas.core.system.sysutils.pas; do
  if [ -f "$SRC_DIR/$f" ]; then ok "文件: $f"; else warn_check "文件缺失: $f"; fi
done
printf "\n${BOLD}C3: 运行时契约${NC}\n"
for contract in "np.system.process_init" "np.system.process_fini" "np.system.object_free"; do
  if grep -rql "\b$contract\b" "$SRC_DIR"/nextpas.core.system*.pas 2>/dev/null; then ok "契约: $contract"; else warn_check "契约未发现: $contract"; fi
done
printf "\n${BOLD}C4: 门面+测试${NC}\n"
[ -f "$SRC_DIR/nextpas.core.system.pas" ] && ok "门面文件存在" || fail_check "system.pas 门面缺失"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT"; else warn_check "无测试"; fi
printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
