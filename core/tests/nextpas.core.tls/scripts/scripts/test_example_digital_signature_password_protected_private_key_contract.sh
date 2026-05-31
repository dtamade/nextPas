#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

fail() {
  echo "[FAIL] $1"
  exit 1
}

cd "$PROJECT_ROOT"

if ! command -v fpc >/dev/null 2>&1; then
  echo "[SKIP] fpc not found"
  exit 0
fi

mkdir -p "$PROJECT_ROOT/tmp"

before_status=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  before_status="$(git status --porcelain)"
fi

work_dir="$(mktemp -d "$PROJECT_ROOT/tmp/contract_digital_signature_password.XXXXXX")"
trap 'rm -rf "$work_dir"' EXIT

example_src="$PROJECT_ROOT/examples/digital_signature/digital_signature.pas"
bin_path="$work_dir/digital_signature"

fpc -Mobjfpc -Sh -O2 \
  -Fu"$PROJECT_ROOT/src" \
  -Fu"$PROJECT_ROOT/src/openssl" \
  -Fi"$PROJECT_ROOT/src" \
  -FE"$work_dir" \
  -FU"$work_dir" \
  -o"$bin_path" \
  "$example_src" >/dev/null

if [[ ! -x "$bin_path" ]]; then
  fail "compiled binary missing: $bin_path"
fi

msg_path="$work_dir/message.txt"
sig_path="$work_dir/message.sig"
priv_path="$work_dir/private.pem"
pub_path="$work_dir/public.pem"
password="testpass"

printf '%s\n' "hello signature" > "$msg_path"

"$bin_path" -g "$priv_path" "$pub_path" 2048 -p "$password" >/dev/null

if [[ ! -s "$priv_path" ]]; then
  fail "expected encrypted private key PEM to be created"
fi

if ! rg -F --quiet -- "ENCRYPTED" "$priv_path"; then
  fail "expected private key PEM to contain ENCRYPTED marker"
fi

"$bin_path" -s "$msg_path" "$sig_path" "$priv_path" -p "$password" >/dev/null
"$bin_path" -v "$msg_path" "$sig_path" "$pub_path" >/dev/null

if "$bin_path" -s "$msg_path" "$sig_path" "$priv_path" -p "wrongpass" >/dev/null 2>&1; then
  fail "expected signing with wrong password to fail"
fi

after_status=""
if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  after_status="$(git status --porcelain)"
fi

if [[ "$before_status" != "$after_status" ]]; then
  echo "[INFO] before:"
  printf '%s\n' "$before_status"
  echo "[INFO] after:"
  printf '%s\n' "$after_status"
  fail "contract should not dirty git worktree"
fi

echo "[PASS] digital_signature example supports password-protected private keys"
