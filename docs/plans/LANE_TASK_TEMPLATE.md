# AI Lane 开工提示词模板

> 用法：每次在固定 worktree 开 AI 会话时，把 `<>` 占位填好，整段贴给 AI。
> 总控（用户）持有 main 的唯一写权限；lane AI 永远不碰 main。

---

## 任务

- 模块：`<core-http / compiler / ...>`
- 工作目录（固定 worktree，不要换地方）：`<仓库根>/.worktrees/<lane>`
- 分支：`<codex/...>`（与 worktree 同名，不要新建分支）
- 目标：`<一句话说清这次要做什么>`

## 开工先跑（只读）

```bash
git status --short --branch
git rev-parse --short HEAD
scripts/worktree-audit.sh
make hygiene
```

`make hygiene` 在你改动前就失败 → 按 baseline debt 上报，不要动。

## 铁律（违反直接停工上报）

1. **永远不碰 main**：不 `checkout main`、不 merge 进 main、不 `push main`。
   你只报 `Ready`，合由总控在 main 的 worktree 里做。
2. **只改自己的 lane 路径**：默认修改范围 `<本模块源码/测试/示例/文档路径>`。
   受控跨模块修改必须先说明原因、最小范围、额外验证，并在报告里单列。
3. **不碰别人的 worktree**：其他 `.worktrees/*` 一律只读。
4. 每个 commit 一个可回滚逻辑单元；不提交构建产物（`make hygiene` 必须过）。
5. 做 `core/` 改动前先读 `core/AGENTS.md` 和 `core/docs/design-conventions.md`。

## 验证

- 改动必须有 focused verification：`<make focused FOCUS=... 具体命令>`
- 公共 API / 内存 / 句柄生命周期变化必须覆盖边界与失败路径 + heaptrc/no-leak 证据。
- 报 `Ready` 前：worktree clean、`git diff --check` 过、对应 gate 绿。

## 汇报（只在状态变化时）

- `Ready`：分支、worktree、`HEAD`、改动文件清单、禁止带入清单、验证证据、merge 建议。
- `Blocked`：阻塞条件、已尝试动作、需谁决策。
- 不要把 `task_plan.md`、`findings.md`、`progress.md` 写进 lane 当正式产物。

---

## Main 侧提示词（在 main 的 worktree 开 AI 会话用，每次只换 lane 名）

```text
你在 main 分支的 worktree 里（项目根目录）。你是 landing 助手，不是开发。

## 本次任务（二选一，删掉不用的）
A. 预审 lane：<lane分支名>，只读审查 + 跑验证，给我 merge 建议，不合不推。
B. 执行 landing：把 <lane分支名> 报 Ready 的 commits 按下面清单合进 main。

先用 git rev-parse 取 lane 分支顶端并报出来确认，HEAD 不用我填。

## 铁律
1. main 上不写任何新功能、不改任何模块代码。允许的只有：landing 候选分支操作、
   文档归档、删已吸收的分支和 worktree。
2. 不许 --force，不许 push main，除非我明确说了"推"。
3. B 任务严格按下面"总控 Landing 清单"一步步来，
   landing-check 红了就停，把报错原样给我，不要修 lane 的代码。
4. cherry-pick 有冲突就停，把冲突摆出来等我定，不要自己选边。
5. 开始先跑：git status --short --branch、git worktree list --porcelain、
   scripts/worktree-audit.sh，确认起点干净再动手。

## 汇报
每做完一步说一声。结束给：合了哪些 commits、验证证据、是否已 push、
worktree/分支清理状态、archive 标签名。
```

最简用法（日常 90% 情况，铁律已在 AGENTS.md 顶部，AI 自动会读）：

```text
在 main 里预审 <lane分支名>，只读，不合不推，给 merge 建议。
```

---

## 总控 Landing 清单（只在 main 的 worktree 执行，一次一个）

```bash
git checkout main && git pull --ff-only
git checkout -b landing/<lane>-YYYYMMDD main
git cherry-pick <lane 待合 commits 由旧到新>
make landing-check BASE_REF=main ALLOW_PATHS="<精确路径>" FOCUS=<gate>
git checkout main && git merge --ff-only landing/<lane>-YYYYMMDD
<复跑验证> && git push origin main
git branch -d landing/<lane>-YYYYMMDD
git tag archive/<lane>-landed-YYYYMMDD <lane 原 HEAD> && git push origin --tags
```
