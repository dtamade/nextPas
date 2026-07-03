# Worktree 纪律

## 目的

确保多人协作和 AI 自主开发时，代码变更可追踪、可审查、不互相干扰。

---

## 核心规则

### 1. 一个功能/模块一个 worktree

```
.worktrees/
  mem/          ← mem 模块开发（所有 mem-* 分支）
  compiler/     ← 编译器开发（所有 feat/compiler-* 分支）
  test/         ← 测试框架开发
  bench/        ← 基准测试
  gpu-window/   ← GPU 窗口开发
```

**禁止**：在 main 仓库直接开发功能代码。main 只用于 landing。

### 2. 分支命名规范

```
<type>/<module>-<description>

类型：
  feat/       ← 新功能
  fix/        ← 修复
  refactor/   ← 重构
  docs/       ← 文档
  chore/      ← 工程治理

示例：
  feat/mem-polish-r20
  fix/mem-arena-alignment
  refactor/compiler-hir-migration
  docs/mem-contract
```

### 3. Worktree 创建

```bash
# 使用脚本创建
scripts/worktree-add.sh <branch> [base]

# 或手动创建
git worktree add .worktrees/<name> -b <branch> <base>
```

### 4. Worktree 合并前检查清单

- [ ] worktree 状态 clean（`git status` 无未提交改动）
- [ ] 四步流程完成（Plan → Implement → Review → Verify）
- [ ] 完整测试通过（不是 smoke test）
- [ ] `make hygiene` 通过（无构建产物散落）
- [ ] `git diff --check` 通过（无冲突标记）
- [ ] 契约文档已更新

### 5. 合并方式

```bash
# 在 main 仓库合并
git checkout main
git merge --no-ff <branch> -m "merge(<module>): <description>"

# 或使用 PR（如果启用了远程协作）
```

### 6. Worktree 清理

合并后，worktree 可以保留（如果还会继续开发）或清理：

```bash
# 保留（推荐，继续开发同一模块）
# 不做任何操作

# 清理
git worktree remove .worktrees/<name>
```

---

## 常见违规

| 违规 | 后果 | 处理 |
|------|------|------|
| 在 main 上直接提交代码 | 污染 main 历史 | `git reset --soft HEAD~1` 撤销，迁移到 worktree |
| worktree 合并前未走四步流程 | 未经审查的代码进入 main | 阻塞合并 |
| 分支命名不规范 | 难以追踪 | 重命名分支 |
| worktree 有未提交改动就合并 | 丢失工作或引入半成品 | 先提交或 stash |

---

## 审计

定期运行 `scripts/worktree-audit.sh` 检查：
- 所有 worktree 的状态
- 是否有孤立的 worktree
- 是否有未合并的分支

---

## 当前 Worktree 状态

| Worktree | 分支 | 状态 | 备注 |
|----------|------|------|------|
| (main) | mem-polish-r17 | stashed font WIP | 需要清理 |
| .worktrees/mem | mem-polish-r20 | clean | 32 commits 待合并 |
| .worktrees/compiler | feat/test-polish-phase10 | 有未提交改动 | 待处理 |
| .worktrees/test | main | 有未提交改动 | 待处理 |
| .worktrees/bench | bench | 有未提交产物 | 待清理 |
| .worktrees/gpu-window | codex/gpu-window | 有已删除文件 | 待处理 |
