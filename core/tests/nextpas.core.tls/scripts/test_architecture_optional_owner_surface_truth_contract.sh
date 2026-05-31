#!/usr/bin/env bash
set -euo pipefail

doc="docs/ARCHITECTURE.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"
  if ! grep -Fq "$needle" "$file"; then
    echo "[FAIL] $message"
    echo "  missing: $needle"
    echo "  file: $file"
    exit 1
  fi
}

forbid_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"
  if grep -Fq "$needle" "$file"; then
    echo "[FAIL] $message"
    echo "  unexpected: $needle"
    echo "  file: $file"
    exit 1
  fi
}

require_fixed '├─ ISSLConnectionControl   (timeout / blocking owner)' \
  "$doc" \
  "ARCHITECTURE interface graph must include ISSLConnectionControl"
require_fixed '├─ ISSLConnectionTextIO    (文本 helper owner)' \
  "$doc" \
  "ARCHITECTURE interface graph must include ISSLConnectionTextIO"
require_fixed '├─ ISSLConnectionInfo      (连接信息 mirrors)' \
  "$doc" \
  "ARCHITECTURE interface graph must include ISSLConnectionInfo"
require_fixed '├─ ISSLDiagnostics         (诊断扩展)' \
  "$doc" \
  "ARCHITECTURE interface graph must include ISSLDiagnostics"
require_fixed '├─ ISSLSessionResumption   (会话扩展)' \
  "$doc" \
  "ARCHITECTURE interface graph must include ISSLSessionResumption"
require_fixed '├─ ISSLCertificateVerification (证书验证扩展)' \
  "$doc" \
  "ARCHITECTURE interface graph must include ISSLCertificateVerification"
require_fixed '└─ ISSLOCSPStapling        (OCSP 扩展)' \
  "$doc" \
  "ARCHITECTURE interface graph must include ISSLOCSPStapling"

require_fixed 'connection-side owner surfaces 当前主要通过这些可选接口暴露：' \
  "$doc" \
  "ARCHITECTURE must explicitly classify connection-side owner surfaces"
require_fixed '`ISSLConnectionControl`：timeout / blocking runtime control owner' \
  "$doc" \
  "ARCHITECTURE must classify ISSLConnectionControl as runtime owner"
require_fixed '`ISSLConnectionTextIO`：text helper owner；框架/transport 集成仍优先使用 `Read` / `Write`' \
  "$doc" \
  "ARCHITECTURE must classify ISSLConnectionTextIO as text-helper owner"
require_fixed '`ISSLConnectionInfo`：connection info / ALPN / context / state-string mirrors 的默认 owner' \
  "$doc" \
  "ARCHITECTURE must classify ISSLConnectionInfo as mirror owner"
require_fixed '`ISSLDiagnostics` / `ISSLSessionResumption` / `ISSLCertificateVerification` / `ISSLOCSPStapling`：其余 connection-side optional owners' \
  "$doc" \
  "ARCHITECTURE must classify the remaining connection-side owners"

require_fixed '后端按 capability / runtime truth 暴露 optional interface，' \
  "$doc" \
  "ARCHITECTURE must explain capability-gated optional interface exposure"
require_fixed '不是每个 backend / class 都统一实现全部 optional surfaces。' \
  "$doc" \
  "ARCHITECTURE must reject the all-optionals-on-every-backend story"

forbid_fixed '每个后端实现所有核心接口 + 可选接口：' \
  "$doc" \
  "ARCHITECTURE still claims every backend implements every optional interface"

echo "[PASS] ARCHITECTURE optional owner-surface truth contract passed"
