# Worktree 与模块 Lane 规范

## 核心规则

本仓库所有项目自有的 linked worktree 必须放在仓库根目录下：

```text
.worktrees/<短名称>
```

`.worktrees/` 已被 Git 忽略，不能作为源码提交。不要再把新的 nextPas
worktree 建到 `~/.config/superpowers`、`.claude/worktrees` 或任意项目外目录。

## 模块 Lane

每个活跃模块或治理线使用一个长期 worktree。这样 AI 同事的会话上下文、分支状态和模块责任都能稳定恢复。

推荐目录：

```text
.worktrees/core-http
.worktrees/core-math
.worktrees/core-mem
.worktrees/core-platform
.worktrees/core-simd
.worktrees/compiler
```

推荐分支名：

```text
codex/core-http
codex/core-math
codex/core-mem
codex/core-platform
codex/core-simd
codex/compiler
```

不要每次提示词都新建一个日期分支。模块 lane 是长期延续分支；在 lane 内用小提交推进。
只有准备进入主线时，才临时创建 `landing/<module>-YYYYMMDD` 这类候选分支。

模块 lane 是默认责任边界，不是架构设计边界。负责人默认在本模块内工作，但如果当前模块要达到正确的
API、性能或架构质量，必须修正依赖模块或底座 contract，可以做受控跨模块修改。跨模块修改要先说明
设计原因、风险、触碰路径和验证计划；影响面较大时先汇报 `Needs Review`，不要把大范围架构迁移混进
普通模块 slice。

高层模块开发是低层模块设计的压力测试。HTTP、TUI、config、app 这类高层模块如果发现 platform、
net、async、mem、base 等底层接口不顺、语义错误或性能路径不合理，应通过受控跨模块修改推动底层收敛，
而不是在高层长期保留 workaround。最终 landing 时由验证和设计说明来判断哪套方案更合理。

## 创建模块 Worktree

使用项目脚本：

```bash
scripts/worktree-add.sh codex/core-http main
```

脚本会创建：

```text
.worktrees/core-http
```

如果分支已经存在，脚本会把它 checkout 到该目录；如果分支不存在，默认从 `main` 创建：

```bash
scripts/worktree-add.sh codex/core-http main
```

然后从对应 worktree 目录恢复 AI 会话：

```bash
cd .worktrees/core-http
codex
```

或：

```bash
cd .worktrees/core-http
claude
```

只有总控或明确被授权的同事可以创建新模块 lane。模块负责人应该从分配的 worktree
继续工作，不要自己再开旁路分支。

## 审计 Worktree

运行：

```bash
scripts/worktree-audit.sh
```

审计会列出每个 linked worktree、所在分支、是否 dirty，以及是否位于项目本地
`.worktrees/` 目录内。任何非 `main` 的 linked worktree 如果不在 `.worktrees/`
下，都属于规范违规。

以下场景必须先跑审计：

- 分支清理前。
- landing 批次前。
- 用户询问仓库是否仍有 worktree 或分支债务时。

## 迁移已有 Worktree

不要用 `mv` 手动移动 worktree。必须让 Git 更新 `.git/worktrees` 元数据：

```bash
git worktree move <旧路径> .worktrees/<短名称>
```

迁移前必须确认该 worktree 的负责人没有正在其中运行 AI 会话、构建或测试。

迁移后运行：

```bash
scripts/worktree-audit.sh
git worktree list --porcelain
```

不要手动删除旧路径。让 Git 负责维护 linked-worktree 元数据。

## 启动模块会话

总控给模块负责人分发任务时，提示词必须包含：

- 模块名和指定 worktree 路径。
- 分支名和当前 `HEAD`。
- 默认修改路径、受控跨模块修改规则和明确禁止触碰的路径。
- 当前模块状态和已知红点。
- focused verification 命令。
- 汇报格式。
- merge / landing 约束。
- 必读的模块设计文档。

模块负责人开工后先运行：

```bash
git status --short --branch
git rev-parse --short HEAD
scripts/worktree-audit.sh
make hygiene
```

如果 `make hygiene` 在本地修改前已经失败，必须把它报告为 baseline debt，不要静默清理或提交无关文件。

任何 `core/` 模块 lane 在改源码、测试、示例或 benchmark 前，都必须先读
`core/AGENTS.md` 和 `core/docs/design-conventions.md`。其中 `design-conventions.md`
是 `nextpas.core` 模块形态、层级规则、测试布局、文档布局和命名规范的权威文件。

提示词中的路径规则建议使用这个结构：

```text
默认修改范围：
<本模块源码、测试、示例、benchmark、docs/<module> 路径>

受控跨模块修改：
如果当前模块质量必须依赖其他模块/API/底座修正，可以修改相关路径，但必须：
1. 先说明跨模块原因和设计目标；
2. 只改最小必要范围；
3. 同时跑被改模块 focused gate 和当前模块 consumer gate；
4. 在 Ready 报告中单独列出 cross-module touched files、设计理由、风险和验证证据；
5. 不触碰其他同事 active dirty worktree；
6. 影响面大时改报 Needs Review，由总控决定是否拆出独立 cross-cutting lane。

明确禁止：
<当前任务无关的 active 模块、dirty worktree、生成物、控制文件等>
```

## Landing 纪律

worktree 位置正确不代表分支可以合并。

任何分支进入主线前必须满足：

1. worktree 是干净的。
2. 改动路径属于预期模块或治理线。
3. 已在 landing candidate 上基于当前 `main` rebase、merge 或 replay。
4. 已运行改动表面的 focused verification。
5. 只用 `ff-only` 或等价的已审查 landing commit 进入主线。
6. 分支完全吸收后，清理对应临时 worktree。

成功 landing 后清理：

```bash
git worktree remove .worktrees/<短名称>
git branch -d <分支名>
git worktree prune
```

如果某个分支不应该进入主线，但仍有历史保留价值，删分支前先打 archive tag：

```bash
git tag archive/<短名称> <分支或提交>
```

不要把长期模块 lane raw merge 到 `main`。主线集成必须通过干净候选分支、已审查
cherry-pick 或 path-limited replay。除非明确授权，最终 mainline integration
由总控负责。

## 汇报纪律

模块负责人不要汇报每个小动作，只在状态变化时汇报：

- `Ready`：实现和 focused verification 已完成，等待 landing review。
- `Blocked`：继续推进需要总控或用户决策。
- `Landed`：改动已进入 `main`，验证已复跑，清理状态已知。
- `Needs Review`：继续写代码前需要设计或跨模块决策。

`Ready` 汇报必须包含分支、worktree 路径、`HEAD`、改动文件清单、不能带入主线的文件、
focused verification 证据和 merge 建议。

如果包含受控跨模块修改，`Ready` 还必须包含：

- `cross-module touched files`：跨模块文件清单。
- `design reason`：为什么不改这些路径就无法做好当前模块。
- `risk`：对 owner boundary、依赖方向、API 稳定性和其他 active lane 的影响。
- `extra verification`：被改模块 focused gate、当前模块 consumer gate、必要的 source-contract 或 compile gate。

不要把根目录 `task_plan.md`、`findings.md`、`progress.md` 当作常规模块状态带进
`main`。需要长期保存的记录，写到 `docs/plans/` 或对应模块的文档目录。

## 禁止事项

- 不要提交 `.worktrees/` 内容或 gitlink 占位。
- 不要因为 worktree 干净就 raw merge 分支。
- 不要未经负责人确认删除 dirty worktree。
- 不要用 `mv` 手动移动 worktree。
- 不要让已经完成且已吸收的 stale worktree 长期留着。
- 不要已有模块 lane 时再开新的分支或 worktree。
- 不要在模块 lane 中顺手做无关跨模块改动；必要跨模块修正必须按受控跨模块规则登记和验证。
