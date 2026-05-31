#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

if [[ ! -f "scripts/run_freepascal_tls13_completeness_gate.sh" ]]; then
  echo "[FAIL] scripts/run_freepascal_tls13_completeness_gate.sh must exist"
  exit 1
fi

set +e
output="$(bash scripts/run_freepascal_tls13_completeness_gate.sh --dry-run --fast-local 2>&1)"
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "[FAIL] freepascal tls13 completeness gate dry-run should exit 0 (got: $exit_code)"
  printf '%s\n' "$output"
  exit 1
fi

for expected in \
  "tests/test_tls13_posthandshake.pas" \
  "tests/test_tls13_resumption.pas" \
  "tests/test_rfc8448_psk_binder.pas" \
  "tests/test_tls13_clienthello_parser.pas" \
  "tests/test_tls13_servercertverify.pas" \
  "tests/test_freepascal_revocation_fast_contracts.pas" \
  "tests/test_freepascal_client_certificateverify_runtime.pas" \
  "tests/test_freepascal_client_chain_trust_runtime.pas" \
  "tests/test_freepascal_client_ocsp_stapling_runtime.pas" \
  "tests/test_freepascal_server_ocsp_stapling_runtime.pas" \
  "tests/test_freepascal_client_online_ocsp_runtime.pas" \
  "tests/test_freepascal_client_ct_sct_surface.pas" \
  "tests/test_freepascal_client_cert_verify_flags_runtime.pas" \
  "tests/test_freepascal_client_session_resumption.pas" \
  "tests/test_freepascal_server_session_resumption.pas" \
  "tests/test_freepascal_tls13_early_data.pas" \
  "tests/test_freepascal_backend_basic.pas" \
  "tests/test_capability_cache.pas"
do
  if ! grep -Fq -- "$expected" <<< "$output"; then
    echo "[FAIL] dry-run output must mention $expected"
    printf '%s\n' "$output"
    exit 1
  fi
done

if ! grep -Fq -- "tmp/freepascal_tls13_completeness_" <<< "$output"; then
  echo "[FAIL] fast-local dry-run must keep binaries under tmp/freepascal_tls13_completeness_<run_id>"
  printf '%s\n' "$output"
  exit 1
fi

ci_completeness_job="$(
  python3 - <<'PY'
from pathlib import Path
import re
import sys

text = Path(".github/workflows/ci.yml").read_text(encoding="utf-8")
job_match = re.search(
    r"(?ms)^  freepascal-tls13-completeness:\n(?P<body>.*?)(?=^  [a-z0-9][a-z0-9_-]*:\n|\Z)",
    text,
)
if not job_match:
    sys.exit(1)

install_match = re.search(
    r"(?ms)^      - name: Install Free Pascal and OpenSSL\n(?P<body>.*?)(?=^      - name: |\Z)",
    job_match.group("body"),
)
if not install_match:
    sys.exit(2)

print(install_match.group("body"), end="")
PY
)"
ci_extract_status=$?

if [[ "$ci_extract_status" -eq 1 ]]; then
  echo "[FAIL] ci.yml must define the freepascal-tls13-completeness job"
  exit 1
fi

if [[ "$ci_extract_status" -eq 2 ]]; then
  echo "[FAIL] ci.yml completeness job must keep an explicit Install Free Pascal and OpenSSL step"
  exit 1
fi

if ! grep -Fq -- "scripts/run_freepascal_tls13_completeness_gate.sh" ".github/workflows/ci.yml"; then
  echo "[FAIL] ci.yml must call scripts/run_freepascal_tls13_completeness_gate.sh"
  exit 1
fi

if ! grep -Fq -- "libwolfssl-dev" <<< "$ci_completeness_job"; then
  echo "[FAIL] ci.yml completeness job install step must include libwolfssl-dev for WolfSSL-backed runtime coverage"
  printf '%s\n' "$ci_completeness_job"
  exit 1
fi

if ! grep -Fq -- "libmbedtls-dev" <<< "$ci_completeness_job"; then
  echo "[FAIL] ci.yml completeness job install step must include libmbedtls-dev for MbedTLS-backed runtime coverage"
  printf '%s\n' "$ci_completeness_job"
  exit 1
fi

if ! grep -Fq -- "procedure TestALPNAndSNISelection;" "tests/test_freepascal_client_session_resumption.pas"; then
  echo "[FAIL] client session resumption runtime proof must include the ALPN/SNI selection test"
  exit 1
fi

for expected in \
  "LCtx.SetALPNProtocols('h2,http/1.1');" \
  "TOfflineTLS13ServerStream.CreateInitial(" \
  "function CaptureSelectedALPN(const ALabel: string; AConn: ISSLConnection): string;" \
  "Result := LConnInfoAccess.GetSelectedALPNProtocol;" \
  "AssertTrue(CaptureSelectedALPN('ALPN handshake', LConn) = 'http/1.1'" \
  "AssertTrue(LInfo.ALPNProtocol = 'http/1.1'" \
  "AssertTrue(CaptureSelectedALPN('ALPN no-overlap handshake', LConnNoOverlap) = ''" \
  "AssertTrue(LInfoNoOverlap.ALPNProtocol = ''"
do
  if ! grep -Fq -- "$expected" "tests/test_freepascal_client_session_resumption.pas"; then
    echo "[FAIL] client session resumption runtime proof missing ALPN/SNI assertion: $expected"
    exit 1
  fi
done

if ! grep -Fq -- "procedure RunServerAcceptSkeletonCase(" "tests/test_freepascal_server_accept_skeleton.pas"; then
  echo "[FAIL] server accept skeleton runtime proof must include the ALPN selection helper"
  exit 1
fi

for expected in \
  "LCtx.SetALPNProtocols('h2,http/1.1');" \
  "RunServerAcceptSkeletonCase('http/1.1', 'http/1.1');" \
  "RunServerAcceptSkeletonCase('spdy/3', '');" \
  "function CaptureSelectedALPN(AConn: ISSLConnection): string;" \
  "Result := LConnInfoAccess.GetSelectedALPNProtocol;" \
  "AssertTrue(CaptureSelectedALPN(LConn) = AExpectedNegotiatedALPN" \
  "AssertTrue(LInfo.ALPNProtocol = AExpectedNegotiatedALPN"
do
  if ! grep -Fq -- "$expected" "tests/test_freepascal_server_accept_skeleton.pas"; then
    echo "[FAIL] server accept skeleton runtime proof missing ALPN assertion: $expected"
    exit 1
  fi
done

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/tls13_gate_contract.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

fake_bin="$tmp_root/bin"
marker_file="$tmp_root/fake_fpc_marker.log"
run_id="contract_fake_fpc_path"
summary_file="$PROJECT_ROOT/tmp/test-reports/freepascal_tls13_completeness_${run_id}.md"

mkdir -p "$fake_bin"

cat > "$fake_bin/fpc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

marker="${FAFAFA_FAKE_FPC_MARKER:?}"
printf '%s\n' "$*" >> "$marker"

out_path=""
for arg in "$@"; do
  case "$arg" in
    -o*)
      out_path="${arg#-o}"
      ;;
  esac
done

if [[ -z "$out_path" ]]; then
  echo "[FAIL] fake fpc expected -o<path>" >&2
  exit 1
fi

mkdir -p "$(dirname "$out_path")"
cat > "$out_path" <<'INNER'
#!/usr/bin/env bash
exit 0
INNER
chmod +x "$out_path"
EOF
chmod +x "$fake_bin/fpc"

rm -f "$summary_file"

set +e
path_output="$(
  cd "$PROJECT_ROOT" && \
  PATH="$fake_bin:$PATH" \
  FAFAFA_FAKE_FPC_MARKER="$marker_file" \
  bash scripts/run_freepascal_tls13_completeness_gate.sh \
    --fast-local \
    --run-id "$run_id" \
    --reports-dir tmp/test-reports 2>&1
)"
path_exit_code=$?
set -e

if [[ "$path_exit_code" -ne 0 ]]; then
  echo "[FAIL] gate should preserve current PATH for FPC resolution (got: $path_exit_code)"
  printf '%s\n' "$path_output"
  exit 1
fi

if [[ ! -f "$marker_file" ]]; then
  echo "[FAIL] gate must use PATH-resolved fake fpc during execution"
  printf '%s\n' "$path_output"
  exit 1
fi

marker_lines="$(wc -l < "$marker_file" | tr -d ' ')"
if [[ "$marker_lines" -ne 18 ]]; then
  echo "[FAIL] gate should invoke fake fpc 18 times (got: $marker_lines)"
  cat "$marker_file"
  exit 1
fi

if [[ ! -f "$summary_file" ]]; then
  echo "[FAIL] gate should write summary report to $summary_file"
  printf '%s\n' "$path_output"
  exit 1
fi

if ! grep -Fq -- "| \`test_freepascal_client_certificateverify_runtime\` | PASS |" "$summary_file"; then
  echo "[FAIL] summary report must record the CertificateVerify runtime PASS row when fake fpc executions succeed"
  cat "$summary_file"
  exit 1
fi

if ! grep -Fq -- "| \`test_rfc8448_psk_binder\` | PASS |" "$summary_file"; then
  echo "[FAIL] summary report must record the RFC 8448 PSK binder PASS row when fake fpc executions succeed"
  cat "$summary_file"
  exit 1
fi

if ! grep -Fq -- "| \`test_freepascal_revocation_fast_contracts\` | PASS |" "$summary_file"; then
  echo "[FAIL] summary report must record the fast revocation contract PASS row when fake fpc executions succeed"
  cat "$summary_file"
  exit 1
fi

if ! grep -Fq -- "| \`test_freepascal_client_cert_verify_flags_runtime\` | PASS |" "$summary_file"; then
  echo "[FAIL] summary report must record the cert-verify-flags runtime PASS row when fake fpc executions succeed"
  cat "$summary_file"
  exit 1
fi

if ! grep -Fq -- "| \`test_freepascal_server_ocsp_stapling_runtime\` | PASS |" "$summary_file"; then
  echo "[FAIL] summary report must record the server OCSP stapling runtime PASS row when fake fpc executions succeed"
  cat "$summary_file"
  exit 1
fi

echo "[PASS] freepascal tls13 completeness gate contract is wired into script + CI"
