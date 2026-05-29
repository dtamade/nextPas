#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WINSSL_QUICKSTART="$ROOT_DIR/docs/guides/WINSSL_QUICKSTART.md"
AGENTS_DOC="$ROOT_DIR/docs/AGENTS.md"

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if ! rg -F -n --quiet -- "$needle" "$file"; then
    fail "$message"
  fi
}

require_absent() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if rg -F -n --quiet -- "$needle" "$file"; then
    fail "$message"
  fi
}

require_absent_regex() {
  local file="$1"
  local pattern="$2"
  local message="$3"
  if rg -n --quiet -- "$pattern" "$file"; then
    fail "$message"
  fi
}

echo "[TEST] repository guidance entrypoint classification truth contract"

require_fixed "$WINSSL_QUICKSTART" '下列项目结构片段描述的是源码树 owner / unit 角色，不代表普通调用方默认 `uses` 列表。' \
  "WINSSL_QUICKSTART must classify the project-structure snippet as source-owner guidance"
require_fixed "$WINSSL_QUICKSTART" "│       │   ├── nextpas.core.tls.pas                # 主门面 / 当前普通入口" \
  "WINSSL_QUICKSTART tree must show the current public facade entry"
require_fixed "$WINSSL_QUICKSTART" "│       │   ├── nextpas.core.tls.context.builder.pas # 推荐 context builder 入口" \
  "WINSSL_QUICKSTART tree must show the current builder entry"
require_fixed "$WINSSL_QUICKSTART" "│       │   ├── nextpas.core.tls.factory.pas        # core factory surface / direct-library helper" \
  "WINSSL_QUICKSTART tree must classify nextpas.core.tls.factory.pas correctly"
require_fixed "$WINSSL_QUICKSTART" "│       │   ├── nextpas.core.tls.base.pas           # 底层 source truth / supporting types" \
  "WINSSL_QUICKSTART tree must classify nextpas.core.tls.base.pas as source-truth owner"
require_absent_regex "$WINSSL_QUICKSTART" '^│       │   ├── fafafa\.ssl\.base\.pas$' \
  "WINSSL_QUICKSTART must stop leaving nextpas.core.tls.base.pas unlabeled in the structure snippet"

require_fixed "$AGENTS_DOC" '主门面入口是 `src/nextpas.core.tls.pas`，推荐 builder 入口是 `src/nextpas.core.tls.context.builder.pas`；`src/nextpas.core.tls.base.pas` 主要承载底层 source truth / supporting types。' \
  "docs/AGENTS must state the current facade / builder / base role split"
require_absent "$AGENTS_DOC" '公共抽象在 `nextpas.core.tls.base`' \
  "docs/AGENTS must stop compressing the structure truth into a misleading base-only sentence"

echo "[PASS] repository guidance entrypoint classification truth contract passed"
