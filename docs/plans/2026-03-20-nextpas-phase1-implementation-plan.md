# nextPas 第一阶段实施计划

> **执行提示：** 必须使用 `superpowers:executing-plans`，按任务顺序执行这份计划。

**目标：** 在冻结的 FPC 基线、已批准的架构文档以及仅限 Linux x86_64 的范围内，执行任务 6-12，完成第一阶段剩余交付物。

**架构背景：** 本文档是 `docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md` 的可执行级配套计划。任务 1-5 已经完成并验证。剩余工作分四个批次推进：批次 B 搭仓库和验证路径，批次 C 增加 `stage0` 工具链与运行时规范，批次 D 增加 Linux CI 并完成最终验证波次。所有证据统一写入 `.sisyphus/evidence/`，且第一阶段承诺始终受限于 FreePascal `stage0` 与 Linux x86_64。

**技术栈：** Markdown、shell 脚本、FreePascal/FPC、Pascal 辅助单元、TOML 目标平台规格、GitHub Actions 工作流、`test`、`grep`、`rg`、`find`

---

## 执行规则

- 范围基准：在活动计划层级中，`docs/plans/2026-03-20-nextpas-phase1-bootstrap-plan.md` 仍然是范围和验收标准的直接来源；稳定边界继续以 `docs/adr/` 与 `docs/architecture/` 为准。
- 已完成前置：任务 1-5 已完成并验证。除非后续任务暴露出必须修正的矛盾，否则不要回头重做。
- 证据根目录：所有正向和负向验证输出都保存到 `.sisyphus/evidence/`。
- 进度纪律：每完成一个任务，都要在 `docs/plans/support/2026-03-20-nextpas-phase1-bootstrap-progress.md` 追加一个简短检查点，记录时间、状态、修改文件、证据路径、阻塞项和下一项就绪任务。
- Git 约束：当前工作区不是 Git 仓库。计划里的提交步骤都只作为指导。如果到执行时 Git 仍不可用，不要运行 `git add` 或 `git commit`，而是把原定提交信息记入进度日志。
- 平台与自举护栏：第一阶段保持仅限 Linux x86_64，以 FreePascal 为 `stage0`，不把自托管写成第一阶段目标，也不扩展到包管理器、IDE、格式化工具或 LSP 实现。
- 完成规则：任务 12 完成后，必须执行最终验证波次，把结果发给用户，并等待用户明确回复 `okay`，之后才能宣布第一阶段完成。

## 已完成前置

- 任务 1：`docs/adr/0001-fpc-reference-baseline.md` 已存在，并把 `/home/dtamade/freepascal/fpcsrc` 冻结为第一阶段参考树。
- 任务 2：`docs/architecture/overview.md` 已存在，并定义了保留的顶层边界、Linux x86_64 以及 FreePascal `stage0`。
- 任务 3：`docs/architecture/compatibility-matrix.md` 已存在，并明确把 ABI 兼容标记为延后。
- 任务 4：`docs/architecture/directory-structure-specification.md` 已存在，并定义了目录边界和现代 `compiler` 子模块布局。
- 任务 5：`docs/architecture/bootstrap-roadmap.md` 已存在，并定义了 `stage0`、`stage1`、`stage2` 与 promotion gate。
- 任务 6：仓库骨架与顶层 README 已存在，并与目录结构规范对齐。
- 任务 7：`harness` 控制面与 Pascal 骨架已存在，并通过最小公开接口验证。
- 任务 8：兼容性测试桶、首批 smoke 样例和快照资产已播种，`smoke` 视角已通过。
- 任务 9：`stage0` `nextpas` 驱动入口、配套 README 与 smoke 输入已存在，并通过
  FreePascal 编译和 `unsupported-command` 负向验证。
- 任务 10：Linux x86_64 目标规格与 Pascal 读取单元已存在，`stage0` driver 已改为从
  外置配置读取目标与工具链事实。
- 任务 11：RTL/CRT 架构规范已与仓库骨架对齐，`rtl/core/`、`rtl/core/system/` 与
  `rtl/crt/` 的首批 README 和占位文件已存在。
- 任务 12：Linux-only CI、本地验证入口与发行布局规范已存在，`verify_local` 路径可 fresh 通过。
- 当前状态：phase1 已完成；后续批次将转入新的主线计划，不再继续扩写本实施计划。

## 批次 B：搭建仓库与验证路径

### 任务 6：搭建现代仓库边界

**文件**

- 新建目录： `compiler/`, `compiler/frontend/`, `compiler/syntax/`, `compiler/sema/`, `compiler/ir/`, `compiler/backend/`, `compiler/targets/`, `compiler/driver/`, `compiler/diagnostics/`, `rtl/`, `rtl/core/`, `rtl/crt/`, `packages/`, `tests/`, `tools/`, `build/`
- 新建文档： `compiler/README.md`, `rtl/README.md`, `packages/README.md`, `tests/README.md`, `tools/README.md`, `build/README.md`
- 证据： `.sisyphus/evidence/task-6-repo-skeleton.txt`, `.sisyphus/evidence/task-6-repo-skeleton-error.txt`

**执行步骤**

1. 创建与架构边界一致的顶层目录，以及与现代化内部结构一致的 compiler 子目录。
2. 为 `compiler`、`rtl`、`packages`、`tests`、`tools` 和 `build` 编写简洁的顶层 `README.md`，明确责任与范围。
3. 保持脚手架最小化：不加入包管理器、不加入 IDE 资产、不加入 Linux x86_64 之外的平台分支。
4. 运行：
   ```bash
   for dir in \
     compiler rtl packages tests tools build docs/architecture docs/adr \
     compiler/frontend compiler/syntax compiler/sema compiler/ir \
     compiler/backend compiler/targets compiler/driver compiler/diagnostics \
     rtl/core rtl/crt
   do
     test -d "$dir" || exit 1
   done | tee .sisyphus/evidence/task-6-repo-skeleton.txt
   ```
   预期：所有必需目录都存在。
5. 运行：
   ```bash
   for file in \
     compiler/README.md rtl/README.md packages/README.md \
     tests/README.md tools/README.md build/README.md
   do
     test -f "$file" || exit 1
   done > .sisyphus/evidence/task-6-repo-skeleton-error.txt 2>&1
   ```
   预期：每个顶层区域都有责任说明文件。
6. 指导性提交信息：`chore(repo): scaffold nextpas repository boundaries`

### 任务 7：搭建验证 `harness` 骨架

**文件**

- 新建： `tests/run_all_tests.sh`, `tests/harness/README.md`, `tests/harness/runner.pas`, `tests/harness/snapshot_support.pas`
- 如有需要可修改： `tests/README.md`
- 证据： `.sisyphus/evidence/task-7-harness.txt`, `.sisyphus/evidence/task-7-harness-error.txt`

**执行步骤**

1. 实现 `tests/run_all_tests.sh`，让它支持 `--list-groups` 与 `--filter <group>`。
2. 实现 Pascal `harness` 骨架，使 `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt` 和 `regression` 套件的结构先成立。
3. 在 `tests/harness/README.md` 中说明 `harness` 行为，包括确定性的退出码和便于留证的输出规则。
4. 运行：
   ```bash
   test -x tests/run_all_tests.sh
   test -f tests/harness/README.md
   test -f tests/harness/runner.pas
   test -f tests/harness/snapshot_support.pas
   ./tests/run_all_tests.sh --list-groups \
     | tee .sisyphus/evidence/task-7-harness.txt
   ```
   预期：输出列出 `compiler-pass`、`compiler-fail`、`diagnostics`、`rtl`、`crt` 和 `regression`。
5. 运行：
   ```bash
   ! ./tests/run_all_tests.sh --filter does-not-exist \
     > .sisyphus/evidence/task-7-harness-error.txt 2>&1
   ```
   预期：harness 以非零状态退出，并打印清晰的 unknown-group 错误。
6. 指导性提交信息：`test(harness): add nextpas verification skeleton`

### 任务 8：补齐兼容性测试桶与 smoke 样例集

**文件**

- 新建目录： `tests/compiler/pass/`, `tests/compiler/fail/`, `tests/diagnostics/parser/`, `tests/rtl/`, `tests/crt/`, `tests/regression/`, `tests/snapshots/`
- 新建规范化样例： `tests/compiler/pass/hello_pass.pas`, `tests/compiler/fail/missing_semicolon_fail.pas`, `tests/diagnostics/parser/unclosed_block.pas`, `tests/rtl/sysutils_smoke.pas`, `tests/crt/console_smoke.pas`, `tests/regression/reference_regression.pas`
- 在需要处新建基线快照输出： `tests/snapshots/diagnostics-parser-unclosed_block.stderr.txt`, `tests/snapshots/compiler-fail-missing_semicolon.stderr.txt`
- 证据： `.sisyphus/evidence/task-8-smoke.txt`, `.sisyphus/evidence/task-8-smoke-error.txt`

**执行步骤**

1. 为每个已声明的类别补一个规范 smoke 样例，确保没有 harness 分组是空的。
2. 把 diagnostics 快照与 `compiler-pass` / `compiler-fail` 样例分开存放。
3. 把 CRT 样例保持在 `tests/crt/` 下，不要并入泛化 RTL 覆盖。
4. 运行：
   ```bash
   for dir in \
     tests/compiler/pass tests/compiler/fail tests/diagnostics/parser \
     tests/rtl tests/crt tests/regression
   do
     test -d "$dir" || exit 1
   done
   find tests/compiler/pass -type f | grep -q .
   find tests/compiler/fail -type f | grep -q .
   find tests/rtl -type f | grep -q .
   find tests/crt -type f | grep -q .
   ./tests/run_all_tests.sh --filter smoke \
     | tee .sisyphus/evidence/task-8-smoke.txt
   ```
   预期：harness 在每个已播种类别中都至少报告一个通过的 smoke 样例。
5. 运行：
   ```bash
   ./tests/run_all_tests.sh --filter compiler-fail \
     > .sisyphus/evidence/task-8-smoke-error.txt 2>&1
   ```
   预期：`compiler-fail` 样例被视为预期失败，而不是 harness 故障。
6. 指导性提交信息：`test(compat): seed nextpas smoke compatibility buckets`

**批次 B 退出标准**

- 仓库骨架已存在。
- `harness` 可以列出全部分组。
- smoke 路径已播种完成，且 `./tests/run_all_tests.sh --filter smoke` 能成功。

## 批次 C：加入 `stage0` 工具链与运行时规范

### 任务 9：实现 `stage0` `nextpas` 命令行驱动入口

**文件**

- 新建： `tools/stage0/nextpas.pas`, `tools/stage0/README.md`, `examples/smoke/hello.pas`
- 如有需要可修改： `tools/README.md`
- 证据： `.sisyphus/evidence/task-9-stage0-driver.txt`, `.sisyphus/evidence/task-9-stage0-driver-error.txt`

**执行步骤**

1. 实现 `tools/stage0/nextpas.pas`，对外只支持一个公开命令：`nextpas build <source> --target linux-x86_64`。
2. 在 `tools/stage0/README.md` 中说明用法、退出码和范围约束。
3. 添加 `examples/smoke/hello.pas` 作为规范 `stage0` 输入。
4. 运行：
   ```bash
   fpc tools/stage0/nextpas.pas
   ./tools/stage0/nextpas build examples/smoke/hello.pas --target linux-x86_64 \
     | tee .sisyphus/evidence/task-9-stage0-driver.txt
   ```
   预期：驱动入口能成功编译，并报告 smoke build 成功。
5. 运行：
   ```bash
   ! ./tools/stage0/nextpas frobnicate examples/smoke/hello.pas \
     > .sisyphus/evidence/task-9-stage0-driver-error.txt 2>&1
   ```
   预期：命令以非零状态退出，并打印清晰的 unsupported-command 消息。
6. 指导性提交信息：`feat(stage0): add nextpas build driver`

### 任务 10：外置 Linux x86_64 目标平台与工具链配置

**文件**

- 新建： `build/targets/linux-x86_64.toml`, `tools/stage0/target_config.pas`
- 修改： `tools/stage0/nextpas.pas`, `tools/stage0/README.md`
- 证据： `.sisyphus/evidence/task-10-target-config.txt`, `.sisyphus/evidence/task-10-target-config-error.txt`

**执行步骤**

1. 把受支持的目标平台定义移入 `build/targets/linux-x86_64.toml`。
2. 实现 `tools/stage0/target_config.pas`，让命令行入口从目标平台定义中读取配置，而不是把平台规则硬编码在代码中。
3. 目标平台列表保持单一：只支持 Linux x86_64。
4. 运行：
   ```bash
   test -f build/targets/linux-x86_64.toml
   test -f tools/stage0/target_config.pas
   grep -n "linux-x86_64" build/targets/linux-x86_64.toml
   ./tools/stage0/nextpas build examples/smoke/hello.pas --target linux-x86_64 \
     > .sisyphus/evidence/task-10-target-config.txt 2>&1
   ```
   预期：`stage0` build 能通过外置目标平台配置成功执行。
5. 运行：
   ```bash
   ! ./tools/stage0/nextpas build examples/smoke/hello.pas --target windows-x86_64 \
     > .sisyphus/evidence/task-10-target-config-error.txt 2>&1
   ```
   预期：不支持的目标平台会被清晰拒绝。
6. 指导性提交信息：`feat(targets): externalize linux x86_64 stage0 config`

### 任务 11：定义现代 RTL/CRT 规范与骨架

**文件**

- 对齐现有架构文档： `docs/architecture/rtl-specification.md`, `docs/architecture/crt-specification.md`
- 新建骨架文档： `rtl/core/README.md`, `rtl/core/system/README.md`, `rtl/crt/README.md`
- 新建最小占位文件： `rtl/core/system/system_placeholder.pas`, `rtl/crt/crt_placeholder.pas`
- 修改： `rtl/README.md`
- 证据： `.sisyphus/evidence/task-11-rtl-crt-contracts.txt`, `.sisyphus/evidence/task-11-rtl-crt-contracts-error.txt`

**执行步骤**

1. 复核 `docs/architecture/rtl-specification.md`，确认它已经定义现代化 RTL 边界、必须保留的 FPC 兼容行为，以及第一阶段非目标。
2. 复核 `docs/architecture/crt-specification.md`，确认它已经把控制台与 CRT 特有行为从泛化 RTL 文案中独立出来。
3. 创建 RTL 与 CRT 的骨架文件，并更新 `rtl/README.md`，为未来公开表面预留仓库位置。
4. 运行：
   ```bash
   test -f docs/architecture/rtl-specification.md
   test -f docs/architecture/crt-specification.md
   test -f rtl/core/README.md
   test -f rtl/core/system/README.md
   test -f rtl/core/system/system_placeholder.pas
   test -f rtl/crt/README.md
   test -f rtl/crt/crt_placeholder.pas
   grep -n "现代化" docs/architecture/rtl-specification.md
   grep -n "控制台" docs/architecture/crt-specification.md \
     | tee .sisyphus/evidence/task-11-rtl-crt-contracts.txt
   ```
   预期：RTL 与 CRT 的独立规范文档和骨架位置都存在。
5. 运行：
   ```bash
   ! grep -n "第一阶段完整 RTL 移植\\|第一阶段完整 CRT 替换" \
     docs/architecture/rtl-specification.md docs/architecture/crt-specification.md \
     > .sisyphus/evidence/task-11-rtl-crt-contracts-error.txt 2>&1
   ```
   预期：两个文档都不会过度承诺“立即完整移植”。
6. 指导性提交信息：`docs(runtime): define nextpas rtl and crt specifications`

**批次 C 退出标准**

- `tools/stage0/nextpas.pas` 可以通过 FPC 构建。
- Linux x86_64 目标平台配置已外置。
- RTL 与 CRT 的独立规范和骨架已经存在。

## 批次 D：加入 Linux CI 并完成最终验证波次

### 任务 12：加入 Linux CI 与本地验证入口

**文件**

- 新建： `.github/workflows/ci.yml`, `build/verify_local.sh`, `docs/architecture/distribution-layout-specification.md`
- 如有需要可修改： `tests/run_all_tests.sh`, `tools/stage0/README.md`, `build/README.md`
- 证据： `.sisyphus/evidence/task-12-local-verify.txt`, `.sisyphus/evidence/task-12-local-verify-error.txt`

**执行步骤**

1. 实现 `.github/workflows/ci.yml`，让它作为仅限 Linux 的工作流去检查 docs 是否存在、用 FPC 编译 `stage0` 驱动入口，并跑通 smoke `harness` 路径。
2. 实现 `build/verify_local.sh`，作为 CI 流程在本地的镜像。
3. 编写 `docs/architecture/distribution-layout-specification.md`，把未来发布布局明确为 `bin/`、`lib/`、`units/<target>/` 和 `share/`。
4. 运行：
   ```bash
   test -f .github/workflows/ci.yml
   test -x build/verify_local.sh
   test -f docs/architecture/distribution-layout-specification.md
   ./build/verify_local.sh | tee .sisyphus/evidence/task-12-local-verify.txt
   ```
   预期：脚本会检查 docs、构建 `stage0` 驱动入口，并成功跑通 smoke `harness`。
5. 运行：
   ```bash
   grep -n "Linux" .github/workflows/ci.yml
   grep -n "bin/\\|units/<target>/\\|share/" \
     docs/architecture/distribution-layout-specification.md
   grep -n "ubuntu\\|linux" .github/workflows/ci.yml
   ! grep -n "windows\\|macos" .github/workflows/ci.yml \
     > .sisyphus/evidence/task-12-local-verify-error.txt 2>&1
   ```
   预期：工作流保持仅限 Linux，发行布局也保持显式。
6. 指导性提交信息：`ci(linux): add nextpas local and github verification`

## 最终验证波次

只有在 任务 12 通过后才能运行这里的内容。结果必须发给用户，并等待用户明确回复
`okay`，之后才能标记第一阶段完成。

### F1：计划一致性审计

- 证据： `.sisyphus/evidence/f1-plan-compliance.txt`
- 运行：
  ```bash
  for path in \
    docs/architecture/directory-structure-specification.md \
    docs/architecture/bootstrap-roadmap.md \
    docs/architecture/rtl-specification.md \
    docs/architecture/crt-specification.md \
    docs/architecture/distribution-layout-specification.md \
    tests/run_all_tests.sh \
    tools/stage0/nextpas.pas \
    build/targets/linux-x86_64.toml \
    build/verify_local.sh \
    .github/workflows/ci.yml
  do
    test -e "$path" || exit 1
    printf '%s\n' "$path"
  done | tee .sisyphus/evidence/f1-plan-compliance.txt
  ```

### F2：质量与构建复核

- 证据： `.sisyphus/evidence/f2-quality-review.txt`
- 运行：
  ```bash
  fpc tools/stage0/nextpas.pas
  ./tests/run_all_tests.sh --list-groups
  ./tests/run_all_tests.sh --filter smoke
  ./build/verify_local.sh \
    | tee .sisyphus/evidence/f2-quality-review.txt
  ```

### F3：手工 QA 回放

- 证据： `.sisyphus/evidence/f3-manual-qa.txt`
- 运行：
  ```bash
  ./tools/stage0/nextpas build examples/smoke/hello.pas --target linux-x86_64
  find tests -maxdepth 3 -type f | sort
  find tools -maxdepth 3 -type f | sort
  find build -maxdepth 3 -type f | sort \
    | tee .sisyphus/evidence/f3-manual-qa.txt
  ```

### F4：范围忠实度检查

- 证据： `.sisyphus/evidence/f4-scope-fidelity.txt`
- 运行：
  ```bash
  grep -n "ABI compatibility is deferred" docs/architecture/compatibility-matrix.md
  ! grep -n "第一阶段.*自托管" docs/architecture/bootstrap-roadmap.md
  ! grep -n "windows\\|macos" .github/workflows/ci.yml
  ! grep -n "windows-x86_64\\|darwin" build/targets/linux-x86_64.toml \
    | tee .sisyphus/evidence/f4-scope-fidelity.txt
  ```

## 建议执行顺序

1. 批次 B：任务 6，然后任务 7，再任务 8。
2. 批次 C：任务 9，然后任务 10，再任务 11。
3. 批次 D：任务 12，然后 F1-F4。

## 指导性提交顺序

由于当前工作区还不是 Git 仓库，以下内容仅作为未来提交拆分建议。

1. `chore(repo): scaffold nextpas repository boundaries`
2. `test(harness): add nextpas verification skeleton`
3. `test(compat): seed nextpas smoke compatibility buckets`
4. `feat(stage0): add nextpas build driver`
5. `feat(targets): externalize linux x86_64 stage0 config`
6. `docs(rtl): define nextpas rtl and crt contracts`
7. `ci(linux): add nextpas local and github verification`
