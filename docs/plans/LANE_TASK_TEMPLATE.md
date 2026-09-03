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
