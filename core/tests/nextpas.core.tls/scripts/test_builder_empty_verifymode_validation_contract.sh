#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

builder_file="core/src/nextpas.core.tls.context.builder.pas"

printf '[TEST] builder empty verify-mode validation parity contract\n'

if ! rg -n --quiet --fixed-strings 'not (sslVerifyPeer in LVerifyMode)' "$builder_file"; then
  fail "builder validation must treat missing sslVerifyPeer as disabled certificate verification"
fi


printf '[PASS] builder empty verify-mode validation parity contract passed\n'
