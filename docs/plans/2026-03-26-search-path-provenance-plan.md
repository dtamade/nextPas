# Search Path Provenance Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 unit resolution 的 search roots 接入 typed package/workspace provenance，并把这些 provenance 暴露到诊断与 CLI 输出里，形成可验证闭环。

**Architecture:** 保留现有 `ProjectUnitRoots` 字符串数组给 toolchain `-Fu` 拼接使用，同时新增一条 typed metadata 通路：manifest/workspace 解析层产出带 provenance 的 root records，resolver 将它们接入 `TSearchPathSet`，CLI/session 再把这些 entry 序列化出来。missing/ambiguous diagnostics 继续基于真实 consulted roots，但不再只剩裸路径字符串。

**Tech Stack:** FreePascal/Object Pascal, shell verification (`build/verify_local.sh`), existing stage0 session/result envelope.

---

### Task 1: 定义 typed search-root / project-root metadata

**Files:**
- Modify: `compiler/frontend/np_unit_graph.pas`
- Modify: `compiler/frontend/np_package_manifest.pas`
- Modify: `compiler/frontend/np_compilation_session.pas`

**Step 1: Write the failing test**

在现有 verify 脚本旁新增对 `search-path-json`（或等价 search-path detail 输出）的断言，要求 package manifest root 与 workspace member root 分别带上 provenance 字段，例如 `scopeName`、`provenanceKind`、`packageName`、`manifestPath`、`workspaceMemberPath`。

**Step 2: Run test to verify it fails**

Run: `bash build/verify_local.sh`
Expected: FAIL，因为当前只输出 `search-path-count`，没有 typed provenance detail。

**Step 3: Write minimal implementation**

- 在 `np_unit_graph.pas` 为 `TSearchPathEntry` 增加 provenance fields，并给 `AddRoot` 增加 metadata 参数。
- 在 `np_package_manifest.pas` 新增 project root info record / array，返回 package manifest roots 与 workspace member roots 的 typed metadata。
- 在 `np_compilation_session.pas` 新增可枚举/序列化 search path detail 的访问面。

**Step 4: Run targeted verification**

Run: `bash build/verify_local.sh`
Expected: 进入下一类失败，说明 detail 输出已出现但诊断/断言还未完全对齐。

### Task 2: 让 resolver 真实消费 typed provenance

**Files:**
- Modify: `compiler/frontend/np_unit_resolver.pas`
- Modify: `compiler/frontend/np_compilation_session.pas`
- Modify: `tools/stage0/nextpas.pas`

**Step 1: Write the failing test**

为 package manifest source root 与 workspace member source root 的 verify case 增加断言：
- CLI 输出包含完整 `search-path-json`
- entry 顺序仍符合 precedence
- workspace member entry 能区分 `workspace-member-package-source-root`

**Step 2: Run test to verify it fails**

Run: `bash build/verify_local.sh`
Expected: FAIL，resolver 当前仍把 project roots 一律写成 `package-source-root`，CLI 也还没有对应 JSON/detail 序列化。

**Step 3: Write minimal implementation**

- `TUnitResolver` 改为接收 typed project root infos，并在 `BuildSearchPaths` 中把 provenance 写进 `TSearchPathSet`。
- `tools/stage0/nextpas.pas` 把 session search path detail 输出为稳定 JSON 字段（例如 `search-path-json=`）。
- 保持 toolchain 的 `-Fu` 仍然消费原有字符串 roots，避免扩大改动面。

**Step 4: Run targeted verification**

Run: `bash build/verify_local.sh`
Expected: provenance detail 断言通过；若 diagnostics 断言仍失败，进入 Task 3。

### Task 3: 把 consulted roots / candidate origins 接进 resolution diagnostics

**Files:**
- Modify: `compiler/frontend/np_unit_resolver.pas`
- Modify: `build/verify_local.sh`
- Optionally modify: `docs/architecture/unit-resolution-specification.md`

**Step 1: Write the failing test**

为缺失 unit / ambiguous unit 场景增加断言，要求 diagnostics message 或 JSON envelope 中出现更可解释的 consulted root / candidate origin 信息，而不只是裸路径拼接。

**Step 2: Run test to verify it fails**

Run: `bash build/verify_local.sh`
Expected: FAIL，因为当前 diagnostics 只有 plain searched roots / candidate paths。

**Step 3: Write minimal implementation**

- 在 resolver 中基于 `TSearchPathSet` detail 生成稳定 summary。
- missing-unit diagnostics 带 consulted root provenance。
- ambiguous-unit diagnostics 带 candidate origin provenance。
- 文档只同步当前真实已落地事实，不提前夸大完整 workspace graph。

**Step 4: Run targeted verification**

Run: `bash build/verify_local.sh`
Expected: PASS。

### Task 4: 同步 planning / findings / progress

**Files:**
- Modify: `task_plan.md`
- Modify: `findings.md`
- Modify: `progress.md`

**Step 1: Update persistent session files**

记录本轮目标、决策、验证结果、未完成边界。

**Step 2: Re-run verification before claiming success**

Run: `bash build/verify_local.sh`
Expected: PASS。
