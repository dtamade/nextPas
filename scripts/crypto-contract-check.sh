#!/usr/bin/env bash

# crypto-contract-check.sh — crypto 模块契约完备性门禁
# 用法: scripts/crypto-contract-check.sh
# 退出码: 0 = 全通过, 1 = 有违规, 2 = 用法错误

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
REPO_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CONTRACT="$REPO_ROOT/core/docs/crypto/CONTRACT.md"
SRC_DIR="$REPO_ROOT/core/src"
TEST_DIR="$REPO_ROOT/core/tests/nextpas.core.crypto"

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

# ── C2: 源文件规模 ──────────────────────────────────────

printf "\n${BOLD}C2: 源文件规模${NC}\n"

PAS_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.crypto*.pas' | wc -l)
INC_COUNT=$(find "$SRC_DIR" -name 'nextpas.core.crypto*.inc' | wc -l)
TOTAL=$((PAS_COUNT + INC_COUNT))
ok "源文件: $PAS_COUNT .pas + $INC_COUNT .inc = $TOTAL 个"

# ── C3: 核心算法域 ──────────────────────────────────────

printf "\n${BOLD}C3: 核心算法域${NC}\n"

# Hash algorithms
for alg in "SHA256" "SHA512" "SHA1" "MD5"; do
  if grep -rql "\b$alg\b" "$SRC_DIR"/nextpas.core.crypto*.pas 2>/dev/null; then
    ok "Hash: $alg"
  else
    warn_check "Hash 未发现: $alg"
  fi
done

# HMAC
for alg in "HMAC" "HKDF" "PBKDF2"; do
  if grep -rql "\b$alg\b" "$SRC_DIR"/nextpas.core.crypto*.pas 2>/dev/null; then
    ok "HMAC: $alg"
  else
    warn_check "HMAC 未发现: $alg"
  fi
done

# AES
for alg in "AESCBC" "AESGCM" "AESNI" "aes.ct64"; do
  if grep -rql "$alg" "$SRC_DIR"/nextpas.core.crypto*.pas 2>/dev/null; then
    ok "AES: $alg"
  else
    warn_check "AES 未发现: $alg"
  fi
done

# ChaCha20
if grep -rql "ChaCha20\|CHACHA20" "$SRC_DIR"/nextpas.core.crypto*.pas 2>/dev/null; then
  ok "ChaCha20-Poly1305"
else
  warn_check "ChaCha20 未发现"
fi

# ── C4: 公钥密码学 ──────────────────────────────────────

printf "\n${BOLD}C4: 公钥密码学${NC}\n"

for alg in "RSA" "ECDSA" "Ed25519" "X25519" "P256" "P384"; do
  if grep -rql "$alg" "$SRC_DIR"/nextpas.core.crypto*.pas 2>/dev/null; then
    ok "公钥: $alg"
  else
    warn_check "公钥未发现: $alg"
  fi
done

# ── C5: 密钥派生 ────────────────────────────────────────

printf "\n${BOLD}C5: 密钥派生${NC}\n"

for fn in "PBKDF2" "HKDF" "Argon2"; do
  if grep -rql "\b$fn\b" "$SRC_DIR"/nextpas.core.crypto*.pas 2>/dev/null; then
    ok "密钥派生: $fn"
  else
    warn_check "密钥派生未发现: $fn"
  fi
done

# ── C6: 安全工具 ────────────────────────────────────────

printf "\n${BOLD}C6: 安全工具${NC}\n"

if grep -rql "ConstantTime\|SecureZero" "$SRC_DIR"/nextpas.core.crypto*.pas 2>/dev/null; then
  ok "常量时间/安全擦除"
else
  warn_check "安全工具未发现"
fi

# ── C7: 子模块文件完备性 ────────────────────────────────

printf "\n${BOLD}C7: 子模块文件完备性${NC}\n"

CORE_FILES=("nextpas.core.crypto.pas" "nextpas.core.crypto.hash.pas" "nextpas.core.crypto.hmac.pas"
            "nextpas.core.crypto.aescbc.pas" "nextpas.core.crypto.aesgcm.pas"
            "nextpas.core.crypto.constant_time.pas" "nextpas.core.crypto.pbkdf2.pas"
            "nextpas.core.crypto.rsa.pas" "nextpas.core.crypto.ed25519.pas"
            "nextpas.core.crypto.x25519.pas" "nextpas.core.crypto.bigint.pas")
for f in "${CORE_FILES[@]}"; do
  if [ -f "$SRC_DIR/$f" ]; then
    ok "文件: $f"
  else
    fail_check "文件缺失: $f"
  fi
done

# ── C8: 门面单元 ────────────────────────────────────────

printf "\n${BOLD}C8: 门面单元${NC}\n"

FACADE="$SRC_DIR/nextpas.core.crypto.pas"
if [ -f "$FACADE" ]; then
  ok "门面文件存在"
else
  fail_check "crypto.pas 门面缺失"
fi

# ── C9: 测试完备性 ──────────────────────────────────────

printf "\n${BOLD}C9: 测试完备性${NC}\n"

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
