#!/usr/bin/env bash

# net-contract-check.sh — net 模块契约完备性门禁
# 用法: scripts/net-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/net/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.net"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; BOLD='\033[1m'; NC='\033[0m'
pass=0; fail=0; warn=0
ok() { pass=$((pass + 1)); printf "${GREEN}✓${NC} %s\n" "$1"; }
fail_check() { fail=$((fail + 1)); printf "${RED}✗${NC} %s\n" "$1"; }
warn_check() { warn=$((warn + 1)); printf "${YELLOW}⚠${NC} %s\n" "$1"; }

# ── C1: 契约文件结构 ────────────────────────────────────

printf "\n${BOLD}C1: 契约文件结构${NC}\n"

if [ ! -f "$CONTRACT" ]; then
  fail_check "CONTRACT.md 不存在"; exit 1
fi

for section in "接口契约" "不变量" "概要" "变更记录"; do
  if grep -q "$section" "$CONTRACT"; then
    ok "章节 '$section'"
  else
    fail_check "章节 '$section' 缺失"
  fi
done

# ── C2: 源文件完备性 (14 个) ────────────────────────────

printf "\n${BOLD}C2: 源文件完备性${NC}\n"

NET_FILES=("nextpas.core.net.pas" "nextpas.core.net.base.pas" "nextpas.core.net.intf.pas"
           "nextpas.core.net.resolve.pas" "nextpas.core.net.tcp.pas" "nextpas.core.net.udp.pas"
           "nextpas.core.net.server.pas" "nextpas.core.net.server.base.pas"
           "nextpas.core.net.server.epoll.pas" "nextpas.core.net.server.intf.pas"
           "nextpas.core.net.server.kqueue.pas" "nextpas.core.net.server.readiness.pas"
           "nextpas.core.net.server.runtime.pas" "nextpas.core.net.server.threaded.pas")
for f in "${NET_FILES[@]}"; do
  if [ -f "$SRC_DIR/$f" ]; then
    ok "文件: $f"
  else
    fail_check "文件缺失: $f"
  fi
done

# ── C3: 核心接口 ────────────────────────────────────────

printf "\n${BOLD}C3: 核心接口${NC}\n"

INTF_FILE="$SRC_DIR/nextpas.core.net.intf.pas"
if [ -f "$INTF_FILE" ]; then
  for iface in "ITcpStream" "ITcpListener" "IUdpSocket"; do
    if grep -q "\b$iface\b" "$INTF_FILE"; then
      ok "接口: $iface"
    else
      warn_check "接口未发现: $iface"
    fi
  done

  # IStream methods
  for method in "TryRead" "TryWrite" "Close"; do
    if grep -q "\b$method\b" "$INTF_FILE"; then
      ok "接口方法: $method"
    else
      warn_check "接口方法缺失: $method"
    fi
  done
else
  fail_check "net.intf.pas 缺失"
fi

# ── C4: 服务器子系统 ────────────────────────────────────

printf "\n${BOLD}C4: 服务器子系统 (7 文件)${NC}\n"

SERVER_FILES=("nextpas.core.net.server.pas" "nextpas.core.net.server.base.pas"
              "nextpas.core.net.server.epoll.pas" "nextpas.core.net.server.kqueue.pas"
              "nextpas.core.net.server.intf.pas" "nextpas.core.net.server.readiness.pas"
              "nextpas.core.net.server.runtime.pas" "nextpas.core.net.server.threaded.pas")
for f in "${SERVER_FILES[@]}"; do
  if [ -f "$SRC_DIR/$f" ]; then
    ok "服务器: $f"
  else
    warn_check "服务器缺失: $f"
  fi
done

# ── C5: 平台多路复用 ────────────────────────────────────

printf "\n${BOLD}C5: 平台多路复用${NC}\n"

if grep -rql "\bepoll\b" "$SRC_DIR"/nextpas.core.net.server*.pas 2>/dev/null; then
  ok "epoll 支持"
else
  warn_check "未检测到 epoll"
fi

if grep -rql "\bkqueue\b" "$SRC_DIR"/nextpas.core.net.server*.pas 2>/dev/null; then
  ok "kqueue 支持"
else
  warn_check "未检测到 kqueue"
fi

# ── C6: 错误类型 ────────────────────────────────────────

printf "\n${BOLD}C6: 错误类型${NC}\n"

for err in "ENetworkError" "ETimeoutError"; do
  if grep -rql "\b$err\b" "$SRC_DIR"/nextpas.core.net*.pas 2>/dev/null; then
    ok "错误类型: $err"
  else
    warn_check "未发现错误类型: $err"
  fi
done

# ── C7: 门面单元 ────────────────────────────────────────

printf "\n${BOLD}C7: 门面单元${NC}\n"

FACADE="$SRC_DIR/nextpas.core.net.pas"
if [ -f "$FACADE" ]; then
  ok "门面文件存在"
else
  fail_check "net.pas 门面缺失"
fi

# ── C8: 测试完备性 ──────────────────────────────────────

printf "\n${BOLD}C8: 测试完备性${NC}\n"

TEST_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' -exec basename {} \; 2>/dev/null | wc -l)
if [ "$TEST_COUNT" -gt 0 ]; then
  ok "测试目录: $TEST_COUNT 个"
else
  warn_check "无 test_* 目录"
fi

# ── 结果汇总 ─────────────────────────────────────────────

printf "\n${BOLD}═══════════════════════════════════${NC}\n"
printf "${GREEN}通过: %d${NC}  ${RED}失败: %d${NC}  ${YELLOW}警告: %d${NC}\n" "$pass" "$fail" "$warn"

if [ "$fail" -gt 0 ]; then
  printf "\n${RED}${BOLD}契约门禁: 失败${NC}\n"; exit 1
elif [ "$warn" -gt 0 ]; then
  printf "\n${YELLOW}${BOLD}契约门禁: 通过（有警告）${NC}\n"; exit 0
else
  printf "\n${GREEN}${BOLD}契约门禁: 全通过${NC}\n"; exit 0
fi
