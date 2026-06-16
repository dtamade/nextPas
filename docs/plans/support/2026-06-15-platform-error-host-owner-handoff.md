# platform.error.pas Host Owner Uses Handoff

- 日期：2026-06-15
- 来源：main 上的 dirty 改动（已 checkout 恢复）
- 接手 lane：`.worktrees/core-platform`（branch `codex/core-platform`）
- 状态：pending，等 core-platform lane 在自己 workflow 内并入

## 为什么作为 handoff 文档而不是直接 apply 到 lane

发现于接手治理调研：

1. main HEAD `9c2479ef1` 上有 1 个 dirty `core/src/nextpas.core.platform.error.pas`
   （+9 行，按宿主条件引入 linux/darwin/freebsd base 单元）。
2. dirty 出现在 main 上违反 `AGENTS.md` "main 不做模块开发" + nextpas-goal-tree.md
   "core 由 core 负责人写"双纪律。
3. 直接把 patch apply 到 `.worktrees/core-platform`：
   - lane HEAD `5c00afec` 落后 main 37 个 commit，platform.error.pas 在 lane 上的
     当前形态与 main 上的 baseline 不同（lane 上没有 `nextpas.core.platform.sync.base`
     这一行，且 `{$IFDEF}` 块没有以逗号紧跟），patch 找不到匹配 hunk context；
   - lane 自身有 4 file M + 1 file ?? dirty（IOCP / io.reactor / Wine CI matrix
     相关），我擅自在他人 active dirty worktree 上叠改动违反
     `AGENTS.md` "不要修改不属于当前任务的 dirty 文件"。

因此选择把 patch + 设计理由打包成本 handoff 文档，由 core-platform lane 同事
（或获得授权的 core 接手者）在自己时机合并，并按 lane 当前 baseline 调整 hunk context。

## 设计动机

按 `core/docs/design-conventions.md` §18：

> 不仅 errno token 要按宿主 owner，下层"当前 errno storage 在哪里"也属于 host ABI truth。
> 外部 errno location 绑定应放进 `linux/darwin/android/freebsd/unix` 等 host ffi owner
> 单元……

`platform.error.pas` 中 `platform_error_category()` 实际消费 `ESysENOENT` /
`ESysEPERM` / `ESysEACCES` / `ESysEEXIST` / `ESysEADDRINUSE` / `ESysENETUNREACH` /
`ESysEHOSTUNREACH` / `ESysENOTCONN` / `ESysENOMEM` / `ESysENOSPC` / `ESysEINVAL` /
`ESysEOPNOTSUPP` / `ESysETIMEDOUT` / `ESysEAGAIN` / `ESysEBUSY` / `ESysEIO` /
`ESysEPIPE` / `ESysECONNABORTED` / `ESysECONNRESET` / `ESysECONNREFUSED` /
`ESysEINTR` 等 token，这些的真实 owner 在各 host 的 `*.base.errno.inc`：

- `core/src/nextpas.core.platform.linux.base.errno.inc`
- `core/src/nextpas.core.platform.darwin.base.errno.inc`
- `core/src/nextpas.core.platform.freebsd.base.errno.inc`

仅 uses shared `posix.base + posix.ffi` 拿不到这些 host-specific errno token。所以需要
按当前宿主 conditional 引入对应 host base。

## 改动详情（原始 patch）

原始 `git diff` 输出（在 main HEAD `9c2479ef1` 上）：

```diff
diff --git a/core/src/nextpas.core.platform.error.pas b/core/src/nextpas.core.platform.error.pas
index 804c18884..96ea25465 100644
--- a/core/src/nextpas.core.platform.error.pas
+++ b/core/src/nextpas.core.platform.error.pas
@@ -28,6 +28,15 @@ uses
   nextpas.core.platform.posix.base,
   nextpas.core.platform.posix.ffi,
   {$ENDIF}
+  {$IFDEF NEXTPAS_LINUX}
+  nextpas.core.platform.linux.base,
+  {$ENDIF}
+  {$IFDEF NEXTPAS_MACOS}
+  nextpas.core.platform.darwin.base,
+  {$ENDIF}
+  {$IFDEF NEXTPAS_FREEBSD}
+  nextpas.core.platform.freebsd.base,
+  {$ENDIF}
   {$IFDEF NEXTPAS_WINDOWS}
   nextpas.core.platform.windows.base,
   nextpas.core.platform.windows.ffi,
```

## core-platform lane 应该如何合并

core-platform lane 同事接到本 handoff 后建议步骤：

1. 在 lane 内决定是否先 rebase / merge `main` 让 baseline 对齐（lane 当前落后 37 commit）。
2. 在新 baseline 下：找到 `implementation uses` 块，按当前真实形态加入：

   ```pascal
   {$IFDEF NEXTPAS_LINUX}
     nextpas.core.platform.linux.base,
   {$ENDIF}
   {$IFDEF NEXTPAS_MACOS}
     nextpas.core.platform.darwin.base,
   {$ENDIF}
   {$IFDEF NEXTPAS_FREEBSD}
     nextpas.core.platform.freebsd.base,
   {$ENDIF}
   ```

   注意 syntax 细节：每个 `{$IFDEF}` / `{$ENDIF}` 块结束后是否需要紧跟逗号，取决于
   lane baseline 上 uses 子句的当前组织方式。

3. 验证：
   - Linux x86_64：focused gate `make focused FOCUS=core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix`
     必须能在 `NEXTPAS_FORCE_HOST_LINUX` / `NEXTPAS_FORCE_HOST_DARWIN` /
     `NEXTPAS_FORCE_HOST_FREEBSD` override 下都通过 compile-only 检查。
   - 真实 Linux runtime：`make focused FOCUS=core/tests/nextpas.core.platform/<error-related-gate>`
     如果 lane 上有 error 模块的 runtime gate，必须保持绿。
   - `make hygiene` + `git diff --check` 必须通过。

4. Ready 报告时把本文档路径列入 evidence。

## 旁路决策

如果 core-platform lane 同事评估该 patch 等价改动已经在 lane 内的某个未完成 slice
内被覆盖，可以直接在 Ready 报告里说明 "本 handoff 内容已被 commit `<sha>` 吸收"，
并由总控决定是否归档本文档。

## main 上的恢复操作记录

执行：

```bash
git checkout -- core/src/nextpas.core.platform.error.pas
```

恢复后 `main` 工作树应回到 clean 状态（HEAD `9c2479ef1`）。
