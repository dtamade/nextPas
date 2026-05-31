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

reject_fixed() {
  local file="$1"
  local unexpected="$2"
  local message="$3"
  if grep -Fq -- "$unexpected" "$file"; then
    fail "$message"
  fi
}

builder_file="src/nextpas.core.tls.context.builder.pas"
contract_src="tests/config/test_context_builder_try.pas"
build_root="tmp/test_tsslcontextconfig_builder_material_projection"
units_dir="$build_root/units"
bin_dir="$build_root/bin"
binary="$bin_dir/test_context_builder_try"
fpc_exe="${FAFAFA_FPC_EXE:-fpc}"

printf '[TEST] TSSLContextConfig builder material projection contract\n'

require_fixed "$builder_file" \
  "Result.CertificateFile := FCertificateFile;" \
  "builder must project ordinary certificate file material through TSSLContextConfig"
require_fixed "$builder_file" \
  "Result.PrivateKeyFile := FPrivateKeyFile;" \
  "builder must project ordinary private-key file material through TSSLContextConfig"
require_fixed "$builder_file" \
  "Result.PrivateKeyPassword := FPrivateKeyPassword;" \
  "builder must project ordinary private-key password through TSSLContextConfig"
require_fixed "$builder_file" \
  "Result.CAFile := FCAFile;" \
  "builder must project CA file trust material through TSSLContextConfig"
require_fixed "$builder_file" \
  "Result.CAPath := FCAPath;" \
  "builder must project CA path trust material through TSSLContextConfig"
require_fixed "$builder_file" \
  "Result.UseSystemRoots := FUseSystemRoots;" \
  "builder must project system-root trust opt-in through TSSLContextConfig"

reject_fixed "$builder_file" \
  "Result.LoadCertificate(FCertificateFile);" \
  "ordinary certificate file loading should no longer stay on the builder post-create path"
reject_fixed "$builder_file" \
  "Result.LoadPrivateKey(FPrivateKeyFile, FPrivateKeyPassword);" \
  "ordinary private-key file loading should no longer stay on the builder post-create path"
reject_fixed "$builder_file" \
  "Result.LoadCAFile(FCAFile);" \
  "CA file loading should no longer stay on the builder post-create path"
reject_fixed "$builder_file" \
  "Result.LoadCAPath(FCAPath);" \
  "CA path loading should no longer stay on the builder post-create path"
reject_fixed "$builder_file" \
  "TSSLFactory.CreateCertificateStore(ContextBackend);" \
  "builder should let the context-safe factory path own system-root loading"

mkdir -p "$units_dir" "$bin_dir"
"$fpc_exe" -B -Fu./src -Fu./tests -Fu./tests/framework -FU"$units_dir" -FE"$bin_dir" -o"$binary" "$contract_src" >/dev/null
if [[ ! -x "$binary" ]]; then
  fail "builder material projection runtime probe must compile"
fi

"$binary"

printf '[PASS] TSSLContextConfig builder material projection contract passed\n'
