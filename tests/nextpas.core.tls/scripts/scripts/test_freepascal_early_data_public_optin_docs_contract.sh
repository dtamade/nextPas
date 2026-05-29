#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

require_file() {
  local file="$1"
  local message="$2"
  if [[ ! -f "$file" ]]; then
    echo "[FAIL] $message"
    echo "  missing: $file"
    exit 1
  fi
}

require_fixed() {
  local file="$1"
  local expected="$2"
  local message="$3"
  if ! grep -Fq -- "$expected" "$file"; then
    echo "[FAIL] $message"
    echo "  file: $file"
    echo "  expected: $expected"
    exit 1
  fi
}

require_file "README.md" "README.md must exist for FreePascal early-data public opt-in guidance"
require_file "docs/ROADMAP.md" "Roadmap must exist for the final FreePascal early-data caveat truth"
require_file "docs/BACKEND_CAPABILITY_MATRIX.md" "Backend capability matrix must exist for FreePascal early-data caveat truth"
require_file "docs/reference/API_REFERENCE.md" "API reference must exist for FreePascal early-data public opt-in guidance"
require_file "docs/INTEGRATION_GUIDE.md" "Integration guide must exist for FreePascal replay-store integration truth"
require_file "docs/guides/EARLY_DATA_GUIDE.md" "Early-data guide must exist for FreePascal replay-store boundary truth"
require_file "docs/guides/security-best-practices.md" "Security best practices guide must exist for FreePascal capability truth"

require_fixed "README.md" "目前仍是实验性能力" \
  "README.md must keep the FreePascal early-data experimental capability wording"
require_fixed "README.md" "TSSLContextConfig.ServerEarlyDataReplayStoreFile" \
  "README.md must mention the file-backed early-data replay-store config field"
require_fixed "README.md" "TSSLContextConfig.ServerEarlyDataReplayStoreDirectory" \
  "README.md must mention the directory-backed early-data replay-store config field"
require_fixed "README.md" "WithServerEarlyDataReplayStoreFile" \
  "README.md must mention the builder file-backed early-data replay-store opt-in"
require_fixed "README.md" "WithServerEarlyDataReplayStoreDirectory" \
  "README.md must mention the builder directory-backed early-data replay-store opt-in"
require_fixed "README.md" "默认 replay truth 落到本地持久化 replay-store" \
  "README.md must record the durable default replay-store truth"
require_fixed "README.md" "fail-closed reject" \
  "README.md must record the fail-closed default-path behavior"
if grep -Fq -- "不代表默认路径已经持久化" "README.md"; then
  echo "[FAIL] README.md must stop contradicting the durable default replay-store truth"
  exit 1
fi

require_fixed "docs/reference/API_REFERENCE.md" "TSSLConfig.ServerEarlyDataReplayStoreFile" \
  "API reference must mention the file-backed early-data replay-store config field"
require_fixed "docs/reference/API_REFERENCE.md" "TSSLConfig.ServerEarlyDataReplayStoreDirectory" \
  "API reference must mention the directory-backed early-data replay-store config field"
require_fixed "docs/reference/API_REFERENCE.md" "WithServerEarlyDataReplayStoreFile" \
  "API reference must mention the builder file-backed early-data replay-store opt-in"
require_fixed "docs/reference/API_REFERENCE.md" "WithServerEarlyDataReplayStoreDirectory" \
  "API reference must mention the builder directory-backed early-data replay-store opt-in"
require_fixed "docs/reference/API_REFERENCE.md" "mutually exclusive" \
  "API reference must document that file and directory replay-store opt-ins are mutually exclusive"
require_fixed "docs/reference/API_REFERENCE.md" "当前 capability 仍保持 \`experimental\`" \
  "API reference must keep the experimental capability wording for the default replay-store path"
require_fixed "docs/reference/API_REFERENCE.md" "默认 shipped path 已经会把 replay truth 落到本地持久化 replay-store 路径" \
  "API reference must record the durable default replay-store truth"
if grep -Fq -- "不代表默认路径已经改成持久化" "docs/reference/API_REFERENCE.md"; then
  echo "[FAIL] API reference must stop contradicting the durable default replay-store truth"
  exit 1
fi

require_fixed "docs/INTEGRATION_GUIDE.md" "默认 shipped path 仍会落到本地持久化 replay-store 目录" \
  "Integration guide must record the durable default replay-store path"
require_fixed "docs/INTEGRATION_GUIDE.md" "fail-closed reject resumed early data" \
  "Integration guide must record the fail-closed default replay-store behavior"
require_fixed "docs/INTEGRATION_GUIDE.md" "这条 opt-in 也不会把 \`experimental\` capability wording 自动升级成更强承诺" \
  "Integration guide must preserve the experimental capability boundary"
if grep -Fq -- "in-memory single-process anti-replay ledger" "docs/INTEGRATION_GUIDE.md"; then
  echo "[FAIL] Integration guide must stop teaching the retired in-memory default replay truth"
  exit 1
fi

require_fixed "docs/guides/EARLY_DATA_GUIDE.md" \
  "\`FreePascal\` 的 client/server surface 已接通，但能力仍按 experimental 发布；默认 replay truth 落到本地持久化 replay-store，默认路径不可用或不可写时 fail-closed reject。" \
  "Early-data guide must keep the FreePascal experimental persistent replay-store boundary"
if grep -Fq -- "in-memory single-process anti-replay ledger" "docs/guides/EARLY_DATA_GUIDE.md"; then
  echo "[FAIL] Early-data guide must stop teaching the retired in-memory default replay truth"
  exit 1
fi

require_fixed "docs/ROADMAP.md" \
  "freepascal_remaining_capability_caveat: \`0-RTT / early data is experimental and currently relies on a local persistent anti-replay replay-store path; if the path is unavailable or unwritable, resumed early data is rejected fail-closed.\`" \
  "Roadmap must keep the exact final FreePascal early-data caveat"
require_fixed "docs/ROADMAP.md" "不再建议无 fresh RED 地继续开 directory-store family" \
  "Roadmap must keep the no-reopen guidance for the directory-store family"
require_fixed "docs/ROADMAP.md" "这条 caveat 应视为 post-release 阶段有意保留的最终 experimental boundary" \
  "Roadmap must classify the remaining caveat as the intended final experimental boundary"

require_fixed "docs/BACKEND_CAPABILITY_MATRIX.md" \
  "**状态**: ⚠️ 实验性支持（public surface 已接通，默认 shipped path 已切到本地持久化 replay-store 路径）" \
  "Backend capability matrix must mark FreePascal early-data as experimental with a persistent default path"
require_fixed "docs/BACKEND_CAPABILITY_MATRIX.md" \
  "\`TSSLBackendCapabilities.ZeroRTTSupport\` / \`EarlyDataSupport\` 当前发布为 \`sslSupportExperimental\`" \
  "Backend capability matrix must keep the experimental support-level wording"
require_fixed "docs/BACKEND_CAPABILITY_MATRIX.md" "默认 shipped path 已经把 replay truth 落到本地持久化 replay-store 路径" \
  "Backend capability matrix must record the durable default replay-store truth"
require_fixed "docs/BACKEND_CAPABILITY_MATRIX.md" "如果默认路径不可用或不可写，resumed early data 会 fail-closed reject" \
  "Backend capability matrix must record the fail-closed default replay-store behavior"
if grep -Fq -- "in-memory single-process anti-replay ledger" "docs/BACKEND_CAPABILITY_MATRIX.md"; then
  echo "[FAIL] Backend capability matrix must stop teaching the retired in-memory default replay truth"
  exit 1
fi

require_fixed "docs/guides/security-best-practices.md" \
  "local persistent anti-replay replay-store path; if the path is unavailable or unwritable, resumed early data is rejected fail-closed." \
  "Security best practices must quote the current FreePascal KnownIssues truth"

require_fixed "src/nextpas.core.tls.freepascal.context.pas" \
  "TFreePascalDefaultPersistentEarlyDataReplayLedger.Create(" \
  "FreePascal server context must still default to the persistent replay ledger"
require_fixed "src/nextpas.core.tls.freepascal.lib.pas" \
  "local persistent anti-replay replay-store path; if the path is unavailable or unwritable, resumed early data is rejected fail-closed." \
  "FreePascal capability KnownIssues must keep the durable default replay-store wording"

echo "[PASS] FreePascal early-data public opt-in docs contract passed"
