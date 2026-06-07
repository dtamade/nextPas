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

审计会列出每个 linked worktree、所在分支、是否 dirty、是否位于项目本地
`.worktrees/` 目录内，以及相对默认基线分支（优先 `main`，否则 `master`）的
`ahead` / `behind` 计数。任何非 `main` 的 linked worktree 如果不在 `.worktrees/`
下，都属于规范违规；任何准备进入 landing 的分支如果 `behind` 不是 `0`，必须先
基于当前主线 rebase、merge 或 replay，并重新跑 focused verification。

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

## Focused Gate Matrix

模块负责人报告 `Ready` 时，先用最窄的 focused gate 证明改动表面，再按改动性质补充
source/compile/runtime/CI evidence。不要用单个绿色命令替代所有 truth 分类。

常用 truth 分类：

- `source-contract`：读取源码、文档或配置，冻结 owner boundary、导出符号、路径规则、
  CI workflow 或文档约定；它证明文本契约，没有证明可执行 runtime 行为。
- `forced-compile`：面向 Windows、POSIX、Darwin、Android 或 no-FPC-units 的编译门。
  它证明目标表面可编译或 API/ABI 声明一致，不等于目标机器 runtime 已跑过。
- `runtime`：在当前 host 上执行测试、示例或 benchmark。涉及 public API、资源所有权、
  内存、句柄、socket、进程或线程生命周期时，报告里要列出 heaptrc / no-leak 或等价证据。
- `CI truth`：证明 CI 调的是同一套 Makefile gate 和命名，不绕过本地验证面。CI truth
  不能替代模块 focused gate；它只证明自动化入口没有漂移。

默认 focused gate matrix：

| lane | first focused evidence | extra evidence to name in `Ready` |
| --- | --- | --- |
| platform | `make focused FOCUS=core/tests/nextpas.core.platform/test_platform_simulated_host_compile_matrix` | affected host/source-contract gates, forced-compile gates, and any runtime gate that actually ran |
| compiler | not the default focused gate; use `bash build/verify_local.sh` only as a verify exception after the narrow compiler fixture or smoke command is named | targeted compiler fixture, toolchain failure truth, or smoke command that proves the changed compiler surface |
| mem | `make focused FOCUS=core/tests/nextpas.core.mem/test_memory_map_compile_gate` | allocator/runtime gate plus heaptrc/no-leak proof when ownership, allocation, or mapping behavior changes |
| system | `make focused FOCUS=core/tests/nextpas.core.system/test_system_source_contracts` | source-contract result plus any runtime or forced-compile gate for changed `system.*` units |
| config | `make focused FOCUS=core/tests/nextpas.core.config/test_config` | format-specific export/import gate when INI, TOML, YAML, examples, or mutation semantics change |
| http | `make focused FOCUS=core/tests/nextpas.core.http/test_http_client` | parser/writer/router/server/runtime gate matching the touched HTTP surface |

也可以用 `make lane-focused LANE=<platform|mem|system|config|http>` 读取当前默认矩阵并执行
对应的根目录 `make focused FOCUS=...`。这个入口会打印 `lane`、`truth`、`focus` 和
`command` 字段，适合模块负责人放进 `Ready` evidence。它是 local/reporting helper；
CI 目前仍跑 `make test-tooling` 和 `make verify`，不要把 `lane-focused` 当成 CI matrix。
需要审计矩阵漂移时，用 `scripts/lane-focused.sh --list` 打印 tab-separated
`lane` / `truth` / `focus` 清单，再和本节矩阵比对。

如果某个模块的最佳 gate 不是根目录 `make focused FOCUS=...`，例如 compiler 目前没有
默认 focused gate、或模块 Makefile 暴露专用目标，报告里必须把例外写清楚，并列出实际命令。
缺少可用 focused gate 时，不要把 slice 说成可落地；先补 gate，或用 `Needs Review`
让总控决定是否拆出 tooling slice。

当前有少数 `core/tests` Makefile 的 `test` 目标只打印 `SKIP`，这些不能作为 runtime evidence：

- `core/tests/nextpas.core.hash/test_hash`：`SKIP`，等待迁移到 `nextpas.core.crypto.hash` API。
- `core/tests/nextpas.core.hash/test_hash_audit`：`SKIP`，等待迁移到 `nextpas.core.crypto.hash` API。
- `core/tests/nextpas.core.tls/unit`：`SKIP`，复杂多文件套件仍需手工拆 gate。
- `core/tests/nextpas.core.simd.cpuinfo`：`SKIP`，真实 focused gate 是
  `make -C core/tests/nextpas.core.simd cpuinfo-focused`。

如果 `Ready` 报告触及这些路径，必须把它们列为占位例外，并补充真实可执行 gate、
source-contract、forced-compile 或 `Needs Review` 说明。

任何分支进入主线前必须满足：

1. worktree 是干净的。
2. 改动路径属于预期模块或治理线。
3. `scripts/worktree-audit.sh` 显示 landing candidate 相对当前 `main` 的 `behind` 为 `0`。
4. 已在 landing candidate 上基于当前 `main` rebase、merge 或 replay。
5. 已运行改动表面的 focused verification。
6. 只用 `ff-only` 或等价的已审查 landing commit 进入主线。
7. 分支完全吸收后，清理对应临时 worktree。

推荐先用只读 landing evidence gate 固化这些事实：

```bash
make landing-check \
  BASE_REF=main \
  ALLOW_PATHS="scripts tests/tooling docs/worktrees.md" \
  FOCUS=core/tests/<module>/<gate>
```

也可以用 `LANE` 从 focused gate matrix 推导 `FOCUS`：

```bash
make landing-check \
  BASE_REF=main \
  ALLOW_PATHS="docs/worktrees.md tests/tooling" \
  LANE=system
```

如果同时设置 `FOCUS` 和 `LANE`，`FOCUS` 优先。`LANE` 只是 local/reporting helper，
用于减少常见模块 lane 的 evidence 命令分叉；它不改变 `ALLOW_PATHS`、不批准 landing、
不替代 diff review，也不会变成 CI matrix。

`ALLOW_PATHS` 是允许带入候选分支的路径前缀清单；多个前缀用空格分隔。
如果当前 slice 没有对应的 core focused gate，可以省略 `FOCUS`，但 `Ready` 或
landing 报告必须说明用了哪些替代 verification。
对于 `.github/` CI slice，省略 `FOCUS` 时必须跑 `make test-tooling`。
对于 `scripts/`、`tests/tooling/` 或 `docs/worktrees.md` 这类 tooling / landing 文档 slice，省略 `FOCUS` 时也必须跑 `make test-tooling`，并在 `Ready` 报告中列出该证据。

`make landing-check` 会运行：

1. `make hygiene`。
2. `scripts/landing-candidate-check.sh --base <BASE_REF> --allow-path <prefix>...`。
3. `git diff --check <BASE_REF>...HEAD`。
4. 如果设置了 `FOCUS`，再运行根目录 `make focused FOCUS=<gate>`；如果没有 `FOCUS`
   但设置了 `LANE`，先解析 lane matrix，再运行解析出的 focused gate。
5. 最后再运行一次 `make hygiene`。

`scripts/landing-candidate-check.sh` 只读取当前 worktree 状态并打印证据：branch、
worktree、HEAD、base、ahead、behind、allowed paths 和 changed files。它会在 dirty、
detached、`behind != 0`、worktree 不在仓库根或 `.worktrees/`、或改动路径超出
`ALLOW_PATHS` 时失败。该 helper 不会 rebase、merge、cherry-pick、replay 或修改分支。

这个 gate 只是 landing evidence，不是合并批准。它不能替代 diff review、模块 focused
verification、heaptrc/no-leak 证据、source/compile/runtime truth 分类，也不能授权 raw merge
长期 lane 到 `main`。

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
