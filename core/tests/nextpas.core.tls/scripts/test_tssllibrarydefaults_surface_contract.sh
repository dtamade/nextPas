#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$repo_root"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local message="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    fail "$message"
  fi
}

base_file="core/src/nextpas.core.tls.base.pas"
contract_src="core/tests/nextpas.core.tls/test_tssllibrarydefaults_surface.pas"
build_root="tmp/test_tssllibrarydefaults_surface"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_tssllibrarydefaults_surface"

printf '[TEST] TSSLLibraryDefaults surface contract\n'

require_fixed "$base_file" "TSSLLibraryDefaults = record" \
  "base source must declare TSSLLibraryDefaults"
require_fixed "$base_file" "function CreateDefaultLibraryDefaults: TSSLLibraryDefaults;" \
  "base source must expose CreateDefaultLibraryDefaults"
require_fixed "$base_file" "function GetLibraryDefaults(const ALibrary: ISSLLibrary): TSSLLibraryDefaults;" \
  "base source must expose GetLibraryDefaults"
require_fixed "$base_file" "procedure ApplyLibraryDefaults(const ALibrary: ISSLLibrary; const ADefaults: TSSLLibraryDefaults);" \
  "base source must expose ApplyLibraryDefaults"



mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu"$PWD/core/src" -Fu"$PWD/core/tests/nextpas.core.tls/framework" -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "TSSLLibraryDefaults runtime probe must compile"
fi

"$binary"

printf '[PASS] TSSLLibraryDefaults surface contract passed\n'
