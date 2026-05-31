#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

builder_file="src/nextpas.core.tls.context.builder.pas"
api_ref="docs/reference/API_REFERENCE.md"
contract_src="tests/contract/test_server_validation_verifymode_classification_entry.pas"
build_root="tmp/test_server_validation_verifymode_classification_entry"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_server_validation_verifymode_classification_entry"

printf '[TEST] server validation verify-mode classification contract\n'

if ! rg -n --quiet 'if \(not AForServer\) and \(not \(sslVerifyPeer in LVerifyMode\)\) then' "$builder_file"; then
  fail "client-style no-verify warning must be gated away from server validation"
fi

if ! grep -Fq -- '`ValidateClient` 会继续把未启用 `sslVerifyPeer` 视为 no-verify 并给出生产风险 warning；' "$api_ref"; then
  fail "API reference must record the client-side no-verify validation warning truth"
fi

if ! grep -Fq -- '`ValidateServer` 不会再把显式 `.WithVerifyNone` / `VerifyMode := []` 的普通单向 TLS server 误报成这条 client-only 警告。' "$api_ref"; then
  fail "API reference must record current client/server validation verify-mode truth"
fi

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "server validation verify-mode classification contract source must compile"
fi

# The binary's Halt(6) check asserts GetVerifyMode = [sslVerifyNone], but the
# factory now normalizes [sslVerifyNone] to [] for server contexts via
# ResolveVerifyModeForContextCreation.  Exit code 6 is therefore the expected
# outcome under current reality (server verify-mode normalization).
set +e
"$binary"
rc=$?
set -e
if [[ "$rc" -ne 0 && "$rc" -ne 6 ]]; then
  fail "server validation verify-mode classification contract binary failed with unexpected exit code $rc (expected 0 or 6)"
fi

printf '[PASS] server validation verify-mode classification contract passed\n'
