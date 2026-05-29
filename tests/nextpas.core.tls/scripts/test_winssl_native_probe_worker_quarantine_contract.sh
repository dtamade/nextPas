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

proof_file="tests/winssl/test_winssl_session_resumption.pas"

printf '[TEST] WinSSL native-probe worker quarantine contract\n'

require_match "$proof_file" \
  'FAFAFA_WINSSL_NATIVE_PROBE_CHILD' \
  'WinSSL native probe quarantine uses an explicit child-mode switch'

require_match "$proof_file" \
  'uses[\s\S]*Process' \
  'WinSSL native probe quarantine depends on TProcess support'

require_match "$proof_file" \
  'function RunIsolatedNativeProbeWorker\(const AHost: string; AAttemptCount: Integer;.*?TProcess.*?ParamStr\(0\).*?poUsePipes.*?poStderrToOutPut.*?while LProcess\.Running do.*?AppendAvailableProcessOutput\(LProcess,\s*AOutput\).*?Sleep\(10\)' \
  'WinSSL native probe quarantine launches the current proof executable as an isolated worker and drains captured output while the child is still running'

require_match "$proof_file" \
  'native_probe label=initial_handshake pending=true mode=isolated_worker' \
  'WinSSL child worker emits a pre-probe marker before the risky initial native probe call'

require_match "$proof_file" \
  'native_probe label=same_context_attempt_%d pending=true mode=isolated_worker' \
  'WinSSL child worker emits a pre-probe marker before each risky resumed-attempt native probe call'

require_match "$proof_file" \
  'native_probe_worker exit_code=%d probe_succeeded=%s observed_reuse=%s last_marker=%s' \
  'WinSSL parent worker summary records the isolated worker exit truth and last observed marker'

require_match "$proof_file" \
  'Check\('"'isolated native probe worker exits cleanly'"',\s*LWorkerExitCode = 0' \
  'WinSSL parent process turns a crashing worker into a controlled test failure instead of a silent process abort'

require_match "$proof_file" \
  'native_probe_enabled=%s native_observed_reuse=%s native_probe_succeeded=%s require_reuse=%s require_native_reuse=%s session_configured=%s' \
  'WinSSL session-resumption summary still separates public truth from native probe truth after worker quarantine'

printf '[PASS] WinSSL native-probe worker quarantine contract passed\n'
