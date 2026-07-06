# Windows B07 证据闭环 Runbook（用于 future rerun / 保持 cross-ready）

更新时间：2026-05-19

## 目标

- 在 future source drift、future Windows evidence drift，或需要重刷 closeout 证据时，把 `freeze-status` 重新收回 `cross-ready=True`。
- 在需要重刷时，完成 Windows 实机证据链归档、校验与 finalize。

## 当前状态（2026-05-19）

- latest `win-evidence-preflight` 当前已是 `PASS / OK`。
- `windows_evidence_verify` 当前也已 PASS。
- 当前 canonical batch `SIMD-20260519-152` 已把 `freeze-status` 收回：
  - `ready=True`
  - `mainline-ready=True`
  - `cross-ready=True`
- 因此这页当前应按“维护 / future rerun playbook”理解，而不是当前 blocker 说明：
  - 当前模块总状态更准确地应按 `code-green / cross-ready` 记录
- 本机 Wine 只算 batch smoke / 日志新鲜度探针，不算真实 Windows evidence runner；即使它能刷新 `windows_b07_gate.log`，也不能把 manual Windows 路径视为已具备可 finalize 的 fresh evidence。
- 为避免把后文的通用步骤误读成当前状态声明，仍保留一条固定护栏提示：
- 下文若出现 `ready=True` / `cross-ready=True`，都应理解成“目标态 / 通过标准”，不是当前 `HEAD` 的现状。
- 当前 `HEAD` 的真实现状以上面的“当前状态（2026-05-19）”小节为准。

## 全局约束（Release-only）

- Linux/Git Bash/WSL 侧命令统一前缀：`FAFAFA_BUILD_MODE=Release`
- Windows PowerShell 先设置：`$env:FAFAFA_BUILD_MODE = 'Release'`
- Gate 回灌阶段启用 fail-close，并补 fresh CPUInfo mainline/full/full-repeat + lazy-repeat：`SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1` + `SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1` + `SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1` + `SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1` + `SIMD_GATE_CPUINFO_LAZY_REPEAT=3`

## 当前 worktree 真相

当前 worktree 当前不提供：

- `BuildOrTest.sh closeout-release`
- `BuildOrTest.sh win-evidence-preflight`
- `BuildOrTest.sh win-evidence-via-gh`
- `BuildOrTest.sh finalize-win-evidence`
- `BuildOrTest.sh evidence-linux`
- `BuildOrTest.sh win-closeout-snippets`
- `BuildOrTest.sh win-closeout-finalize`

当前这条 lane 仍保留的 live local path：

- `BuildOrTest.sh gate-summary-selfcheck`
- `BuildOrTest.sh freeze-status`
- `BuildOrTest.sh freeze-status-linux`
- `BuildOrTest.sh win-closeout-3cmd`
- `buildOrTest.bat evidence-win-verify`

如果你要从 Linux/Git Bash/WSL 侧把整条 release closeout 主线一波收口，直接运行：

`FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh closeout-release SIMD-YYYYMMDD-152`

它会固定执行 `win-evidence-preflight -> impl-smoke-x86 -> closeout-host-local -> win-evidence-via-gh -> freeze-status`。下面的 runbook 继续保留，是为了你拆分诊断 GH 预检、手工 Windows 实机路径或单独复验某一步时使用。

## 推荐顺序（主路径）

优先走单入口 GH 路径：

1. GH/额度预检（Git Bash / WSL）  
   `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-preflight`
2. 一条命令完成 dispatch + 下载 + 校验 + finalize（Git Bash / WSL）  
   `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-via-gh SIMD-YYYYMMDD-152`
3. 最终冻结确认（Git Bash / WSL）  
   `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status`

说明：

- `win-evidence-via-gh` 会把批次快照写到 `tests/nextpas.core.simd/logs/windows-closeout/<batch-id>/`，并同步回写 canonical `logs/` 指针，方便 `freeze-status` 默认入口直接消费。
- 默认 `win-evidence-via-gh` 会消费远端 ref。如果本地还有未提交或未推送的 closeout 修复，请先提交并推到目标 ref；否则脚本会直接拒绝 dispatch，避免浪费一轮 Windows runner。
- 若你已经有可复用的 GH Actions `run-id`，可执行 `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-via-gh SIMD-YYYYMMDD-152 <run-id>`。这条旁路会跳过 dispatch，只做下载、校验与 finalize，因此不会再因为本地 dirty worktree / remote ref mismatch 被误拒。
- `win-evidence-via-gh` 在下载并校验证据后，会自动补一轮 `SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1` + `SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1` + `SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1` + `SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1` + `SIMD_GATE_CPUINFO_LAZY_REPEAT=3` 的 Linux cross gate，再进入 `win-closeout-finalize`。
- `win-closeout-finalize` 是推荐主入口；它内部顺序固定为 `finalize -> freeze-status -> apply`。`finalize-win-evidence` 仅保留给拆分诊断或低层 helper 调用。
- `win-evidence-preflight` 现在会先扫描最近 failed run 的 `gh run view` 文本，再检查 Windows job 的 `check_run_url` annotations；只要命中 billing/quota/runner block 关键词，就会 fail-close 为 `RECENT_BILLING_BLOCK`。

## 手工 Windows 实机路径（兜底）

1. GH/额度预检（Git Bash / WSL）
   `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-preflight`
2. 采集 + 校验（Windows PowerShell）
   前提：本机必须能直接执行 native Windows `lazbuild.exe`；不要拿 Wine/cmd 冒充实机。
   若 Lazarus 不在默认路径，先显式指定：
   `$env:LAZBUILD = 'C:\Lazarus\lazbuild.exe'`
   `$env:FAFAFA_BUILD_MODE = 'Release'`
   `tests\nextpas.core.simd\buildOrTest.bat evidence-win-verify`
3. 回灌 cross gate（Git Bash / WSL，必需）
   `FAFAFA_BUILD_MODE=Release SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_QEMU_NONX86_EVIDENCE=0 SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 SIMD_GATE_CPUINFO_LAZY_REPEAT=3 SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate`
4. 一键收口（Git Bash / WSL）
   `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize SIMD-YYYYMMDD-152`
5. 最终冻结确认（Git Bash / WSL）
   `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status`

## 无 Windows 实机时（GH Windows Runner 路径）

1. 直接走 GH 收集 + 下载 + 校验 + closeout  
   `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-evidence-via-gh SIMD-YYYYMMDD-152`
2. 最终冻结确认（Git Bash / WSL）  
   `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status`

说明：

- `win-evidence-via-gh` 内部会先执行 `win-evidence-preflight`（可通过 `SIMD_WIN_EVIDENCE_PREFLIGHT=0` 关闭）。
- 该路径依赖 `gh` 已登录，且仓库存在可用 workflow：`.github/workflows/simd-windows-b07-evidence.yml`。
- 若传入显式 `run-id`，脚本会直接复用现成 workflow run，不再执行 dispatch 前的 dirty worktree / remote ref 一致性拒绝；适合在本地继续修脚本、但要先消费既有 Windows artifact 的场景。
- 如果你只是想单独重生 closeout summary 而不执行 freeze/apply，可使用低层 helper：`BuildOrTest.sh finalize-win-evidence`。
- `collect_windows_b07_evidence.bat` / `buildOrTest.bat evidence-win-verify` 现在默认优先走 native batch gate，避免静默绕开 Windows 自己的 `publicabi-smoke` 路径。只有在显式设置 `SIMD_WIN_EVIDENCE_USE_BASH_GATE=1` 时，才会切到 bash gate 口径做诊断性预演。
- `collect_windows_b07_evidence.bat` 会保存并恢复 `SIMD_OUTPUT_ROOT`，并把 sibling publicabi runner 固定到 `core/build/tests/nextpas.core.simd.publicabi`；不要让 Windows publicabi evidence 链隐式跟随 runner 默认输出根漂移。
- 这里的 `LAZBUILD` 必须解析到 native Windows `.exe/.bat/.cmd`；不要把它指到 `Z:\opt\...` 这种 Wine 可见但 `cmd.exe` 不能执行的 Linux ELF。
- 当前本机 Wine 探针里，`where bash` 在 `cmd.exe` 下不可用，`wine start /unix ...` 也没有形成可用的 `lazbuild` bridge；不要把 host-side Unix bridge 当成 native Windows `LAZBUILD` 的替代。
- native batch 采集路径不会额外导出 `gate_summary.json`；这是有意为之，因为该路径本身不生成一份新的 `gate_summary.md`，强行导出只会冒着复用旧摘要的风险。若你需要归档 `gate_summary.md/json`，请走 `win-evidence-via-gh`，或仅在 `cmd.exe` 真的能解析 `bash` 的环境里显式 opt-in `SIMD_WIN_EVIDENCE_USE_BASH_GATE=1` 做诊断性预演；当前本机 Wine 不属于这种环境。
- 因此手工 Windows 实机路径在 finalize 前必须显式补跑 fail-close cross gate；否则 `freeze-status` 只会继续消费旧的 `gate_summary.md`。

## 快捷入口

- 输出“复制即跑”的 3 命令：
  `bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-3cmd SIMD-YYYYMMDD-152`
- 输出文档回填片段（会按实时 verifier 结果标注“已归档/待补齐”）：
  `bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-snippets`
- 注意：`apply_windows_b07_closeout_updates.sh --apply` 在 Windows 证据校验失败时会拒绝写入“已完成”状态。

## 分步兜底

当第 2 步失败需要拆分诊断时，按顺序执行：

0. `powershell -NoProfile -Command "$env:FAFAFA_BUILD_MODE='Release'"`
1. `tests\nextpas.core.simd\buildOrTest.bat evidence-win`
2. `tests\nextpas.core.simd\buildOrTest.bat verify-win-evidence`
3. `FAFAFA_BUILD_MODE=Release SIMD_QEMU_PLATFORMS='linux/arm/v7 linux/arm64 linux/riscv64' SIMD_GATE_QEMU_NONX86_EVIDENCE=0 SIMD_GATE_QEMU_CPUINFO_NONX86_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_EVIDENCE=1 SIMD_GATE_QEMU_CPUINFO_NONX86_FULL_REPEAT=1 SIMD_GATE_QEMU_ARCH_MATRIX_EVIDENCE=0 SIMD_GATE_CPUINFO_LAZY_REPEAT=3 SIMD_GATE_REQUIRE_WINDOWS_EVIDENCE=1 bash tests/nextpas.core.simd/BuildOrTest.sh gate`
4. `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh win-closeout-finalize SIMD-YYYYMMDD-152`
5. `FAFAFA_BUILD_MODE=Release bash tests/nextpas.core.simd/BuildOrTest.sh freeze-status`

## 通过标准

- `tests/nextpas.core.simd/logs/windows_b07_gate.log` 存在且新鲜。
- `verify_windows_b07_evidence` 校验通过。
- `freeze-status` 显示：
  - `ready=True`
  - `mainline-ready=True`
  - `cross-ready=True`

## 常见阻塞

- `RECENT_BILLING_BLOCK`：这是 future fallback blocker；只有当 latest preflight 再次回到这个状态时，才先恢复 GitHub Billing/额度，再从预检重试。
- `windows_b07_gate.log` 过期：重新执行 `evidence-win-verify`。
- B07 关键头缺失（`Source/HostOS/CmdVer/Working dir`）：必须重新采集真实 Windows 日志，旧日志不可补写。
- closeout summary 与 verifier 不一致：执行 `win-closeout-finalize` 重新生成并应用。
- `win-closeout-snippets` 显示“待补齐”：说明实时 `verify_windows_b07_evidence` 未通过，需先完成 Windows 实机证据链。
