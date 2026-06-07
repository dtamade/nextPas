# nextPas Agent Rules

本文件是 AI 同事进入仓库后的第一入口。开始任何任务前先读这里，再读与任务相关的
`docs/architecture/`、`docs/plans/`、模块 README 和测试目录。

如果本文件、历史计划和用户当前指令冲突，以用户当前指令为准；稳定架构事实以
`docs/architecture/` 和 `docs/adr/` 为准。

## Authority Map

- `AGENTS.md`：仓库级 AI 协作、worktree、汇报、Git 安全和验证纪律。
- `core/AGENTS.md`：`nextpas.core` 专属 AI 入口，适用于直接在 `core/` 下开工的同事。
- `docs/worktrees.md`：项目本地 `.worktrees/` 与模块 lane 的操作规范。
- `core/docs/design-conventions.md`：`nextpas.core` 的设计风格、模块范式、分层约束、测试布局和代码组织规范。
- `docs/architecture/`：nextPas 编译器、toolchain、stage0、RTL/CRT 等仓库级稳定架构事实。
- `docs/plans/`：当前路线图、阶段计划和活动计划。

做 `core/` 下任何生产代码、测试、示例或 benchmark 改动前，必须先读
`core/AGENTS.md` 和 `core/docs/design-conventions.md`。不要用本文件替代 `nextpas.core` 的设计规范。

## Route By Task

- 仓库治理、分支/worktree 清理、landing：读本文件和 `docs/worktrees.md`。
- 编译器、toolchain、stage0、RTL/CRT：读本文件、`docs/architecture/README.md`、相关 roadmap / plan。
- `nextpas.core` 模块开发：读本文件、`core/AGENTS.md`、`core/docs/design-conventions.md`、模块文档。
- 文档或路线图修改：先确认权威层级。稳定事实进 `docs/architecture/` 或 `core/docs/design-conventions.md`；活动计划进 `docs/plans/` 或 `core/docs/plans/`。
- 不确定归属时，先做只读审计并汇报建议，不要先改跨模块代码。

## Start Here

- 先运行 `git status --short --branch`，确认当前分支和脏文件范围。
- 先运行 `git worktree list --porcelain` 或 `scripts/worktree-audit.sh`，确认自己在哪个 worktree。
- 不要在 `main` 上做普通模块开发。`main` 只用于总控 landing、仓库治理和明确授权的小修。
- 模块开发必须在项目根目录 `.worktrees/<module>` 下的专属 worktree 进行。
- 每个模块默认只有一个长期 lane 分支，例如 `codex/core-http`、`codex/core-math`、`codex/compiler`。
- 新建模块 worktree 使用 `scripts/worktree-add.sh <branch> [base]`，不要手写随机路径。
- 不要创建新的全局 worktree 到 `~/.config/superpowers/worktrees`、`.claude/worktrees` 或项目外目录。
- 详细规则见 `docs/worktrees.md`。
- 如果任务在 `core/` 内，继续读取 `core/AGENTS.md` 和 `core/docs/design-conventions.md` 后再改代码。

## Module Lane Discipline

- 一个 worktree 只负责一个模块或一条明确治理线。
- 模块 lane 是默认责任边界，不是架构设计边界。默认只改自己的模块路径；如果当前模块质量必须依赖其他模块、底座 API 或架构边界修正，可以做受控跨模块修改。
- 高层模块开发过程应当反哺低层模块。HTTP、TUI、config 等高层模块如果暴露出 platform、net、async、mem、base 等底层 contract 的设计缺陷，优先修正底层接口或实现，不要在高层堆 workaround 掩盖底层问题。
- 受控跨模块修改必须先说明原因：不改会阻碍哪个设计目标、涉及哪些路径、风险是什么、需要哪些额外验证。
- 跨模块改动必须是最小必要范围。不要借模块任务顺手重构无关模块，也不要偷偷把大范围架构迁移混进普通模块 slice。
- 跨模块改动要同时验证被改模块和当前模块的 consumer 行为；`Ready` 报告必须单独列出 cross-module touched files、设计理由、风险和验证证据。
- 如果跨模块影响面较大，先汇报 `Needs Review`，由总控决定是否拆成独立 cross-cutting lane 或 landing slice。
- 不要 raw merge 长期模块 lane 到 `main`。进入主线前创建 landing candidate，做 path-limited replay、cherry-pick 或等价小提交。
- 合并前必须证明：worktree clean、改动路径正确、focused verification 通过、`git diff --check` 通过、`make hygiene` 通过。
- 合并后模块 lane 必须重新基于最新 `main` 收敛，已完全吸收的临时 landing worktree 要删除。
- 干净不等于可合并。必须审查 diff 的质量和范围。

## Reporting

- 同事汇报只在有状态变化时进行，避免碎片化刷屏。
- 标准状态只用 `Ready`、`Blocked`、`Landed`、`Needs Review`。
- `Ready` 必须包含分支、worktree、HEAD、保留文件清单、禁止带入清单、focused verification 证据和 merge 建议。
- `Blocked` 必须说明阻塞条件、已尝试动作、下一步需要谁决策。
- `Landed` 必须说明进入 main 的提交、验证结果、是否已清理 worktree/分支。
- 不要把临时聊天记录、`task_plan.md`、`findings.md`、`progress.md` 直接带入主线，除非总控明确要求。

## Build And Artifact Hygiene

- 构建、测试、清理优先使用根目录 `Makefile`。
- 常用入口：`make hygiene`、`make clean`、`make rebuild-compiler`、`make test TEST_FILTER=<group>`、`make test-smoke`、`make focused FOCUS=core/tests/<module>/<gate>`、`make verify`。
- 不要让 `.o`、`.ppu`、`.a`、`.exe`、`.dll`、`.so`、`.dylib`、`link*.res`、`*.test.res` 等产物散落到源码目录。
- 不要强制添加生成物到 Git。`scripts/build-hygiene-check.sh` 会拦截源码树产物和已追踪产物。
- 临时产物应落在 `build/`、`.nextpas/`、`.sisyphus/` 等 ignored 目录。

## Testing

- 改动必须有 focused verification，不要只说“应该能过”。
- core test gate 优先从仓库根目录运行 `make focused FOCUS=core/tests/<module>/<gate>`；
  该入口会先后跑 `make hygiene`，并要求目标 Makefile 暴露 `clean` 和 `test`。
- 修 bug 要补回归测试或 source-contract 测试。
- 公共 API、模块门面、错误语义、内存/句柄生命周期变化必须覆盖边界输入和失败路径。
- 默认先跑本模块 focused gate；不要动不动跑全量 `make verify`。
- 如果 full gate 已知存在无关红点，必须明确记录当前红点和证据，不要为了变绿篡改期望。

## Code Quality

- 遵循现有 Pascal 风格和模块分层，不混用命名体系。
- 函数保持单一职责，重复逻辑要提取公共函数。
- 外部输入、路径、句柄、内存大小、整数边界都要做防御性检查。
- 资源必须有清晰所有权，文件、进程、socket、内存、映射和锁都要可靠释放。
- 不要绕过 owner boundary。需要改变 owner boundary 时，先看对应架构文档，并把边界变更作为显式设计决策记录在报告或文档中。

## Documentation

- 稳定架构事实写入 `docs/architecture/` 或 `docs/adr/`。
- 活动计划和设计路线写入 `docs/plans/`，不要把临时控制文件长期留在根目录。
- 模块工作流、测试入口和维护规则要同步更新 README 或模块文档。
- 文档必须描述当前真实状态，不要保留过时的“Production Ready”或已废弃路径说法。

## Git Safety

- 不要使用 `git reset --hard`、`git checkout -- <file>`、强制删除分支或删除 dirty worktree，除非用户明确授权。
- 不要修改不属于当前任务的 dirty 文件。
- 每个 commit 必须是一个可回滚的逻辑单元，提交前先看 `git diff --cached`。
- 推送前确认 `git status --short --branch`、`make hygiene` 和相关 focused gate。
