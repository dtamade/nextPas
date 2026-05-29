#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$repo_root"

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

require_fixed() {
  local file="$1"
  local needle="$2"
  local message="$3"
  if grep -Fq -- "$needle" "$file"; then
    pass "$message"
  else
    fail "$message" "missing fixed string in $file: $needle"
  fi
}

proof_file="tests/winssl/test_winssl_session_resumption.pas"
api_ref="docs/reference/API_REFERENCE.md"
matrix_doc="docs/reference/WINSSL_BACKEND_CAPABILITY_MATRIX.md"
guide_doc="docs/guides/WINSSL_USER_GUIDE.md"
status_doc="docs/test_reports/WINSSL_BACKEND_STATUS_REPORT.md"
checklist_doc="tests/windows/WINDOWS_VALIDATION_CHECKLIST.md"
bundle_doc="tests/windows/VALIDATION_BUNDLE.md"

printf '[TEST] WinSSL session evidence-model truth contract\n'

require_fixed "$proof_file" \
  "evidence_model public_reuse_truth=conservative_shared_path native_probe_truth=isolated_worker_opt_in" \
  "WinSSL session-resumption proof must emit a stable evidence-model marker"

require_fixed "$proof_file" \
  "native_probe_enabled=%s native_observed_reuse=%s native_probe_succeeded=%s require_reuse=%s require_native_reuse=%s session_configured=%s" \
  "WinSSL session-resumption summary must keep public truth and native-probe truth separated"

require_fixed "$api_ref" \
  "> 由于 canonical shared path 当前继续撤下 live \`SECPKG_ATTR_SESSION_INFO\` probe 以避免 Windows AV，\`observed_reuse\` 在 broader/shared lane 上应按 conservative public truth 理解；更深 native evidence 需要查看 opt-in isolated native probe 输出的 \`native_observed_reuse\` / \`native_probe_succeeded\`。" \
  "API reference must explain the conservative shared-path truth versus isolated native probe"

require_fixed "$matrix_doc" \
  "> 由于 canonical shared path 当前继续撤下 live \`SECPKG_ATTR_SESSION_INFO\` probe 以避免 Windows AV，\`observed_reuse\` 当前应按 conservative public truth 理解；更深 native evidence 仍需看 opt-in isolated native probe 输出的 \`native_observed_reuse\` / \`native_probe_succeeded\`。" \
  "WinSSL backend matrix must explain the conservative shared-path truth"

require_fixed "$guide_doc" \
  "- ⚠️ 由于 canonical shared path 当前继续撤下 live \`SECPKG_ATTR_SESSION_INFO\` probe 以避免 Windows AV，broader/shared lane 里的 \`observed_reuse\` 当前应按 conservative public truth 理解；更深 native evidence 需看 opt-in isolated native probe 的 \`native_observed_reuse\` / \`native_probe_succeeded\`" \
  "WinSSL user guide must explain the conservative shared-path truth"

require_fixed "$status_doc" \
  '- **WinSSL session-resumption lane 现在会同时产出两层证据：shared/public 的 conservative truth，以及 opt-in isolated native probe truth；因此 `observed_reuse=false` 不能单独读成“已经直接证明 Schannel 没复用”**' \
  "WinSSL status report must explain the two-layer evidence model"

require_fixed "$status_doc" \
  '- 最新 opt-in native-probe 调查 run `26104446972` 进一步证明：当前 isolated worker 仍可能在 `QueryContextAttributesW(..., SECPKG_ATTR_SESSION_INFO, ...)` 之前/期间以 `native_probe_worker exit_code=-1073741819` 失败，因此 native probe lane 仍属于 investigatory evidence，而不是稳定 baseline。' \
  "WinSSL status report must record the current native-probe crash boundary"

require_fixed "$checklist_doc" \
  "[WINSSL-RUNTIME] session_resumption evidence_model public_reuse_truth=conservative_shared_path native_probe_truth=isolated_worker_opt_in" \
  "Windows checklist must document the evidence-model marker"

require_fixed "$checklist_doc" \
  "[WINSSL-RUNTIME] session_resumption summary host=... attempts=... observed_reuse=... native_probe_enabled=... native_observed_reuse=... native_probe_succeeded=... require_reuse=... require_native_reuse=... session_configured=..." \
  "Windows checklist must document the richer session-resumption summary marker"

require_fixed "$checklist_doc" \
  '方便后续直接在 artifact 里区分 shared/public conservative truth 与 opt-in native probe evidence，而不是把 `observed_reuse` 单独误读成“是否真的观测到 resumed handshake”的唯一结论。' \
  "Windows checklist must explain how to read the promoted markers"

require_fixed "$checklist_doc" \
  '如果这次是手动开启 native probe 的调查 run，还要额外检查 `native_probe_worker exit_code=...` 与最后一个 `stage=...` marker；当前 GitHub Windows runner 上，这条 lane 仍可能在 `before_query_context_attributes` 附近以 `-1073741819` 失败，所以它仍属于 investigatory evidence，而不是 broader suite 默认 baseline。' \
  "Windows checklist must document the current native-probe crash boundary"

require_fixed "$bundle_doc" \
  "[WINSSL-RUNTIME] session_resumption evidence_model public_reuse_truth=conservative_shared_path native_probe_truth=isolated_worker_opt_in" \
  "validation bundle inventory must document the evidence-model marker"

require_fixed "$bundle_doc" \
  "[WINSSL-RUNTIME] session_resumption summary host=... attempts=... observed_reuse=... native_probe_enabled=... native_observed_reuse=... native_probe_succeeded=... require_reuse=... require_native_reuse=... session_configured=..." \
  "validation bundle inventory must document the richer session-resumption summary marker"

require_fixed "$bundle_doc" \
  '方便后续在 artifact 里区分 shared/public conservative truth 与 opt-in native probe evidence，而不是把 `observed_reuse` 单独误读成“是否真的观测到 resumed handshake”的唯一结论。' \
  "validation bundle inventory must explain how to read the promoted markers"

require_fixed "$bundle_doc" \
  '如果这是开启 native probe 的专项调查，还应同时保存 `native_probe_worker exit_code=...` 和最后一个 `stage=...` marker；当前 GitHub Windows runner 上，这条 lane 仍可能在 `before_query_context_attributes` 附近以 `-1073741819` 失败。' \
  "validation bundle inventory must document the current native-probe crash boundary"

printf '[PASS] WinSSL session evidence-model truth contract passed\n'
