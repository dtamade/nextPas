#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_match() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    fail "$name" "unexpected pattern found in $file: $pattern"
  else
    pass "$name"
  fi
}

proof_file="tests/winssl/test_winssl_integration_multi.pas"

printf '[TEST] WinSSL integration-multi HTTP status contract\n'

require_match "$proof_file" \
  'function TryExtractHTTPStatusCode\(' \
  'integration-multi test defines an HTTP status parser helper'

require_match "$proof_file" \
  '响应状态码可解析' \
  'integration-multi test explicitly records whether the HTTP status line is parseable'

require_match "$proof_file" \
  '响应状态码不是 5xx' \
  'integration-multi test treats non-5xx HTTP responses as acceptable transport-level success'

require_absent "$proof_file" \
  '响应状态码正常 \(2xx/3xx\)' \
  'integration-multi test no longer hardcodes a 2xx/3xx-only assertion for external hosts'

printf '[PASS] WinSSL integration-multi HTTP status contract passed\n'
