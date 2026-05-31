#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILES=(
  "$ROOT_DIR/.github/workflows/winssl-tests.yml"
  "$ROOT_DIR/.github/workflows/winssl-tests.yml.disabled"
)

fail() {
  echo "[FAIL] $1"
  exit 1
}

for workflow_file in "${WORKFLOW_FILES[@]}"; do
  [[ -f "$workflow_file" ]] || fail "missing workflow file: ${workflow_file#$ROOT_DIR/}"

  python3 - "$workflow_file" <<'PY'
from pathlib import Path
import sys

workflow = Path(sys.argv[1])
text = workflow.read_text(encoding="utf-8")

required_fragments = [
    "name: WinSSL Runtime Gate",
    "workflow_dispatch:",
    "src/nextpas.core.tls.winssl*.pas",
    "src/nextpas.core.tls.base.pas",
    "src/nextpas.core.tls.connection.base.pas",
    "src/nextpas.core.tls.factory.pas",
    "src/nextpas.core.tls.context.config.pas",
    "src/nextpas.core.tls.asn1.pas",
    "src/nextpas.core.tls.x509.pas",
    "src/nextpas.core.tls.pas",
    "src/nextpas.core.tls.context.builder.pas",
    "examples/*winssl*.pas",
    "tests/winssl/**",
    "scripts/run_wave_b_windows_gate.ps1",
    "choco install -y freepascal lazarus",
    "Get-Command lazbuild",
    "pwsh -NoProfile -ExecutionPolicy Bypass -File tests/quick_winssl_validation.ps1",
    "pwsh -NoProfile -ExecutionPolicy Bypass -File scripts/run_wave_b_windows_gate.ps1",
    "pwsh -NoProfile -ExecutionPolicy Bypass -File tests/run_winssl_tests.ps1",
    "Tee-Object -Variable runtimeOutput",
    "Out-File -FilePath $runtimeLog -Encoding utf8",
    "test-reports/winssl_quick_smoke_${{ env.WINSSL_RUN_ID }}.log",
    "test-reports/wave_b_windows_gate_summary_${{ env.WINSSL_RUN_ID }}.md",
    "test-reports/winssl_runtime_suite_${{ env.WINSSL_RUN_ID }}.log",
    "This workflow records the observed results of the repository WinSSL scripts for the current run only.",
    "Review the uploaded runtime logs before making backend readiness or production support claims.",
    "For host overrides or risky native probe collection, use wave-b-b2-manual.yml.",
]

forbidden_fragments = [
    "test_suite:",
    "lazbuild src/nextpas.core.tls.winssl.lpk",
    "lazbuild tests/test_winssl_comprehensive.lpi",
    'tests\\bin\\test_winssl_comprehensive.exe',
    "**Production Ready**: ✅ YES",
    "All WinSSL tests PASSED",
    "PRODUCTION READY",
    "Zero-dependency Windows deployment SUPPORTED",
    "This template records the observed results of the repository WinSSL scripts for the current run only.",
]

for fragment in required_fragments:
    if fragment not in text:
        print(f"[FAIL] {workflow.name} missing truthful winssl-tests fragment: {fragment}")
        raise SystemExit(1)

for fragment in forbidden_fragments:
    if fragment in text:
        print(f"[FAIL] {workflow.name} stale winssl-tests fragment still present: {fragment}")
        raise SystemExit(1)

print(f"[PASS] {workflow.name} winssl-tests workflow truth contract passed")
PY
done
