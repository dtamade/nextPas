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
  if rg -n -P --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
    pass "$name"
  else
    fail "$name" "pattern not found in $file: $pattern"
  fi
}

proof_file="tests/winssl/test_winssl_session_resumption.pas"

printf '[TEST] WinSSL native-probe worker evidence-only contract\n'

require_match "$proof_file" \
  'LRequireNativeReuse := EnvEnabled\(\x27FAFAFA_WINSSL_REQUIRE_NATIVE_REUSE\x27\);' \
  'WinSSL proof still exposes an explicit strict native-reuse env gate'

require_match "$proof_file" \
  'if LRequireNativeReuse then\s*Check\(\x27isolated native probe worker exits cleanly\x27,\s*LWorkerExitCode = 0,' \
  'WinSSL proof keeps strict worker-exit enforcement when native reuse truth is required'

require_match "$proof_file" \
  'else\s*Check\(\x27isolated native probe worker evidence recorded\x27,\s*True,' \
  'WinSSL proof downgrades worker nonzero exit to evidence-only when strict native reuse is not required'

require_match "$proof_file" \
  'native_probe_worker exit_code=%d probe_succeeded=%s observed_reuse=%s last_marker=%s' \
  'WinSSL proof still emits the worker exit evidence marker even in evidence-only mode'

printf '[PASS] WinSSL native-probe worker evidence-only contract passed\n'
