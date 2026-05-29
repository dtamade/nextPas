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

require_fixed '## 当前路线与演进边界' \
  "$doc" \
  "ARCHITECTURE must carry a current-route boundary section"
require_fixed '当前执行顺序与产品路线以 [ROADMAP.md](ROADMAP.md) 为准。' \
  "$doc" \
  "ARCHITECTURE must point route decisions back to ROADMAP"
require_fixed '当前 release/runtime 结论请看 [test_reports/RELEASE_READINESS_V1.5.0.md](test_reports/RELEASE_READINESS_V1.5.0.md)。' \
  "$doc" \
  "ARCHITECTURE must point release truth back to the release-readiness report"
require_fixed '当前下一条更大的 completeness 主线，继续以 [plans/2026-03-25-ssl-tls-backend-completeness-roadmap-and-freepascal-tls13-aes256-sha384-parity.md](plans/2026-03-25-ssl-tls-backend-completeness-roadmap-and-freepascal-tls13-aes256-sha384-parity.md) 为候选入口。' \
  "$doc" \
  "ARCHITECTURE must point implementation follow-up back to the current completeness roadmap"

forbid_fixed '## 未来架构演进' \
  "$doc" \
  "ARCHITECTURE still presents a stale future-architecture roadmap section"
forbid_fixed '### 短期（v1.2-v1.3）' \
  "$doc" \
  "ARCHITECTURE still keeps the stale short-term version bucket"
forbid_fixed '### 中期（v2.0）' \
  "$doc" \
  "ARCHITECTURE still keeps the stale mid-term version bucket"
forbid_fixed '### 长期（v3.0）' \
  "$doc" \
  "ARCHITECTURE still keeps the stale long-term version bucket"

echo "[PASS] ARCHITECTURE current route truth contract passed"
