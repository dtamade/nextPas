#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

ocsp_guide="docs/guides/OCSP_USAGE_GUIDE.md"
ct_guide="docs/guides/CT_IMPLEMENTATION_GUIDE.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if ! rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_absent() {
  local needle="$1"
  local file="$2"
  local message="$3"

  if rg -F -n --quiet -- "$needle" "$file"; then
    echo "[FAIL] $message"
    exit 1
  fi
}

require_fixed '这里直接回到 `CreateConnection(...)`，是因为 stapled OCSP runtime state 通过 `ISSLOCSPStapling` 挂在连接对象上，握手失败时的 verify 结果也通过 `ISSLCertificateVerification` 从连接侧读取；如果你只是普通客户端接入而不需要这层 owner surface，握手入口仍可保持在 `TSSLConnector` / `TSSLStream`。' \
  "$ocsp_guide" \
  "OCSP_USAGE_GUIDE must explain why it intentionally uses the connection owner path"
require_fixed "  fafafa.ssl," \
  "$ocsp_guide" \
  "OCSP_USAGE_GUIDE must use the current public facade unit in active OCSP examples"
require_fixed "  nextpas.core.tls.context.builder;" \
  "$ocsp_guide" \
  "OCSP_USAGE_GUIDE must keep the builder unit where TSSLContextBuilder is referenced"
require_absent "  nextpas.core.tls.base," \
  "$ocsp_guide" \
  "OCSP_USAGE_GUIDE must stop teaching split base-unit imports in active examples"

require_fixed '这里直接回到 `CreateConnection(...)`，是因为 `ISSLCertificateTransparency` / `ISSLCertificateTransparencyValidation` 这组 CT runtime owner surface 挂在连接对象上；如果你只是普通客户端接入而不需要读取 CT owner surface，握手入口仍可保持在 `TSSLConnector` / `TSSLStream`。' \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must explain why it intentionally uses the connection owner path"
require_fixed "**版本**: rolling" \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must declare rolling version instead of a stale 1.0 snapshot"
require_fixed "**最后更新**: 2026-05-21" \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must refresh its active update date"
require_fixed "**适用范围**: 当前 fafafa.ssl active CT runtime / validator / log-client guidance" \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must classify itself as current active CT guidance instead of a frozen v1.0 page"
require_fixed "  fafafa.ssl," \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must use the current public facade unit in active CT examples"
require_fixed "  nextpas.core.tls.context.builder;" \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must keep the builder unit where TSSLContextBuilder is referenced"
require_absent "**版本**: 1.0" \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must stop advertising stale 1.0 version"
require_absent "**创建日期**: 2026-01-30" \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must stop advertising stale creation-date snapshot as current guidance"
require_absent "**适用于**: fafafa.ssl v1.0+" \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must stop advertising stale v1.0 applicability as current guidance"
require_absent "  nextpas.core.tls.base," \
  "$ct_guide" \
  "CT_IMPLEMENTATION_GUIDE must stop teaching split base-unit imports in active examples"

echo "[PASS] specialized guides explain why they intentionally use connection owner paths"
