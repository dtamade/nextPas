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

base_file="src/nextpas.core.tls.winssl.base.pas"
connection_file="src/nextpas.core.tls.winssl.connection.pas"
suite_file="tests/run_winssl_tests.ps1"
proof_file="tests/winssl/test_winssl_session_resumption.pas"
checklist_file="tests/windows/WINDOWS_VALIDATION_CHECKLIST.md"
bundle_file="tests/windows/VALIDATION_BUNDLE.md"

printf '[TEST] WinSSL session-resumption runtime-truth contract\n'

require_match "$base_file" \
  'SSL_SESSION_RECONNECT\s*=\s*1;' \
  'WinSSL base defines the Schannel reconnect session flag'

require_match "$connection_file" \
  'function TWinSSLConnection\.TryGetCurrentSessionInfo\(' \
  'WinSSL connection owns a dedicated current-session-info helper'

require_match "$connection_file" \
  'QueryContextAttributesW\(@FCtxtHandle,\s*SECPKG_ATTR_SESSION_INFO,\s*@ASessionInfo\)' \
  'WinSSL connection reads Schannel session info from the live context'

require_match "$connection_file" \
  'function TWinSSLConnection\.TryGetCurrentSessionInfo\(.*?try.*?QueryContextAttributesW\(@FCtxtHandle,\s*SECPKG_ATTR_SESSION_INFO,\s*@ASessionInfo\).*?except.*?Result := False;' \
  'WinSSL current-session-info helper degrades to false instead of propagating runtime exceptions'

require_match "$connection_file" \
  'procedure TWinSSLConnection\.UpdateSessionReuseTruthFromContext\(.*?ASessionId := \x27\x27;.*?FSessionReused := False;.*?SECPKG_ATTR_SESSION_INFO probe on canonical shared handshake paths.*?reused = False.*?session_id = \x27\x27.*?existing fallback session-id generators' \
  'WinSSL canonical shared paths stay off live session-info probing until Windows runtime proof is safe'

require_match "$connection_file" \
  'LSession\.SetSessionMetadata\(LSessionID,\s*LProtocol,\s*LCipher,\s*FSessionReused\);' \
  'saved WinSSL session metadata now carries the actual resumed-handshake flag'

require_match "$connection_file" \
  'function TWinSSLConnection\.DoConnect: Boolean;.*?SaveSessionAfterHandshake;' \
  'client Connect path saves WinSSL session metadata after a successful handshake'

require_match "$connection_file" \
  'function TWinSSLConnection\.PerformHandshake: TSSLHandshakeState;.*?SaveSessionAfterHandshake;' \
  'generic WinSSL handshake path also saves session metadata'

require_match "$connection_file" \
  'Result\.IsResumed := FSessionReused;' \
  'GetConnectionInfo still mirrors the connection-level reuse truth'

require_match "$suite_file" \
  'test_winssl_session_resumption\.lpi' \
  'broader WinSSL runtime suite includes the session-resumption proof lane'

require_match "$suite_file" \
  'FAFAFA_RUN_NETWORK_TESTS = "1"' \
  'session-resumption lane opts into the real network path'

require_match "$suite_file" \
  '\[WINSSL-SESSION-RESUME\]' \
  'broader suite promotes session-resumption proof markers into runtime evidence'

require_match "$proof_file" \
  '\[WINSSL-SESSION-RESUME\]' \
  'WinSSL session-resumption proof program emits stable session-resume markers'

require_match "$proof_file" \
  'function TryQueryNativeSessionReuse\(const AConn: ISSLConnection;.*?ISSLNativeHandleAccess.*?GetNativeHandle.*?TryQueryCurrentSessionInfoWithSizedBuffer\(LCtxtHandle,\s*LSessionInfo,\s*LStatus,\s*LUsedQueryEx\).*?SSL_SESSION_RECONNECT' \
  'WinSSL session-resumption proof owns a dedicated native session-reuse probe'

require_match "$proof_file" \
  'GetConnectionInfo' \
  'WinSSL session-resumption proof checks connection-info reuse truth'

require_match "$proof_file" \
  'GetPerformanceMetrics' \
  'WinSSL session-resumption proof checks performance-metric reuse truth'

require_match "$proof_file" \
  'FAFAFA_WINSSL_REQUIRE_REUSE' \
  'WinSSL session-resumption proof supports a strict reuse-observed mode'

require_match "$proof_file" \
  'FAFAFA_WINSSL_REQUIRE_NATIVE_REUSE' \
  'WinSSL session-resumption proof supports a strict native-reuse-observed mode'

require_match "$proof_file" \
  'FAFAFA_WINSSL_ENABLE_NATIVE_PROBE' \
  'WinSSL session-resumption proof gates the native probe behind an explicit opt-in switch'

require_match "$proof_file" \
  'native_probe label=initial_handshake' \
  'WinSSL session-resumption proof emits native-probe evidence for the initial handshake'

require_match "$proof_file" \
  'native_probe label=same_context_attempt_%d' \
  'WinSSL session-resumption proof emits native-probe evidence for resumed attempts'

require_match "$proof_file" \
  'native_probe_enabled=%s native_observed_reuse=%s native_probe_succeeded=%s require_reuse=%s require_native_reuse=%s session_configured=%s' \
  'WinSSL session-resumption summary separates public reuse truth from native probe truth'

require_match "$proof_file" \
  'reason=disabled_by_default' \
  'WinSSL session-resumption proof keeps the risky native probe disabled by default on the broader suite lane'

require_match "$checklist_file" \
  'test_winssl_session_resumption\.lpi' \
  'Windows checklist names the dedicated session-resumption proof project'

require_match "$checklist_file" \
  '\[WINSSL-RUNTIME\] session_resumption summary' \
  'Windows checklist documents the promoted session-resumption runtime marker'

require_match "$bundle_file" \
  'test_winssl_session_resumption\.lpi' \
  'validation bundle inventory includes the session-resumption proof project'

require_match "$bundle_file" \
  '\[WINSSL-RUNTIME\] session_resumption summary' \
  'validation bundle inventory documents the promoted session-resumption marker'

printf '[PASS] WinSSL session-resumption runtime-truth contract passed\n'
