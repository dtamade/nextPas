#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

require_absent() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if grep -Fq -- "$expected" "$file"; then
    fail "$name"
  fi
}

perf_guide="docs/guides/PERFORMANCE_PROFILING_GUIDE.md"
security_guide="${SECURITY_BEST_PRACTICES_DOC:-docs/guides/security-best-practices.md}"

printf '[TEST] active builder guidance truth contract\n'

require_absent "$perf_guide" '.WithSessionCache(1000)' \
  "performance profiling guide must stop teaching a fake builder size overload for session cache"
require_fixed "$perf_guide" '.WithSessionCache(True)  // 当前 builder 只控制是否启用 session cache' \
  "performance profiling guide must show the current Boolean session-cache builder entrypoint"
require_fixed "$perf_guide" 'Ctx.SetSessionCacheSize(1000);  // 如需限制缓存条目数，当前走 context API' \
  "performance profiling guide must redirect session cache sizing to ISSLContext"

require_absent "$security_guide" '.WithStrongCipherSuites' \
  "security best practices guide must stop teaching nonexistent WithStrongCipherSuites builder method"
require_absent "$security_guide" '.WithPerfectForwardSecrecy' \
  "security best practices guide must stop teaching nonexistent WithPerfectForwardSecrecy builder method"
require_absent "$security_guide" '.WithSessionCache            // 启用会话缓存' \
  "security best practices guide must stop teaching a parameterless WithSessionCache builder method"
require_absent "$security_guide" '.WithSessionTickets' \
  "security best practices guide must stop teaching nonexistent WithSessionTickets builder method"
require_absent "$security_guide" '.WithoutVerifyPeer' \
  "security best practices guide must stop teaching nonexistent WithoutVerifyPeer builder method"
require_absent "$security_guide" '.WithSSL3' \
  "security best practices guide must stop teaching nonexistent WithSSL3 builder method"
require_absent "$security_guide" '.WithTLS10' \
  "security best practices guide must stop teaching nonexistent WithTLS10 builder method"
require_absent "$security_guide" '  nextpas.core.tls.base,' \
  "security best practices guide must stop teaching nextpas.core.tls.base in active builder examples"

require_fixed "$security_guide" '.WithSafeDefaults             // 当前高入口：收紧 cipher/profile baseline' \
  "security best practices guide must redirect strong-cipher guidance to WithSafeDefaults"
require_fixed "$security_guide" '.WithSessionCache(True)               // builder 只负责开关' \
  "security best practices guide must show the current Boolean session-cache builder entrypoint"
require_fixed "$security_guide" '.WithOption(ssoEnableSessionTickets)  // ticket 当前走 option seam' \
  "security best practices guide must route session tickets through WithOption"
require_fixed "$security_guide" '.WithVerifyNone               // 危险！' \
  "security best practices guide must use the current insecure verify-disable entrypoint"
require_fixed "$security_guide" '.WithProtocols([sslProtocolSSL3, sslProtocolTLS10])' \
  "security best practices guide must use current protocol-set API for the weak-protocol anti-example"
require_fixed "$security_guide" '  fafafa.ssl,' \
  "security best practices guide must keep the current public facade import in active builder examples"

printf '[PASS] active builder guidance truth contract passed\n'
