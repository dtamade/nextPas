#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/run_freepascal_tls13_servercertverify_bench.sh"

fail() {
  echo "[FAIL] $1"
  exit 1
}

if [[ ! -f "$SCRIPT" ]]; then
  fail "missing script: scripts/run_freepascal_tls13_servercertverify_bench.sh"
fi

if rg -n --pcre2 '^fpc .* -Criot(?: |$)' "$SCRIPT" >/dev/null; then
  fail "bench script must not force -Criot because it trips constant range checks in the signer bench build"
fi

if rg -n --fixed-strings -- 'bench_tls13_servercertverify.pas" >/dev/null' "$SCRIPT" >/dev/null; then
  fail "bench script must not discard compiler output to /dev/null"
fi

tmp_root="$(mktemp -d "${TMPDIR:-/tmp}/tls13_sign_bench_contract.XXXXXX")"
trap 'rm -rf "$tmp_root"' EXIT

fake_bin="$tmp_root/bin"
stdout_log="$tmp_root/stdout.log"
stderr_log="$tmp_root/stderr.log"

mkdir -p "$fake_bin"

cat > "$fake_bin/fpc" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo "FAKE_FPC_RANGE_CHECK_ERROR: simulated bench compile failure" >&2
exit 42
EOF
chmod +x "$fake_bin/fpc"

set +e
(
  cd "$ROOT_DIR"
  PATH="$fake_bin:$PATH" \
  bash scripts/run_freepascal_tls13_servercertverify_bench.sh >"$stdout_log" 2>"$stderr_log"
)
exit_code=$?
set -e

if [[ "$exit_code" -eq 0 ]]; then
  fail "bench script should fail when fake fpc fails"
fi

if ! rg -n "FAKE_FPC_RANGE_CHECK_ERROR" "$stderr_log" "$stdout_log" >/dev/null; then
  echo "[INFO] stdout:" >&2
  cat "$stdout_log" >&2 || true
  echo "[INFO] stderr:" >&2
  cat "$stderr_log" >&2 || true
  fail "bench script must surface compiler diagnostics when the bench build fails"
fi

echo "[PASS] tls13 servercertverify bench contract passed"
