#!/usr/bin/env bash

# run-all-contract-checks.sh — 运行全部 34 个模块契约门禁
# 用法: scripts/run-all-contract-checks.sh [--verbose]
# 退出码: 0 = 全通过, 1 = 有失败

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'

VERBOSE=0
if [ "${1:-}" = "--verbose" ]; then VERBOSE=1; fi

TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_WARN=0; SCRIPT_FAIL=0; SCRIPT_COUNT=0

printf "${BOLD}═══════════════════════════════════════════${NC}\n"
printf "${BOLD}  nextpas.core 契约门禁 — 全模块验证${NC}\n"
printf "${BOLD}═══════════════════════════════════════════${NC}\n\n"

for script in "$SCRIPT_DIR"/*-contract-check.sh; do
  [ "$(basename "$script")" = "run-all-contract-checks.sh" ] && continue
  [ "$(basename "$script")" = "build-hygiene-check.sh" ] && continue
  [ "$(basename "$script")" = "rebuild-compiler.sh" ] && continue

  name=$(basename "$script" .sh | sed 's/-contract-check//')
  SCRIPT_COUNT=$((SCRIPT_COUNT + 1))

  output=$(bash "$script" 2>&1) && rc=0 || rc=$?

  if [ "$rc" -ne 0 ]; then
    printf "${RED}✗${NC} %-14s ${RED}FAIL${NC}\n" "$name"
    SCRIPT_FAIL=$((SCRIPT_FAIL + 1))
    if [ "$VERBOSE" -eq 1 ]; then echo "$output" | sed 's/^/    /'; fi
  else
    p=$(echo "$output" | grep -oP '通过: \K\d+' || echo 0)
    f=$(echo "$output" | grep -oP '失败: \K\d+' || echo 0)
    w=$(echo "$output" | grep -oP '警告: \K\d+' || echo 0)
    TOTAL_PASS=$((TOTAL_PASS + p))
    TOTAL_FAIL=$((TOTAL_FAIL + f))
    TOTAL_WARN=$((TOTAL_WARN + w))

    if [ "$w" -gt 0 ]; then
      printf "${GREEN}✓${NC} %-14s %3d checks  ${YELLOW}%d warnings${NC}\n" "$name" "$p" "$w"
    else
      printf "${GREEN}✓${NC} %-14s %3d checks\n" "$name" "$p"
    fi
  fi
done

printf "\n${BOLD}═══════════════════════════════════════════${NC}\n"
printf "脚本: %d  通过: %d  失败脚本: %d\n" "$SCRIPT_COUNT" "$((SCRIPT_COUNT - SCRIPT_FAIL))" "$SCRIPT_FAIL"
printf "检查项: %d  警告: %d\n" "$TOTAL_PASS" "$TOTAL_WARN"

if [ "$SCRIPT_FAIL" -gt 0 ]; then
  printf "\n${RED}${BOLD}契约门禁: 有 %d 个模块失败${NC}\n" "$SCRIPT_FAIL"
  exit 1
else
  printf "\n${GREEN}${BOLD}契约门禁: 全部通过${NC}\n"
  exit 0
fi
