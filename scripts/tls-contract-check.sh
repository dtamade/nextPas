#!/usr/bin/env bash

# tls-contract-check.sh — tls 模块契约完备性门禁
# 用法: scripts/tls-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/tls/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.tls"

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

for section in "接口契约" "不变量" "错误处理" "线程安全" "内存管理" "测试覆盖"; do
  if grep -q "$section" "$CONTRACT"; then
    ok "章节 '$section'"
  else
    fail_check "章节 '$section' 缺失"
  fi
done

# ── C2: 源文件规模 ──────────────────────────────────────

printf "\n${BOLD}C2: 源文件规模${NC}\n"

PAS_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.tls*.pas' | wc -l)
INC_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.tls*.inc' | wc -l)
TOTAL=$((PAS_COUNT + INC_COUNT))
ok "源文件: $PAS_COUNT .pas + $INC_COUNT .inc = $TOTAL 个"

if [ "$TOTAL" -lt 200 ]; then
  warn_check "文件数 ($TOTAL) 低于契约声明 (231)"
fi

# ── C3: 核心接口 ────────────────────────────────────────

printf "\n${BOLD}C3: 核心接口${NC}\n"

for iface in "ISSLContext" "ISSLConnection" "ISSLCertificate"; do
  if grep -rql "\b$iface\b" "$SRC_DIR"/nextpas.core.tls*.pas 2>/dev/null; then
    ok "接口: $iface"
  else
    fail_check "接口缺失: $iface"
  fi
done

# ISSLContext methods
for method in "CreateConnection" "LoadCertificate" "SetVerifyMode" "SetALPNProtocols" "LoadPrivateKey"; do
  if grep -rql "\b$method\b" "$SRC_DIR"/nextpas.core.tls*.pas 2>/dev/null; then
    ok "ISSLContext.$method"
  else
    warn_check "ISSLContext.$method 未发现"
  fi
done

# ISSLConnection methods
for method in "Read" "Write" "Close" "DoHandshake" "Connect"; do
  if grep -rql "\b$method\b" "$SRC_DIR"/nextpas.core.tls*.pas 2>/dev/null; then
    ok "ISSLConnection.$method"
  else
    warn_check "ISSLConnection.$method 未发现"
  fi
done

# ── C4: 平台后端 ────────────────────────────────────────

printf "\n${BOLD}C4: 平台后端${NC}\n"

for backend in "openssl" "winssl" "freepascal" "wolfssl" "mbedtls"; do
  COUNT=$(find "$SRC_DIR" -name "nextpas.core.tls.$backend.*.pas" 2>/dev/null | wc -l)
  if [ "$COUNT" -gt 0 ]; then
    ok "后端 $backend: $COUNT 文件"
  else
    warn_check "后端 $backend: 未发现文件"
  fi
done

# ── C5: TLS 1.3 协议栈 ──────────────────────────────────

printf "\n${BOLD}C5: TLS 1.3 协议栈${NC}\n"

TLS13_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.tls.tls13*.pas' 2>/dev/null | wc -l)
if [ "$TLS13_COUNT" -gt 0 ]; then
  ok "TLS 1.3 子模块: $TLS13_COUNT 文件"
else
  fail_check "TLS 1.3 子模块缺失"
fi

# 关键 TLS 1.3 组件
for comp in "keyschedule" "aead" "handshake" "record"; do
  if find "$SRC_DIR" -name "nextpas.core.tls.tls13*$comp*.pas" 2>/dev/null | grep -q .; then
    ok "TLS 1.3: $comp"
  else
    warn_check "TLS 1.3: $comp 未发现"
  fi
done

# ── C6: 错误类型 ────────────────────────────────────────

printf "\n${BOLD}C6: 错误类型${NC}\n"

if grep -rql "\bESSLException\b" "$SRC_DIR"/nextpas.core.tls*.pas 2>/dev/null; then
  ok "ESSLException"
else
  warn_check "ESSLException 未发现"
fi

# ── C7: 证书基础设施 ────────────────────────────────────

printf "\n${BOLD}C7: 证书基础设施${NC}\n"

CERT_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.tls.cert*.pas' 2>/dev/null | wc -l)
if [ "$CERT_COUNT" -gt 0 ]; then
  ok "证书子模块: $CERT_COUNT 文件"
else
  warn_check "证书子模块缺失"
fi

# OCSP/CT/DANE
for feat in "ocsp" "ct." "dane"; do
  if find "$SRC_DIR" -name "nextpas.core.tls.$feat*.pas" 2>/dev/null | grep -q .; then
    ok "特性: $feat"
  else
    warn_check "特性缺失: $feat"
  fi
done

# ── C8: 门面单元 ────────────────────────────────────────

printf "\n${BOLD}C8: 门面单元${NC}\n"

FACADE="$SRC_DIR/nextpas.core.tls.pas"
if [ -f "$FACADE" ]; then
  ok "门面文件存在"
else
  fail_check "tls.pas 门面缺失"
fi

# ── C9: 测试完备性 ──────────────────────────────────────

printf "\n${BOLD}C9: 测试完备性${NC}\n"

TEST_DIR_COUNT=$(find "$TEST_DIR" -mindepth 1 -maxdepth 1 -type d -name 'test_*' -exec basename {} \; 2>/dev/null | wc -l)
TEST_FILE_COUNT=$(find "$TEST_DIR" -maxdepth 1 -name 'test_*.pas' 2>/dev/null | wc -l)
TEST_TOTAL=$((TEST_DIR_COUNT + TEST_FILE_COUNT))
ok "测试: $TEST_DIR_COUNT 目录 + $TEST_FILE_COUNT 文件 = $TEST_TOTAL 个"

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
