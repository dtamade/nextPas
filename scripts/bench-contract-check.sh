#!/usr/bin/env bash
# bench-contract-check.sh — bench 模块契约完备性门禁
set -euo pipefail
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/bench/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.bench"
EX_DIR1="$REPO_ROOT/core/examples/bench"
EX_DIR2="$REPO_ROOT/core/examples/nextpas.core.bench"
MK="$REPO_ROOT/core/tests/nextpas.core.bench/Makefile"
LANE_DUTY="$REPO_ROOT/core/docs/bench/LANE-DUTY.md"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }

printf "\n${BOLD}C1: 契约文件${NC}\n"
if [ ! -f "$CONTRACT" ]; then fail_check "CONTRACT.md 不存在"; else ok "CONTRACT.md 存在"; fi

printf "\n${BOLD}C2: 源文件完备性${NC}\n"
PAS_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.bench*.pas' 2>/dev/null | wc -l)
ok "源文件: $PAS_COUNT 个"

printf "\n${BOLD}C3: 核心类型${NC}\n"
for type in "TParallelBenchmark" "TParallelBenchConfig" "BenchBlackBoxInt64"; do
  if grep -rql "$type" "$SRC_DIR"/nextpas.core.bench*.pas 2>/dev/null; then ok "符号: $type"; else fail_check "符号未发现: $type"; fi
done

printf "\n${BOLD}C4: 门面+测试${NC}\n"
[ -f "$SRC_DIR/nextpas.core.bench.pas" ] && ok "门面文件存在" || fail_check "bench.pas 门面缺失"
TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then ok "测试目录: $TEST_COUNT"; else warn_check "无测试"; fi

printf "\n${BOLD}C5: 示例禁止直连 FPC RTL (SysUtils/Classes)${NC}\n"
RTL_HITS=0
if [ -d "$EX_DIR1" ] || [ -d "$EX_DIR2" ]; then
  if command -v rg >/dev/null 2>&1; then
    if rg -n --glob '*.pas' --glob '*.lpr' '\bSysUtils\b|\bClasses\b' "$EX_DIR1" "$EX_DIR2" 2>/dev/null; then
      RTL_HITS=1
    fi
  else
    if grep -RIn --include='*.pas' --include='*.lpr' -E '\bSysUtils\b|\bClasses\b' "$EX_DIR1" "$EX_DIR2" 2>/dev/null; then
      RTL_HITS=1
    fi
  fi
  if [ "$RTL_HITS" -eq 0 ]; then ok "examples/bench 无 SysUtils/Classes"; else fail_check "examples 含 SysUtils/Classes"; fi
else
  warn_check "examples 目录缺失"
fi

printf "\n${BOLD}C6: LANE-DUTY${NC}\n"
[ -f "$LANE_DUTY" ] && ok "LANE-DUTY.md 存在" || fail_check "LANE-DUTY.md 缺失"

printf "\n${BOLD}C7: 默认 PROJECTS = 22${NC}\n"
if [ -f "$MK" ]; then
  # count tokens on PROJECTS := lines until empty/non-continuation
  PC=$(awk '
    /^PROJECTS[[:space:]]*:?=/ {grab=1}
    grab {
      line=$0
      sub(/PROJECTS[[:space:]]*:?=/,"",line)
      n=split(line,a,/[[:space:]\\]+/)
      for(i=1;i<=n;i++) if(a[i] ~ /^test_/) c++
      if ($0 !~ /\\[[:space:]]*$/) grab=0
    }
    END {print c+0}
  ' "$MK")
  if [ "$PC" = "22" ]; then ok "PROJECTS count=$PC"; else fail_check "PROJECTS count=$PC (期望 22)"; fi
else
  fail_check "Makefile 缺失"
fi

printf "\n${BOLD}C8: orphan 非 gate 目录${NC}\n"
if [ -d "$TEST_DIR/test_test_bench_integration" ]; then
  warn_check "test_test_bench_integration 存在且非默认 PROJECTS（文档已标注）"
else
  ok "无 orphan test_test_bench_integration"
fi

printf "\n${BOLD}C9: core/benchmarks/nextpas.core.* 禁止直连 FPC RTL${NC}\n"
BENCH_ROOT="$REPO_ROOT/core/benchmarks"
# 白名单：刻意 FPC RTL 对照
EXCLUDE_PATH="$BENCH_ROOT/platform-comparison"
RTL_LIST=""
if [ -d "$BENCH_ROOT" ]; then
  if command -v rg >/dev/null 2>&1; then
    RTL_LIST=$(rg -l --glob 'nextpas.core.*/**/*.{lpr,pas}' \
      -e '\bSysUtils\b' -e '\bClasses\b' -e '\bBaseUnix\b' -e '\bUnix\b' -e '\bWindows\b' \
      "$BENCH_ROOT" 2>/dev/null || true)
  else
    RTL_LIST=$(find "$BENCH_ROOT" -path '*/nextpas.core.*/*' \( -name '*.lpr' -o -name '*.pas' \) \
      -print0 2>/dev/null | xargs -0 grep -lE '\bSysUtils\b|\bClasses\b|\bBaseUnix\b' 2>/dev/null || true)
  fi
fi
# filter whitelist and nextpas.core.math false positives handled by Classes/SysUtils only
if [ -n "$RTL_LIST" ]; then
  FILTERED=""
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$f" in
      *platform-comparison*) continue ;;
    esac
    FILTERED="${FILTERED}${f}
"
  done <<EOF
$RTL_LIST
EOF
  if [ -n "$(echo "$FILTERED" | sed '/^$/d')" ]; then
    fail_check "benchmarks 仍含 RTL uses:"
    echo "$FILTERED" | sed '/^$/d' | while read -r line; do printf "    %s\n" "$line"; done
  else
    ok "nextpas.core.* benches 无 SysUtils/Classes/BaseUnix/Unix/Windows"
  fi
else
  ok "nextpas.core.* benches 无 SysUtils/Classes/BaseUnix/Unix/Windows"
fi

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
