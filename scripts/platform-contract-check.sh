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
for sub in "io" "socket" "thread" "sync" "fs" "env" "time" "dl" "signal"; do
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

printf "\n${BOLD}C6: API 签名一致性${NC}\n"
# 检查 CONTRACT.md 中的 API 签名是否与源码一致
check_api_signature() {
  local func_name="$1"
  local expected_sig="$2"
  local src_file="$3"
  if grep -q "$expected_sig" "$SRC_DIR/$src_file" 2>/dev/null; then
    ok "API 签名: $func_name"
  else
    fail_check "API 签名不匹配: $func_name"
  fi
}

check_api_signature "platform_file_read" "ALen: PtrUInt" "nextpas.core.platform.files.pas"
check_api_signature "platform_file_write" "ALen: PtrUInt" "nextpas.core.platform.files.pas"
check_api_signature "platform_process_wait" "ATimeoutMs: Int64" "nextpas.core.platform.process.pas"
check_api_signature "platform_watch_poll" "ATimeoutMs: Int64" "nextpas.core.platform.watch.pas"
check_api_signature "platform_console_wait_readable" "ATimeoutMs: Int64" "nextpas.core.platform.console.pas"

printf "\n${BOLD}C7: 错误码一致性${NC}\n"
# 检查 fallback stub 是否使用 PLATFORM_ERR_UNSUPPORTED
# 排除合法的 -1 返回（搜索未找到、实现错误处理等）
FALLBACK_COUNT=$(grep -rn 'Result := -1' "$SRC_DIR"/nextpas.core.platform.*.pas 2>/dev/null | grep -v 'fmt.pas\|io.pas.*Exit(LI)\|fs.pas.*Exit\|which.pas\|random.pas\|thread.pas.*Unexpected\|socket.pas.*getaddrinfo\|watch.pas.*close' | wc -l)
if [ "$FALLBACK_COUNT" -eq 0 ]; then
  ok "无 fallback stub 使用 -1"
else
  warn_check "发现 $FALLBACK_COUNT 处 fallback stub 使用 -1"
fi

printf "\n${BOLD}C8: 测试覆盖${NC}\n"
# 检查关键模块是否有测试
for mod in "watch" "pty" "signal" "socket"; do
  if [ -d "$TEST_DIR/test_platform_$mod" ]; then
    ok "测试覆盖: $mod"
  else
    warn_check "无测试: $mod"
  fi
done

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"
if [ "$fail" -gt 0 ]; then printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0; fi
