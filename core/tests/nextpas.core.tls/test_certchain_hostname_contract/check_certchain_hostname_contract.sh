#!/usr/bin/env bash
# 契约：TSSLCertificateChainVerifier.MatchHostname 的通配符分支必须
# 先按 '.' 拆分 CertParts/HostParts 再比较。
#
# 回归背景：CertParts/HostParts 曾只声明未赋值，Length(空数组) =
# Length(空数组) 恒为真、循环体不执行，任何 "*." 前缀证书名都会匹配
# 任意主机名（SAN 与 CN 两条路径同时失效）。
set -euo pipefail

cd "$(dirname "$0")"

SRC=../../../src/nextpas.core.tls.certchain.pas

if [ ! -f "$SRC" ]; then
  echo "FAIL: source not found: $SRC" >&2
  exit 1
fi

# 提取 MatchHostname 函数体（从函数头到第一个顶格 end;）
BODY=$(awk '
  /^function TSSLCertificateChainVerifier\.MatchHostname\(/ {flag=1}
  flag {print}
  flag && /^end;$/ {exit}
' "$SRC")

if [ -z "$BODY" ]; then
  echo "FAIL: cannot locate MatchHostname body in $SRC" >&2
  exit 1
fi

fail() { echo "FAIL: $1" >&2; exit 1; }

echo "$BODY" | grep -q 'CertParts :=' || fail "MatchHostname 未给 CertParts 赋值"
echo "$BODY" | grep -q 'HostParts :=' || fail "MatchHostname 未给 HostParts 赋值"
echo "$BODY" | grep 'CertParts :=' | grep -q 'StringsSplit' || fail "CertParts 拆分未使用 StringsSplit"
echo "$BODY" | grep 'HostParts :=' | grep -q 'StringsSplit' || fail "HostParts 拆分未使用 StringsSplit"

SPLIT_LINE=$(echo "$BODY" | grep -n 'HostParts :=' | head -1 | cut -d: -f1)
CMP_LINE=$(echo "$BODY" | grep -n 'Length(CertParts) = Length(HostParts)' | head -1 | cut -d: -f1)

[ -n "$CMP_LINE" ] || fail "未找到域名级数比较行（函数体结构变化，需人工复核契约）"
[ "$SPLIT_LINE" -lt "$CMP_LINE" ] || fail "拆分必须发生在级数比较之前"

echo "PASS: MatchHostname 通配符分支先拆分后比较（certchain hostname contract）"
