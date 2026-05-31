#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
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

base_file="src/nextpas.core.tls.base.pas"
facade_file="src/nextpas.core.tls.pas"
api_ref="docs/reference/API_REFERENCE.md"
arch_ref="docs/reference/ARCHITECTURE.md"
user_guide="docs/guides/USER_GUIDE.md"
troubleshooting="docs/guides/TROUBLESHOOTING.md"
contract_src="tests/test_tssllibrarydefaults_surface.pas"
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

require_fixed "$facade_file" "TSSLLibraryDefaults = nextpas.core.tls.base.TSSLLibraryDefaults;" \
  "facade must re-export TSSLLibraryDefaults"
require_fixed "$facade_file" "function CreateDefaultLibraryDefaults: TSSLLibraryDefaults;" \
  "facade must re-export CreateDefaultLibraryDefaults"
require_fixed "$facade_file" "function GetLibraryDefaults(const ALibrary: ISSLLibrary): TSSLLibraryDefaults;" \
  "facade must re-export GetLibraryDefaults"
require_fixed "$facade_file" "procedure ApplyLibraryDefaults(const ALibrary: ISSLLibrary; const ADefaults: TSSLLibraryDefaults);" \
  "facade must re-export ApplyLibraryDefaults"

require_fixed "$api_ref" '当前更清晰的 additive surface 是 `TSSLLibraryDefaults` + `GetLibraryDefaults(...)` / `ApplyLibraryDefaults(...)`。' \
  "API reference must describe TSSLLibraryDefaults as the preferred additive library-default surface"
require_fixed "$arch_ref" '通过 `TSSLLibraryDefaults` + `GetLibraryDefaults(...)` / `ApplyLibraryDefaults(...)` 访问 library-owned defaults；' \
  "reference architecture must describe TSSLLibraryDefaults as the library-default entrypoint"
require_fixed "$user_guide" 'LLogDefaults := GetLibraryDefaults(LLib);' \
  "user guide must use GetLibraryDefaults in logging examples"
require_fixed "$user_guide" 'ApplyLibraryDefaults(LLib, LLogDefaults);' \
  "user guide must use ApplyLibraryDefaults in logging examples"
require_fixed "$troubleshooting" 'LLogDefaults := GetLibraryDefaults(LLib);' \
  "troubleshooting guide must use GetLibraryDefaults in logging examples"
require_fixed "$troubleshooting" 'ApplyLibraryDefaults(LLib, LLogDefaults);' \
  "troubleshooting guide must use ApplyLibraryDefaults in logging examples"

mkdir -p "$units_dir" "$bin_dir"
fpc -B -Fu./src -Fu./tests -Fu./tests/framework -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "TSSLLibraryDefaults runtime probe must compile"
fi

"$binary"

printf '[PASS] TSSLLibraryDefaults surface contract passed\n'
