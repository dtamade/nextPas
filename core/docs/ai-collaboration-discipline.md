# nextPas 多人 / 多 AI 协作纪律

这份文档定义 `nextPas` 仓库的多人、多 AI 并行开发纪律。目标不是“减少麻烦”，而是避免共享
checkout、脏 index、误提交、误覆盖和错误合并把仓库带进不可追溯状态。

这是一份 repo 级长期规则，适用于人类开发者、Codex、Claude Code，以及任何会直接修改工作区的自动化代理。

---

## 1. 用一个可写 worktree 对应一个写作者

默认规则：

- 一个写作者只能在一个自己明确持有的可写 worktree 里落代码。
- 一个 worktree 只服务一个当前批次，不混多个无关目标。
- 一个批次只允许一个明确 owner；同一模块、同一文件族、同一路控制文件不要并行双写。

对于 `nextPas` 这种 monorepo：

- worktree 应创建在仓库根目录级别，而不是只为 `core/` 子目录单独伪造 git 环境。
- 如果任务目标是 `core`，就在 repo root 建 worktree，然后在该 worktree 里的 `core/` 子目录工作。

推荐命名：

- branch：`codex/<module>-<topic>-YYYYMMDD`
- worktree 目录：`.worktrees/<branch-short-name>` 或统一的 agent worktree 根目录

开始前至少记录：

- worktree 路径
- branch 名称
- 起始 `main` commit
- 当前 owner
- 当前模块范围

这些信息应写进 `task_plan.md` / `progress.md` / `findings.md` 的当前批次记录。

---

## 2. 把主 checkout 当成集成面，不当成并行实现面

默认情况下，主 checkout 只做这些事：

- `git status`、`git log`、`git diff`、`rg`、文档阅读等只读动作
- repo 级验证、汇总报告、最终集成检查
- 已验证分支的最终集成

默认不在主 checkout 做这些事：

- 功能实现
- 大范围重构
- 批量格式化
- 多文件生产代码编辑
- 不可逆 Git 操作

如果因为现实原因必须在主 checkout 落改动，必须同时满足：

- 当前只有一个写作者在使用主 checkout
- 已先确认 `git diff --cached --name-only` 没有无关 staged 文件
- 本轮改动是窄范围、可 review、可 path-limited 提交的单一逻辑批次

只要主 checkout 已经是 dirty shared checkout，就不再把它当成常规开发场所。

---

## 3. 动手前先做仓库安全检查

开始任何写操作前，先跑：

```bash
git status --short --branch
git diff --cached --name-only
git worktree list
git rev-parse HEAD
```

重点看四件事：

1. 当前 branch / HEAD 是什么。
2. working tree 里有没有无关 dirty 文件。
3. index 里有没有别人的 staged 文件。
4. 当前仓库是否已经存在多个并行 worktree，是否有人正在做同一块。

如果发现无关 staged 文件：

- 先停止提交动作。
- 只对明确无关路径执行 `git restore --staged -- <paths>`。
- 不要顺手清理别人的 working tree 修改。

如果发现同一路文件已经被另一条 branch / worktree 接管：

- 先停下来。
- 决定串行化、拆边界，或改到新的窄切口。
- 不要假设“改一点应该没事”。

---

## 4. staging 和 commit 必须按路径收口

允许：

```bash
git add -- path/to/file1 path/to/file2
git diff --cached --name-only
git diff --check
git commit -m "type(scope): message"
```

禁止：

- `git add .`
- `git add -A`
- `git commit -a`
- 在 dirty shared checkout 里 `git stash` / `git stash -u`
- 未经确认就提交当前 index 全部 staged 内容

提交前至少检查：

- `git diff --stat`
- `git diff --cached --name-only`
- `git diff --check`

每个 commit 必须是一个逻辑单元，不混入无关模块或别人的 staged 内容。

---

## 5. 合并优先走可验证、可追溯的集成路径

推荐集成顺序：

1. 在 feature worktree 内完成实现与 focused verification。
2. 把该分支推进到与最新 `main` 可安全集成的状态。
3. 在主 checkout 只做最终集成和集成后验证。

优先策略：

- 优先可快进集成的线性路径。
- 非必要不在 shared checkout 做复杂冲突处理。
- 非必要不在多人共享仓库里做历史改写。

默认禁止：

- `git reset --hard`
- `git rebase`
- `git checkout -- <path>`
- `git clean -fd`
- `git commit --amend`
- `git push --force`

例外只能在仓库 owner 明确批准后执行，而且要先说明影响范围。

---

## 6. 冲突不要在脏主 checkout 里硬解

出现下面任一情况，先停：

- `git diff --cached --name-only` 出现无关 staged 文件
- 同一文件在多个 worktree 同时推进
- `main` 在你工作过程中被其他分支推进
- 出现真实 merge conflict
- 测试失败但 diff 里混着无关改动
- 不确定某些改动是不是别人的未提交成果

停下后的处理顺序：

1. 记录 `git status --short --branch`
2. 记录 `git diff --cached --name-only`
3. 记录当前 HEAD 和目标分支
4. 明确哪些文件是自己 owner，哪些不是
5. 再决定是拆边界、换 worktree，还是串行化处理

默认禁止用 `ours` / `theirs` 粗暴吞掉未知变更。

---

## 7. 并行开发先分模块和边界，不先拼运气

多个 AI 可以并行，但前提是边界先分清：

- 一个 AI 一次只接一个主模块或一个窄切口
- 控制文件、测试、生产代码的 owner 要一起考虑
- 如果两个任务都会碰同一组控制文件，必须先约定谁落最终事实

推荐分工方式：

- 按模块分：`http`、`tls`、`platform`、`compiler`
- 按波次分：同模块下不同 phase，但不能同时改同一条契约
- 按角色分：一个写实现，一个只读审查，一个做集成验证

不推荐的方式：

- 多个 AI 同时在主 checkout 改不同文件，然后都直接提交到 `main`
- 多个 AI 同时修改同一个模块的控制文件和测试基线
- 先开发，最后再想“怎么合一起”

---

## 8. 每轮收尾必须留恢复入口

每个批次结束时至少要留下：

- 改了什么
- 为什么这么改
- 跑了哪些 focused tests
- 是否有 leak / heaptrc 证据
- 当前 commit id
- 下一步应该做什么
- 当前 branch / worktree 状态

如果该批次使用了 `task_plan.md` / `findings.md` / `progress.md`，必须把它们更新到可恢复状态。

推荐收尾命令：

```bash
git status --short --branch
git show --stat --format=short HEAD --
```

如果一个 worktree 已完成并完成集成：

- 删除该 worktree
- 删除已完成 branch
- 不保留“以后可能还要继续”的僵尸 worktree

---

## 9. 主 checkout 脏了时的最低安全线

如果现实里暂时还做不到“每个写作者一个独立 worktree”，最低也要守住这些底线：

- 一次只允许一个写作者在主 checkout 落代码
- 所有提交必须 path-limited staging
- 提交前必须看 `git diff --cached --name-only`
- 不做历史改写
- 不清理、不回滚、不覆盖无关改动
- 每轮结束必须提交，不能把大批未提交改动长期挂在主 checkout

这只是止损线，不是理想工作方式。

---

## 10. 推荐最小流程

新开一批任务时：

```bash
git worktree list
git status --short --branch
git diff --cached --name-only
```

创建独立 worktree 时：

```bash
cd /path/to/nextPas
git worktree add .worktrees/http-trailer main
cd .worktrees/http-trailer
git switch -c codex/http-trailer-20260603
```

提交前：

```bash
git diff --stat
git diff --cached --name-only
git diff --check
```

收尾时：

```bash
git status --short --branch
git show --stat --format=short HEAD --
```

---

## 11. 一句话纪律

**一个写作者，一个可写 worktree；主 checkout 只做集成；所有提交都必须按路径收口。**
