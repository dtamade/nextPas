# Pre-session Build Context Projection Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 stage0 在 session 创建前就已经解析出的 build command context（尤其是 workspace/artifact/output 相关 truth）也变成正式 failure projection，避免 `invalid-unit-root` 这类 early failure 退回成只有 `failureKind` 的贫血结果。

**Architecture:** 不引入第二套 session，也不把 driver 变成新的 truth owner。继续沿用 `tools/stage0/nextpas.pas` 里的 `Active...` command context，把已知的 source/target/workspace/artifact/output/package-manifest facts 在 session 之前先 capture 成 command-level truth；CLI line-based output 与 `command-envelope=<json>` 仍只做稳定 projection。

**Tech Stack:** FreePascal/Object Pascal, `tools/stage0/nextpas.pas`, shell verification in `build/verify_local.sh`.

---

### Task 1: 写 RED gate，冻结 early failure 的最小 build context surface

**Files:**
- Modify: `build/verify_local.sh`

**Step 1: Write the failing test**

为现有 `invalid-unit-root-check` 增加断言：
- line-based output 包含：
  - `workspace-root=`
  - `workspace-discovery-kind=explicit-workspace-override`
  - `artifact-root=`
  - `output-dir=`
- `command-envelope=<json>.result` 同步包含：
  - `workspaceRoot`
  - `workspaceDiscoveryKind`
  - `artifactRoot`
  - `outputDir`
  - 继续保留 `failureKind=invalid-unit-root`

**Step 2: Run test to verify it fails**

Run: `bash build/verify_local.sh`
Expected: FAIL，因为当前这些字段只有 session capture 后才会进入 projection，而 `invalid-unit-root` 在 session 创建前就失败了。

**Step 3: Confirm failure is the expected RED**

确认失败点落在新增的 invalid-unit-root pre-session projection 断言，而不是别的 gate。

### Task 2: 让 stage0 在 session 前也拥有最小 build context projection

**Files:**
- Modify: `tools/stage0/nextpas.pas`

**Step 1: Capture known command context as early as possible**

在 `RunBuild(...)` 中，把这些事实在 session 创建前就 capture 进 `Active...`：
- source path
- target id/name
- workspace root
- workspace discovery kind
- workspace descriptor path
- package manifest path（如果已知）
- artifact root
- output dir

保持 discovery 逻辑本身不变。

**Step 2: Project without requiring session-id**

让 failure path 在没有 `session-id` 的情况下，也能稳定打印已经已知的 command context，
但不要因此伪造 `syntax-status`、`diagnostics-count`、`session-id` 等 session-owned fields。

**Step 3: Keep scope small**

本批不扩成“所有失败都必须拥有完整 pseudo-session projection”；
只确保已经确定的 command-level truth 不会因为 session 尚未创建而丢失。

### Task 3: 运行 verify 并同步规划文件

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`
- Optionally modify: `docs/architecture/stage0-driver-specification.md`
- Optionally modify: `tools/stage0/README.md`

**Step 1: Run full verification**

Run: `bash build/verify_local.sh`
Expected: PASS。

**Step 2: Sync persistent notes**

记录：
- 当前 stage0 已开始把 pre-session command truth 投影到 early failure path
- 这不等于完整 session-less diagnostics model；只是把已知 build context 补齐
- 仍然不宣称完整 workspace model 或 richer failure envelope 已完成
