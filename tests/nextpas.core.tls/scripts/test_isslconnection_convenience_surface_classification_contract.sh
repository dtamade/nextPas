#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

cd "$PROJECT_ROOT"

source_file="src/nextpas.core.tls.base.pas"
api_doc="docs/reference/API_REFERENCE.md"
design_doc="docs/reference/INTERFACE_DESIGN_V2.md"
architecture_doc="docs/ARCHITECTURE.md"
audit_doc="docs/test_reports/INTERFACE_DESIGN_AUDIT_V1.5.0.md"
docs_readme="docs/README.md"

declare -a source_patterns=(
  'function ReadString(out AStr: string): Boolean;'
  'function WriteString(const AStr: string): Boolean;'
  'procedure SetTimeout(ATimeout: Integer);'
  'function GetTimeout: Integer;'
  'procedure SetBlocking(ABlocking: Boolean);'
  'function GetBlocking: Boolean;'
  '@preferred-access 框架/transport 集成优先使用 Read/Write；ReadString/WriteString 继续作为 v1.x convenience-core 文本入口保留'
  '@preferred-access 新代码优先在构建阶段使用 TSSLConnectionBuilder.WithTimeout / TSSLConnector.WithTimeout / TSSLAcceptor.WithTimeout；连接创建后若需要读取或覆盖 runtime control state，优先通过 ISSLConnectionControl.SetTimeout；此入口继续作为 per-connection convenience override 保留'
  '@preferred-access 新代码优先在构建阶段使用 TSSLConnectionBuilder.WithTimeout / TSSLConnector.WithTimeout / TSSLAcceptor.WithTimeout；连接创建后若需要读取或覆盖 runtime control state，优先通过 ISSLConnectionControl.GetTimeout；此入口继续作为 per-connection convenience override 保留'
  '@preferred-access 新代码优先在构建阶段使用 TSSLConnectionBuilder.WithBlocking；连接创建后若需要读取或覆盖 runtime control state，优先通过 ISSLConnectionControl.SetBlocking；此入口继续作为 per-connection convenience override 保留'
  '@preferred-access 新代码优先在构建阶段使用 TSSLConnectionBuilder.WithBlocking；连接创建后若需要读取或覆盖 runtime control state，优先通过 ISSLConnectionControl.GetBlocking；此入口继续作为 per-connection convenience override 保留'
)

for pattern in "${source_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$source_file"; then
    echo "[FAIL] source convenience-surface truth missing: $pattern"
    exit 1
  fi
done

declare -a api_doc_patterns=(
  '`ReadString` / `WriteString` 继续作为 `v1.x` convenience-core 文本 helper 保留；框架/transport 集成优先使用 `Read` / `Write`。'
  '`SetTimeout` / `GetTimeout` 继续作为 `v1.x` connection-adjacent convenience surface 保留；新代码优先在构建阶段使用 `TSSLConnectionBuilder.WithTimeout(...)` / `TSSLConnector.WithTimeout(...)` / `TSSLAcceptor.WithTimeout(...)`。'
  '`SetBlocking` / `GetBlocking` 继续作为 `v1.x` connection-adjacent convenience surface 保留；新代码优先在构建阶段使用 `TSSLConnectionBuilder.WithBlocking(...)`。'
)

for pattern in "${api_doc_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$api_doc"; then
    echo "[FAIL] API reference convenience classification missing: $pattern"
    exit 1
  fi
done

declare -a design_doc_patterns=(
  '这份文档描述的是 **v2 最小 core 目标**，不是 `v1.5.0` 当前 shipped source 的逐行镜像。'
  '| ReadString, WriteString | ISSLConnectionTextIO | 默认 owner 已切到 ISSLConnectionTextIO；core 侧继续作为 `v1.x` convenience mirror 保留 |'
  '| SetTimeout, GetTimeout | ISSLConnectionControl | 默认 owner 已切到 ISSLConnectionControl；core 侧继续作为 `v1.x` convenience mirror 保留 |'
  '| SetBlocking, GetBlocking | ISSLConnectionControl | 默认 owner 已切到 ISSLConnectionControl；core 侧继续作为 `v1.x` convenience mirror 保留 |'
)

for pattern in "${design_doc_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$design_doc"; then
    echo "[FAIL] design doc convenience classification missing: $pattern"
    exit 1
  fi
done

declare -a forbidden_design_patterns=(
  '| ReadString, WriteString | **移除** | 使用 Read/Write |'
  '| SetTimeout, GetTimeout | **移除** | 由外部框架控制 |'
  '| SetBlocking, GetBlocking | **移除** | 由外部框架控制 |'
)

for pattern in "${forbidden_design_patterns[@]}"; do
  if grep -F -q "$pattern" "$design_doc"; then
    echo "[FAIL] design doc still presents current convenience methods as removed: $pattern"
    exit 1
  fi
done

declare -a architecture_patterns=(
  '以下代码块是 **概念上的最小 core slice**，不是 `v1.5.0` 当前 shipped source 的完整逐行镜像。'
  '当前 shipped source 仍保留 `ReadString` / `WriteString` 与 timeout/blocking 这组 convenience-core / connection-adjacent 方法；权威 source-truth 视图请看 `docs/reference/API_REFERENCE.md`。'
)

for pattern in "${architecture_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$architecture_doc"; then
    echo "[FAIL] architecture doc missing current convenience-surface truth: $pattern"
    exit 1
  fi
done

declare -a docs_readme_patterns=(
  '下面代码块列的是面向框架集成的最小关注面，不是 `v1.5.0` 当前 shipped source 的完整逐行镜像。'
  '当前 shipped source 还公开 `Close` / `DoHandshake` / `ReadString` / `WriteString` / timeout/blocking 等 connection-adjacent 或 compatibility-core 方法；完整 source-truth 请看 `docs/reference/API_REFERENCE.md`。'
)

for pattern in "${docs_readme_patterns[@]}"; do
  if ! grep -F -q "$pattern" "$docs_readme"; then
    echo "[FAIL] docs README missing current ISSLConnection slice truth: $pattern"
    exit 1
  fi
done

declare -a audit_patterns=(
  '但对 `ReadString` / `WriteString` / `SetTimeout` / `SetBlocking` 这组 convenience 方法，当前更准确的 shipped truth 是：'
  '- `v1.5.0` source 仍正式保留它们，builder 与活跃 guides 也仍在使用'
  '- 当前应先完成 classification / recommendation truth 收口，而不是把它们误报成“源码已经移除”'
)

for pattern in "${audit_patterns[@]}"; do
  if ! grep -F -q -- "$pattern" "$audit_doc"; then
    echo "[FAIL] audit doc missing current convenience-surface clarification: $pattern"
    exit 1
  fi
done

echo "[PASS] ISSLConnection convenience-surface classification docs match current shipped truth"
