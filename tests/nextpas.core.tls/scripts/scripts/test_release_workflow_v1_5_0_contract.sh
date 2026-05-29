#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

release_action_sha="b4309332981a82ec1c5618f44dd2e27cc8bfbfda"
have_rg=0

if command -v rg >/dev/null 2>&1; then
  have_rg=1
fi

pass() {
  printf '[PASS] %s\n' "$1"
}

fail() {
  printf '[FAIL] %s\n' "$1"
  if [[ $# -ge 2 ]]; then
    printf '       %s\n' "$2"
  fi
  exit 1
}

require_file() {
  local file="$1"
  local name="$2"
  if [[ -f "$file" ]]; then
    pass "$name"
  else
    fail "$name" "missing file: $file"
  fi
}

require_match() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if (( have_rg )); then
    if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
      pass "$name"
      return
    fi
  elif python3 - "$file" "$pattern" <<'PY'
import pathlib
import re
import sys

file_path = pathlib.Path(sys.argv[1])
pattern = sys.argv[2]
content = file_path.read_text(encoding="utf-8")
sys.exit(0 if re.search(pattern, content, re.MULTILINE | re.DOTALL) else 1)
PY
  then
    pass "$name"
    return
  fi

  fail "$name" "pattern not found in $file: $pattern"
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if grep -Fq -- "$expected" "$file"; then
    pass "$name"
  else
    fail "$name" "expected text not found in $file: $expected"
  fi
}

require_literal() {
  local file="$1"
  local expected="$2"
  local name="$3"
  if (( have_rg )); then
    if rg -n --fixed-strings -- "$expected" "$file" >/dev/null; then
      pass "$name"
      return
    fi
  elif grep -Fq -- "$expected" "$file"; then
    pass "$name"
    return
  fi

  fail "$name" "expected text not found in $file: $expected"
}

require_absent() {
  local file="$1"
  local pattern="$2"
  local name="$3"
  if (( have_rg )); then
    if rg -n --multiline --multiline-dotall "$pattern" "$file" >/dev/null; then
      fail "$name" "unexpected pattern still present in $file: $pattern"
    fi
  elif python3 - "$file" "$pattern" <<'PY'
import pathlib
import re
import sys

file_path = pathlib.Path(sys.argv[1])
pattern = sys.argv[2]
content = file_path.read_text(encoding="utf-8")
sys.exit(0 if re.search(pattern, content, re.MULTILINE | re.DOTALL) else 1)
PY
  then
    fail "$name" "unexpected pattern still present in $file: $pattern"
  else
    pass "$name"
    return
  fi

  pass "$name"
}

printf '[TEST] v1.5.0 release workflow contract\n'

require_file ".github/workflows/release.yml" "active release workflow exists"
require_file ".github/workflows/release.yml.disabled" "disabled release workflow template exists"
require_file "RELEASE_NOTES_V1.5.0.md" "v1.5.0 release notes exist"

if cmp -s ".github/workflows/release.yml" ".github/workflows/release.yml.disabled"; then
  pass "active and disabled release workflow templates are synchronized"
else
  fail "active and disabled release workflow templates are synchronized"
fi

for workflow in ".github/workflows/release.yml" ".github/workflows/release.yml.disabled"; do
  require_match "$workflow" 'push:\s*\n\s*tags:\s*\n\s*-\s*["'\'']v1\.5\.0["'\'']' \
    "$workflow only auto-runs for the v1.5.0 tag"
  require_match "$workflow" 'workflow_dispatch:' \
    "$workflow supports manual dispatch"
  require_match "$workflow" 'VERSION="\$\{\{ github\.event\.inputs\.version \}\}"' \
    "$workflow resolves workflow_dispatch version input"
  require_match "$workflow" 'VERSION="\$\{GITHUB_REF_NAME\}"' \
    "$workflow resolves tag version from GITHUB_REF_NAME"
  require_match "$workflow" '\[\[ "\$VERSION" != "v1\.5\.0" \]\]' \
    "$workflow rejects versions other than v1.5.0"
  require_match "$workflow" 'git rev-parse -q --verify "refs/tags/\$VERSION"' \
    "$workflow requires an existing approved tag"
  require_match "$workflow" "FAFAFA_SSL_VERSION_STRING = '1\\.5\\.0'" \
    "$workflow verifies source version string"
  require_match "$workflow" 'FAFAFA_SSL_INTERFACE_VERSION = 10500' \
    "$workflow verifies interface version"
  require_match "$workflow" '<Version Major="1" Minor="5" Release="0" Build="0"/>' \
    "$workflow verifies Lazarus package version"
  require_match "$workflow" 'README\.md' \
    "$workflow checks README version truth"
  require_match "$workflow" 'CHANGELOG\.md' \
    "$workflow checks changelog release section"
  require_match "$workflow" 'RELEASE_NOTES_V1\.5\.0\.md' \
    "$workflow checks release notes"
  require_match "$workflow" 'python3 scripts/compile_all_modules\.py' \
    "$workflow runs the current compile gate"
  require_match "$workflow" 'bash scripts/run_minimal_ci_gate\.sh --fast-local' \
    "$workflow runs the current minimal CI gate"
  require_match "$workflow" 'bash scripts/run_freepascal_tls13_completeness_gate\.sh --fast-local' \
    "$workflow runs the FreePascal TLS 1.3 completeness gate"
  require_match "$workflow" 'libwolfssl-dev' \
    "$workflow installs WolfSSL runtime dependencies for completeness coverage"
  require_match "$workflow" 'libmbedtls-dev' \
    "$workflow installs MbedTLS runtime dependencies for completeness coverage"
  require_match "$workflow" 'python3 scripts/check_code_style\.py src' \
    "$workflow runs the style gate"
  require_match "$workflow" 'bash scripts/run_phase2_performance_baseline\.sh --dry-run --fast-local' \
    "$workflow runs the Phase 2 dry-run gate"
  require_match "$workflow" 'body_path: RELEASE_NOTES_V1\.5\.0\.md' \
    "$workflow uses the checked-in v1.5.0 release notes"
  require_match "$workflow" "uses:\\s*softprops/action-gh-release@${release_action_sha}\\b" \
    "$workflow uses the pinned softprops/action-gh-release commit for the Node24 release runtime"
  require_match "$workflow" 'archive_tmp="\$\{RUNNER_TEMP:-/tmp\}/\$\{ARCHIVE_NAME\}\.tar\.gz"' \
    "$workflow stages the source archive outside the repo tree"
  require_match "$workflow" 'tar -czf "\$archive_tmp"' \
    "$workflow creates the staged source archive"
  require_match "$workflow" 'mv "\$archive_tmp" "\$\{ARCHIVE_NAME\}\.tar\.gz"' \
    "$workflow moves the staged source archive back after creation"
  require_literal "$workflow" "--exclude='./bin'" \
    "$workflow excludes bin/"
  require_literal "$workflow" "--exclude='./tmp'" \
    "$workflow excludes tmp/"
  require_literal "$workflow" "--exclude='./test-reports'" \
    "$workflow excludes test-reports/"
  require_literal "$workflow" "--exclude='./.ace-tool'" \
    "$workflow excludes local ace tool cache"
  require_literal "$workflow" "--exclude='./.agents'" \
    "$workflow excludes local agent cache"
  require_literal "$workflow" "--exclude='./.codex'" \
    "$workflow excludes local codex cache"
  require_literal "$workflow" "--exclude='./.fusion'" \
    "$workflow excludes local fusion cache"
  require_literal "$workflow" "--exclude='./examples/digital_signature/private.pem'" \
    "$workflow excludes generated example private key"
  require_literal "$workflow" "--exclude='./examples/digital_signature/public.pem'" \
    "$workflow excludes generated example public key"
  require_literal "$workflow" "--exclude='*.o'" \
    "$workflow excludes object files"
  require_literal "$workflow" "--exclude='*.ppu'" \
    "$workflow excludes Pascal unit outputs"
  require_literal "$workflow" "--exclude='*.exe'" \
    "$workflow excludes compiled executables"
  require_absent "$workflow" 'tar -czf "\$\{ARCHIVE_NAME\}\.tar\.gz"' \
    "$workflow no longer writes the archive directly inside the archived tree"
  require_absent "$workflow" 'build_linux\.sh' \
    "$workflow no longer uses the old build_linux.sh release path"
  require_absent "$workflow" 'run_tests_linux\.sh' \
    "$workflow no longer uses the old run_tests_linux.sh release path"
  require_absent "$workflow" 'softprops/action-gh-release@v2\b' \
    "$workflow no longer keeps the Node20 release action line"
  require_absent "$workflow" 'release_notes\.md' \
    "$workflow no longer generates inline release notes"
  require_absent "$workflow" 'CreateSSLContext\(' \
    "$workflow no longer embeds the old API example"
  require_absent "$workflow" 'CreateSSLLibrary\(' \
    "$workflow no longer embeds the old library helper"
  require_absent "$workflow" 'yourusername/fafafa\.ssl' \
    "$workflow no longer contains placeholder GitHub URLs"
done

require_fixed "src/nextpas.core.tls.base.pas" "FAFAFA_SSL_VERSION_STRING = '1.5.0';" \
  "source version string is v1.5.0"
require_fixed "src/nextpas.core.tls.base.pas" "FAFAFA_SSL_INTERFACE_VERSION = 10500;" \
  "source interface version is 10500"
require_fixed "fafafa_ssl.lpk" '<Version Major="1" Minor="5" Release="0" Build="0"/>' \
  "Lazarus package version is 1.5.0"
require_fixed "README.md" "Version-v1.5.0" \
  "README version badge is v1.5.0"
require_fixed "README.md" "releases/tag/v1.5.0" \
  "README version badge links to v1.5.0"
require_fixed "README.md" "## 最新版本 v1.5.0" \
  "README latest-version heading is v1.5.0"
require_absent "README.md" 'Version-v1\.4\.2|releases/tag/v1\.4\.2|最新版本 v1\.4\.2' \
  "README no longer advertises v1.4.2 as current"
require_fixed "CHANGELOG.md" "## [Unreleased]" \
  "CHANGELOG keeps a fresh Unreleased section"
require_fixed "CHANGELOG.md" "## [1.5.0] - 2026-05-12" \
  "CHANGELOG has a v1.5.0 release section"
require_fixed "RELEASE_NOTES_V1.5.0.md" "FAFAFA_SSL_INTERFACE_VERSION = 10500" \
  "release notes record interface version"
require_fixed "RELEASE_NOTES_V1.5.0.md" "TSSLFactory.*" \
  "release notes document TSSLFactory migration"
require_fixed "RELEASE_NOTES_V1.5.0.md" "TSSLHelper class remains available" \
  "release notes clarify TSSLHelper remains public"
require_fixed "RELEASE_NOTES_V1.5.0.md" "FreePascal: TLS 1.3 coverage is broader, but early-data remains experimental" \
  "release notes preserve FreePascal early-data caveat"
require_fixed "RELEASE_NOTES_V1.5.0.md" "GitHub Actions cross-platform runtime evidence is already green on the current head." \
  "release notes preserve the current cross-platform runtime truth"
require_fixed "RELEASE_NOTES_V1.5.0.md" "WinSSL: source contracts and validation bundle contracts are in place. GitHub Actions Windows runtime proof is green on the current head and is recorded in release readiness." \
  "release notes preserve the current WinSSL runtime proof truth"

printf '[PASS] v1.5.0 release workflow contract passed\n'
