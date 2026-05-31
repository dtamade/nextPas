#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW="$ROOT_DIR/.github/workflows/tls13-signer-gate.yml"

fail() {
  echo "[FAIL] $1"
  exit 1
}

if [[ ! -f "$WORKFLOW" ]]; then
  fail "missing workflow: .github/workflows/tls13-signer-gate.yml"
fi

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/tls13_signer_workflow_contract.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

summary_script="$tmp_root/append_step_summary.sh"
summary_workdir="$tmp_root/workflow"
summary_file="$tmp_root/step_summary.md"
status_json="$summary_workdir/test-reports/tls13_signer_gate_status_contract.json"
bundle_md="$summary_workdir/test-reports/tls13_signer_gate_bundle_contract.md"
snapshot_md="$summary_workdir/test-reports/tls13_signer_gate_snapshot_contract.md"
bench_json="$summary_workdir/test-reports/wave_b_tls13_signer_contract.json"

python3 - "$WORKFLOW" "$summary_script" <<'PY'
import pathlib
import re
import sys

workflow = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])
lines = workflow.read_text(encoding="utf-8").splitlines()

step_idx = None
for idx, line in enumerate(lines):
    if line.strip() == "- name: Append step summary":
        step_idx = idx
        break

if step_idx is None:
    raise SystemExit("missing append step summary block")

run_idx = None
for idx in range(step_idx + 1, len(lines)):
    if re.match(r"^\s*run:\s*\|$", lines[idx]):
        run_idx = idx
        break
    if re.match(r"^\s*-\s+name:", lines[idx]):
        raise SystemExit("append step summary block has no run: | section")

if run_idx is None:
    raise SystemExit("append step summary block has no run: | section")

base_indent = None
block = []
for line in lines[run_idx + 1:]:
    if line.strip() == "":
      block.append("")
      continue
    indent = len(line) - len(line.lstrip(" "))
    if base_indent is None:
      base_indent = indent
    if indent < base_indent:
      break
    block.append(line[base_indent:])

if not block:
    raise SystemExit("append step summary block is empty")

out_path.write_text("\n".join(block) + "\n", encoding="utf-8")
PY

if ! bash -n "$summary_script" >/dev/null 2>&1; then
  echo "[INFO] extracted append-step-summary script:" >&2
  cat "$summary_script" >&2
  fail "tls13 signer gate append-step-summary shell must parse cleanly"
fi

mkdir -p "$summary_workdir/test-reports"

cat > "$bundle_md" <<'EOF'
# bundle
EOF

cat > "$snapshot_md" <<'EOF'
# snapshot
EOF

cat > "$bench_json" <<'EOF'
{"bench_scheme":"rsa_pkcs1_sha256"}
EOF

cat > "$status_json" <<'EOF'
{
  "overall_state": "HEALTHY",
  "summary_overall": "PASS",
  "snapshot_state": "GREEN",
  "purity_status": "PASS",
  "bench_status": "PASS",
  "bench": {
    "scheme": "rsa_pkcs1_sha256",
    "iterations": "2",
    "warmup": "1",
    "crt_avg_ms": "1.0",
    "d_avg_ms": "2.0",
    "speedup_d_over_crt": "2.0x"
  }
}
EOF

set +e
(
  cd "$summary_workdir"
  GITHUB_STEP_SUMMARY="$summary_file" \
  bash "$summary_script"
)
exit_code=$?
set -e

if [[ "$exit_code" -ne 0 ]]; then
  echo "[INFO] extracted append-step-summary script:" >&2
  cat "$summary_script" >&2
  fail "tls13 signer gate append-step-summary script must execute cleanly against a fake status payload"
fi

if ! rg -n "^### Gate Status$" "$summary_file" >/dev/null; then
  echo "[INFO] generated step summary:" >&2
  cat "$summary_file" >&2
  fail "step summary must include the Gate Status section"
fi

if ! grep -Fq -- '- overall_state: `HEALTHY`' "$summary_file"; then
  echo "[INFO] generated step summary:" >&2
  cat "$summary_file" >&2
  fail "step summary must render overall_state from the status json"
fi

echo "[PASS] tls13 signer gate workflow contract passed"
