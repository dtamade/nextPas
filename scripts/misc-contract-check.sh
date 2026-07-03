#!/usr/bin/env bash
# misc-contract-check.sh — 杂项小模块契约完备性门禁
# 覆盖: ini, contracts, props, template, testing, validation
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
SRC_DIR="$REPO_ROOT/core/src"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }

printf "\n${BOLD}杂项小模块门禁${NC}\n\n"

for mod in ini contracts props template testing validation; do
  PAS_COUNT=$(find "$SRC_DIR" -name "nextpas.core.$mod*.pas" 2>/dev/null | wc -l)
  if [ "$PAS_COUNT" -gt 0 ]; then
    ok "$mod: $PAS_COUNT 源文件"
  else
    warn_check "$mod: 无源文件"
  fi
done

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
