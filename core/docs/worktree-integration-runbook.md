# nextPas worktree 命名与集成 runbook

这份 runbook 是 `docs/ai-collaboration-discipline.md` 的操作 companion。

纪律文档回答“什么不能做、什么必须做”；这份 runbook 回答“实际怎么做才安全”。

适用范围：

- 任何会修改 `nextPas` 仓库内容的开发批次
- 人类开发者和 AI 代理
- 尤其适用于多个 writer 并行推进时

---

## 1. 默认先开独立 worktree

只要任务会写代码、写测试、写控制文件，默认就开独立 worktree。

只有这几类窄动作可以不新开：

- 只读检查
- 主 checkout 上的最终集成
- 已明确无人并行使用主 checkout 的极小文档修正

如果你已经在一个 dirty shared checkout 里，默认不要继续在这里实现。

---

## 2. 先定名字，再建目录

推荐命名规则：

- branch：`codex/<module>-<topic>-YYYYMMDD`
- worktree：`.worktrees/<module>-<topic>-YYYYMMDD`

例子：

- `codex/http-trailer-20260603`
- `.worktrees/http-trailer-20260603`
- `codex/platform-pty-20260603`
- `.worktrees/platform-pty-20260603`

命名要表达三件事：

- 主要模块
- 当前窄目标
- 开始日期

不要用这些名字：

- `test`
- `fix`
- `tmp`
- `main-copy`
- `new-branch`

这种名字后面很难审计和清理。

---

## 3. 从 repo root 创建 worktree

在 repo root 执行：

```bash
cd /path/to/nextPas
git worktree add .worktrees/http-trailer-20260603 main
cd .worktrees/http-trailer-20260603
git switch -c codex/http-trailer-20260603
git status --short --branch
git rev-parse HEAD
```

如果任务目标是 `core`，就在这个 worktree 里的 `core/` 子目录工作，而不是给 `core/` 单独伪造一个 Git 根。

创建后至少记录：

- worktree 路径
- branch 名称
- 起始 `main` commit
- 当前 owner
- 当前模块范围

这些信息应该进入 `task_plan.md` / `progress.md` / `findings.md`。

---

## 4. 开工前做四步安全检查

在可写 worktree 里，正式编辑前先跑：

```bash
git status --short --branch
git diff --cached --name-only
git worktree list
git rev-parse HEAD
```

只有这四项都清楚，才开始编辑。

发现下面任一情况就先停：

- index 里有无关 staged 文件
- 当前 branch 名称和任务不匹配
- 已有另一个 worktree 正在推进同一路文件
- 当前 worktree 已混入其他批次的未提交改动

---

## 5. 日常开发只走 path-limited 流程

推荐循环：

1. 写窄批次改动
2. 跑 focused verification
3. 更新控制文件
4. 看 `git diff --stat`
5. 只按路径 stage
6. 看 `git diff --cached --name-only`
7. 提交一个逻辑单元

提交前最少检查：

```bash
git diff --stat
git diff --cached --name-only
git diff --check
```

只允许：

```bash
git add -- path/to/file1 path/to/file2
git commit -m "type(scope): message"
```

不要用：

- `git add .`
- `git add -A`
- `git commit -a`

---

## 6. 集成回 main 的安全路径

先在 feature worktree 内完成：

- focused tests / verify
- 文档与控制文件同步
- 最终 commit

然后回 repo root 的主 checkout，只做集成动作：

```bash
cd /path/to/nextPas
git status --short --branch
git diff --cached --name-only
git merge --ff-only codex/http-trailer-20260603
```

这里的安全关键点有两个：

- 主 checkout 只做集成，不顺手继续开发
- 集成前先确认 index 没有无关 staged 文件

如果 `git merge --ff-only` 失败：

- 先停
- 不要在 dirty 主 checkout 里硬解
- 改为单独做一次受控集成批次，或者回 feature worktree 先把边界整理干净

默认不要把“复杂冲突解决”夹在别的开发批次中间完成。

---

## 7. 集成后立刻清理

集成完成后，确认主 checkout 验证通过，再清理：

```bash
cd /path/to/nextPas
git worktree remove .worktrees/http-trailer-20260603
git branch -d codex/http-trailer-20260603
```

如果该 branch 还没合入，或者还要保留继续开发，不要删。

但已经完成的批次也不要长期保留僵尸 worktree，不然很快又会回到“工作区到处是旧分支副本”的状态。

---

## 8. 遇到这些情况直接停机复核

- 无关 staged 文件出现在 index
- 主 checkout 在你工作中途被别人推进
- 同一文件在多个 worktree 同时改
- 需要 `reset --hard`、`rebase`、`checkout --` 才能“方便处理”
- 你已经说不清某个改动是不是自己写的

停机复核时先记录：

```bash
git status --short --branch
git diff --cached --name-only
git rev-parse HEAD
git worktree list
```

然后再决定拆边界、串行化，还是单独开新的集成批次。

---

## 9. 最短安全模板

新开批次：

```bash
cd /path/to/nextPas
git worktree add .worktrees/http-trailer-20260603 main
cd .worktrees/http-trailer-20260603
git switch -c codex/http-trailer-20260603
git status --short --branch
git diff --cached --name-only
```

提交批次：

```bash
git diff --stat
git add -- path/to/file1 path/to/file2
git diff --cached --name-only
git diff --check
git commit -m "type(scope): message"
```

集成批次：

```bash
cd /path/to/nextPas
git status --short --branch
git diff --cached --name-only
git merge --ff-only codex/http-trailer-20260603
```

清理批次：

```bash
git worktree remove .worktrees/http-trailer-20260603
git branch -d codex/http-trailer-20260603
```

---

## 10. 一句话 runbook

**能独立 worktree 就不要挤 shared checkout；能 fast-forward 集成就不要在脏主 checkout 里硬解冲突。**
