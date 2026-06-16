# core-platform Lane Review

- 日期：2026-06-15
- 评审者：接手 AI（按 takeover plan §P1.x）
- 评审对象：`.worktrees/core-platform` 当前 dirty
- 评审范围：dirty 文件设计合理性 + 与 handoff doc 的关系 + 下一步建议
- 性质：**初步意见**，最终由 lane owner（codex/core-platform 维护者）判断

## Lane 概况

| 项 | 值 |
|---|---|
| Worktree | `.worktrees/core-platform` |
| 分支 | `codex/core-platform` |
| HEAD | `5c00afec5 docs(platform): update P3/P4 with Wine CI matrix evidence` |
| 落后 main | 37 commit |
| Dirty | 4 M + 1 ?? |

## Goal-Tree 当前位置（截至 lane HEAD）

| Milestone | 目标 | 当前 truth | Next proof |
|---|---|---|---|
| P1 Host ABI inventory | Host 常量/记录/句柄/raw decl | ✅ complete | keep gap matrix current |
| P2 Feature facades | 14 portable APIs | ✅ 14/14 focused-runtime on Windows (real VM via SSH) | expand consumer coverage |
| P3 Readiness lane | poller / wake / userdata / empty-interest | Linux runtime + Windows source/compile + Wine CI matrix ✅ | real-Windows CI runner |
| P4 Completion lane | IOCP/proactor + async loop | ✅ focused-runtime (AsyncSend/Recv/Accept/Connect + close/timeout drain) | promote to ci-matrix |
| P5 Tier 2 targets | Windows aarch64, riscv64/arm32, FreeBSD/Android | source/compile fragments | cross-compile + runtime matrix |
| P6 Benchmarks | Platform performance comparison | deferred | only after contract/runtime truth stabilizes |

## Dirty 改动评审

### ✅ `core/src/nextpas.core.io.reactor.iocp.pas`（cleanup, +1/-7）

- **格式 reformat**（行 237）：`GetQueuedCompletionStatus` 调用合到一行，纯格式化
- **删除 4 处显式 `IocpUnlinkOp`**（行 ~437/481/680/721）：
  - `IocpFreeOp(var AReactor; AOp; AUnlink: Boolean = True)` 的默认参数即为 `AUnlink=True`
  - 旧版 `IocpUnlinkOp(...); IocpFreeOp(...)` 是**重复 unlink**（free 内又调一次）
  - 新版直接 `IocpFreeOp(...)` 依赖默认参数，单次 unlink
  - 行 527-532 仍保留 `IocpUnlinkOp(...); IocpFreeOp(..., False);` 的"显式 unlink + 跳过 free 内 unlink"分离模式，说明 lane owner 对该 toggle 设计明确
- **风险审计**：需要确认 `IocpUnlinkOp` 是幂等的。旧版的重复 unlink 既然通过了 Wine CI matrix + real Windows VM SSH 验证，可推断它幂等
- **结论**：✅ 接受。建议 commit message 写明 *"remove redundant IocpUnlinkOp calls before IocpFreeOp(AUnlink=True default)"*

### ✅ `core/src/nextpas.core.platform.fs.pas`（refactor, +14/-23）

- 把 `platform_fs_mktemp` 内部逻辑提取到 `platform_fs_mktemp_impl`，让 fd-flavor 和 handle-flavor 共享 impl
- 旧版：`mktemp_handle` 调 `mktemp` 再做 fd→handle 转换
- 新版：两个 public API 各自最少封装直接调 impl，`mktemp_handle` 不再做 fd↔handle 双向转换
- **设计公约对照**：符合 `core/docs/design-conventions.md` §6 — handle-native API 优先 native handle 路径，不要被 fd-flavor 强行套一层转换
- **结论**：✅ 接受

### ✅ 新增 `core/tests/nextpas.core.platform/test_platform_wine_ci_matrix_contract/`

- Wine CI matrix 的 source-contract gate（Makefile + .lpr）
- 完善 P3 readiness 的 source-contract 覆盖
- **结论**：✅ 接受，符合 goal-tree §P3 "next proof: real-Windows CI runner" 方向

### ✅ 测试增强（poller_windows_contract +96/-, reactor_iocp_wine +23/-）

- 测试增强；目录看不出 regression 风险
- **建议**：跑 focused gate 验证之后 commit

## 与归档 handoff doc 的关系

`docs/plans/support/2026-06-15-platform-error-host-owner-handoff.md` 已在 main 落盘
（commit `ed4322d4f`），目标 lane = core-platform，目标改动 = `core/src/nextpas.core.platform.error.pas`
按宿主条件引入 linux/darwin/freebsd base 单元。

**lane 状态对 apply 的影响**：

- lane HEAD `5c00afec5` 落后 main 37 个 commit
- lane 内 `platform.error.pas` 形态老（implementation uses 缺 `nextpas.core.platform.sync.base`，
  IFDEF 块不带逗号）
- main 上 dirty patch 的 hunk context（`nextpas.core.platform.posix.base, nextpas.core.platform.posix.ffi, {$ENDIF}`）
  在 lane 上找不到匹配，patch 不能干净 apply

**建议 lane 处理顺序**：

1. 先完成当前 dirty 4 文件的 commit（不混入 handoff，保持 logical slice 清晰）
2. 决定 sync main 策略（merge --no-ff 或 rebase）
3. sync 之后再 apply handoff patch（按当前 baseline 调整 hunk context；具体形态见
   `docs/plans/support/2026-06-15-platform-error-host-owner-handoff.md` §"core-platform lane 应该如何合并"）
4. 验证：focused gate `test_platform_simulated_host_compile_matrix` 在
   `NEXTPAS_FORCE_HOST_LINUX/DARWIN/FREEBSD` override 下都过

## 推荐 lane 下一步

| 优先级 | 动作 | 估算 |
|---|---|---|
| P1 | commit 当前 4 个 dirty 按 logical slice 拆：IOCP cleanup / fs mktemp refactor / Wine CI matrix source-contract / 测试增强 | 4 个 commit |
| P2 | 跑 focused gate 验证：`make focused FOCUS=core/tests/nextpas.core.platform/test_platform_wine_ci_matrix_contract` + IOCP / fs 相关 gate + heaptrc/no-leak 证据 | 数分钟 |
| P3 | 决定 sync main 策略（merge / rebase / 等待），吸收 handoff patch（platform.error.pas host owner uses） | 一次 sync + 一个 commit |
| P4 | 继续 goal-tree §P3 next proof：real-Windows CI runner（已是 Wine CI matrix 之后的自然下一步） | 中等 |
| P5 | 持续推进 §P5 Tier 2 targets：Windows aarch64 / riscv64 / FreeBSD / Android cross-compile + runtime matrix | 远期 |

## 评审纪律说明

按 nextpas-goal-tree.md "core 由 core 团队推进"，本评审：

- ❌ 不动 lane 代码
- ❌ 不在 lane 内创建新文档（lane owner 自己管 `task_plan.md` / `findings.md` / `progress.md`）
- ✅ 只读分析 + 主线治理文档形式留下评审记录
- ✅ 评审输出由 lane owner 自行采纳或反驳；本文档是"接手者初步意见"不是"强制方案"

如果 lane owner 不同意某个评审点（尤其是 IocpUnlinkOp 删除的设计判断），请在 lane 内
`findings.md` 或新增 reply doc 反馈，本文档不主动修订。
