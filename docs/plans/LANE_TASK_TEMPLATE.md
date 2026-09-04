# AI Lane 开工与 Landing 模板

> Lane 自主 landing：lane AI 按本文第 2 节自行合入 main，不再等总控动手。
> 日常用法：给 AI 发一句话
> `读 docs/plans/LANE_TASK_TEMPLATE.md，按第 2 节自主 landing 流程把 <lane分支名> 合进 main`
> AI 按本文第 2 节的详细流程执行。lane 名是每次唯一要换的东西。

---

## 1. Lane 开工提示词（在固定 worktree 开 AI 会话用）

把 `<>` 占位填好，整段贴给 AI：

```text
- 模块：<core-http / compiler / ...>
- 工作目录（固定 worktree，不要换地方）：<仓库根>/.worktrees/<lane>
- 分支：<codex/...>（与 worktree 同名，不要新建分支）
- 目标：<一句话说清这次要做什么>

开工先跑（只读）：git status --short --branch、git rev-parse --short HEAD、
scripts/worktree-audit.sh、make hygiene。
make hygiene 在你改动前就失败 → 按 baseline debt 上报，不要动。

铁律（违反直接停工上报）：
1. 不在 main 上写代码：日常开发只在自己的 worktree；合入 main 只走第 2 节的
   landing 机械步骤（建候选分支/cherry-pick/landing-check/ff 合并/push），不 raw merge。
2. 只改自己的 lane 路径：默认修改范围 <本模块源码/测试/示例/文档路径>。
   受控跨模块修改必须先说明原因、最小范围、额外验证，并在报告里单列。
3. 不碰别人的 worktree：其他 .worktrees/* 一律只读。
4. 每个 commit 一个可回滚逻辑单元；不提交构建产物（make hygiene 必须过）。
5. 做 core/ 改动前先读 core/AGENTS.md 和 core/docs/design-conventions.md。

验证：改动必须有 focused verification（<make focused FOCUS=... 具体命令>）；
公共 API / 内存 / 句柄生命周期变化必须覆盖边界与失败路径 + heaptrc/no-leak 证据；
报 Ready 前 worktree clean、git diff --check 过、对应 gate 绿。

汇报（只在状态变化时）：Ready 含分支、worktree、HEAD、改动文件清单、
禁止带入清单、验证证据、merge 建议；Blocked 含阻塞条件、已尝试动作、需谁决策。
```

---

## 2. 自主 Landing 详细流程与安全规范（lane owner 自己执行，一次只合一个 lane）

### 2.1 起点检查（不干净就停）

```bash
git status --short --branch     # main worktree 必须是 ## main...origin/main，且无改动
git pull --ff-only               # 拉到远端最新；失败说明有人动过 main，先查清再继续
scripts/worktree-audit.sh        # 确认自己 lane 存在、无违规 worktree
```

### 2.2 确认要合的内容

```bash
git log --oneline main..<lane分支名>  # 列出待合 commits，与自己的 Ready 报告对一遍
```

对不上的（多了/少了 commit）就停：回到自己 lane 把 commit 理齐再重来。

### 2.3 建一次性候选分支并 cherry-pick

```bash
git checkout -b landing/<lane>-YYYYMMDD main
git cherry-pick <最旧> <...> <最新>   # 按时间从旧到新
```

- 有冲突：解完 `git add` + `git cherry-pick --continue`；解不了就
  `git cherry-pick --abort`，回到自己 lane 把分歧修好重来。涉及他人模块语义拿不准的，
  按受控跨模块规则上报后再动手，**不要自己选边**。
- 绝不 merge lane 分支进来（不带入 lane 的实验 commit 和跨 lane merge 历史）。

### 2.4 门禁（红了就停）

```bash
make landing-check \
  BASE_REF=main \
  ALLOW_PATHS="<lane 改动路径，空格分隔，精确到文件>" \
  FOCUS=core/tests/<module>/<gate>
```

`ALLOW_PATHS` 用 `git diff --name-only main..HEAD | tr '\n' ' '` 拼。
红了就停：回到自己 lane 修好重跑，再重走本节。涉及他人模块才上报。

### 2.5 合进 main 并推送

```bash
git checkout main
git merge --ff-only landing/<lane>-YYYYMMDD   # 非 ff 就停，说明基线变了，重走 2.1
<复跑一遍关键 gate>                             # 验证合完的 main，不是验证候选分支
git push origin main
```

### 2.6 收尾

```bash
git branch -d landing/<lane>-YYYYMMDD
git tag archive/<lane>-landed-YYYYMMDD <lane 原 HEAD> && git push origin --tags
```

长期 lane（`codex/<module>` 这类）跳过下面两行，worktree 和分支留着继续推进；
一次性任务 lane 才清理：

```bash
git worktree remove .worktrees/<lane>   # 确认 owner 已收工
git branch -d <lane分支名>
```

### 2.7 安全红线（任何一条触发就停，修好重走；涉及他人时上报）

1. 起点不干净（main 有改动 / pull 非 ff / 审计有违规）。
2. 待合 commits 与 Ready 报告对不上。
3. landing-check 红灯（路径越界、behind 非 0、hygiene、diff-check 任一失败）。
4. cherry-pick 冲突拿不准，或 merge 非 ff。
5. 全程不用 `--force`（main 服务器端已禁 force，push 被拒就重走流程，不要绕）。

### 2.8 汇报格式

合了哪些 commits、验证证据、是否已 push、worktree/分支清理状态、archive 标签名。
