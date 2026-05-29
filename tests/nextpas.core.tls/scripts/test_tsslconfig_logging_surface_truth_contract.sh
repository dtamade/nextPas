#!/usr/bin/env bash
set -euo pipefail

api_ref="docs/reference/API_REFERENCE.md"
arch_ref="docs/reference/ARCHITECTURE.md"
user_guide="docs/guides/USER_GUIDE.md"
troubleshooting="docs/guides/TROUBLESHOOTING.md"

require_fixed() {
  local needle="$1"
  local file="$2"
  local message="$3"
  if ! grep -Fq "$needle" "$file"; then
    echo "FAIL: $message" >&2
    echo "  missing: $needle" >&2
    echo "  file: $file" >&2
    exit 1
  fi
}

require_fixed '通过 `TSSLLibraryDefaults` + `GetLibraryDefaults(...)` / `ApplyLibraryDefaults(...)` 访问 library-owned defaults；底层仍分别落到 `SetDefaultConfig(...)` / `SetLogCallback(...)`。' \
  "$api_ref" \
  "API reference no longer explains the additive TSSLLibraryDefaults surface"

require_fixed '通过 `TSSLLibraryDefaults` + `GetLibraryDefaults(...)` / `ApplyLibraryDefaults(...)` 访问 library-owned defaults；底层仍分别落到 `SetDefaultConfig(...)` / `SetLogCallback(...)`；factory request path 不接受 request-local 覆盖。' \
  "$arch_ref" \
  "Architecture reference no longer states the split logging entrypoints"

require_fixed 'LLogDefaults := GetLibraryDefaults(LLib);' \
  "$user_guide" \
  "User guide no longer fetches TSSLLibraryDefaults before raising the log level"
require_fixed 'LLogDefaults.LogLevel := sslLogInfo;' \
  "$user_guide" \
  "User guide no longer shows LogLevel configuration for info-level logging"
require_fixed 'LLogDefaults.LogCallback := @MyLogCallback;' \
  "$user_guide" \
  "User guide no longer sets the callback through TSSLLibraryDefaults"
require_fixed 'ApplyLibraryDefaults(LLib, LLogDefaults);' \
  "$user_guide" \
  "User guide no longer applies library defaults through ApplyLibraryDefaults"

require_fixed 'LLogDefaults := GetLibraryDefaults(LLib);' \
  "$troubleshooting" \
  "Troubleshooting guide no longer fetches TSSLLibraryDefaults before raising the log level"
require_fixed 'LLogDefaults.LogLevel := sslLogDebug;' \
  "$troubleshooting" \
  "Troubleshooting guide no longer shows debug-level logging through library defaults"
require_fixed 'LLogDefaults.LogCallback := @MyLogCallback;' \
  "$troubleshooting" \
  "Troubleshooting guide no longer sets the callback through TSSLLibraryDefaults"
require_fixed 'ApplyLibraryDefaults(LLib, LLogDefaults);' \
  "$troubleshooting" \
  "Troubleshooting guide no longer applies library defaults through ApplyLibraryDefaults"

echo "PASS: TSSLConfig logging surface truth remains aligned across active docs"
