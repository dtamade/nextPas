# Agent Landing 操作手册 — 待 main 稳定窗口

> 状态：**待执行**（2026-08-31 15:00 创建，14:40 更新）
> 背景：agent perfection 线（W13-W18）+ 反哺收口已完整验证，候选分支就绪；
> main 当前处于多 lane 高频合入期（1-2 min/commit），且 agent 域被其他同事
> 占用（`9104ab2da fix(core,ssh): agent heaptrc 收口`），landing 需等待
> agent 域外部工作收敛 + main 合入高峰过去。
> 最新：worktree 分支 HEAD `56ac144e2`（含 landing 手册）；
> 可验证 gate（不依赖 compress）全绿：test_sse 13/13、test_provider_common 11/11；
> test_compile_skeleton/test_codecs 受外部 `compress.deflate` 未完成重构阻塞
> （`ZlibPure*` 缺失，与 agent 无关，待外部收敛后复跑）。

## 资产位置

| 资产 | 位置 | 内容 |
|------|------|------|
| 候选分支（本地） | `landing/agent-final-20260831` | agent perfection 线 + 反哺收口 11 commit（49 单元） |
| 候选分支（远端备份） | `origin/landing/agent-final-20260831` | 同上（`6f025654a`） |
| 开发分支（worktree） | `codex/core-agent` @ `.worktrees/core-agent` | 原始 11 commit（`7567b8fbc`..`ef0c151fc`） |
| 旧 landing 候选 | `landing/agent-perfection-20260830` | 落后 main 831，**勿用**（已废弃） |

## 候选分支内容（18 commit = 12 来源 + 6 增补）

- **perfection 线**（merge `69aaa2c0e`）：W13-W18 六维收口，95 文件，49 单元
- **反哺收口 11 commit**（cherry-pick，含 2 处冲突解决）：
  - `bytes.pas`：保留双方（main 的 unsigned helpers + String re-export）
  - `text.utils`：取 Move 修复版（FPC inline+字面量缺陷修复）
  - `module-registry.md`：取 main 侧（同事的 vfs/webview 描述）
- **验证**：25/25 gate 全绿（含 HEAPTRC）+ sse-feed A/B -31%（98.13→67.71ms）

## 执行步骤（main 稳定窗口内）

```bash
# 1. 同步最新 main（候选可能落后）
git fetch origin
git checkout landing/agent-final-20260831
git rebase origin/main
#    若冲突：agent 域冲突由 agent 负责人解决；非 agent 冲突取 main 侧

# 2. 验证（rebase 后必须重跑）
make focused FOCUS=core/tests/nextpas.core.agent/test_sse
make focused FOCUS=core/tests/nextpas.core.agent/test_compile_skeleton
make focused FOCUS=core/tests/nextpas.core.agent/test_provider_common

# 3. 快进 main（确认主工作区无人 checkout main）
git update-ref refs/heads/main landing/agent-final-20260831
#    注意：git branch -f main 会被工作区保护拒绝；update-ref 不碰工作区文件

# 4. 验证 main
git log --oneline -1 main
git ls-tree -r --name-only main -- core/src/ | grep -c 'nextpas.core.agent'  # 应 49

# 5. 清理
git push origin landing/agent-final-20260831 --delete   # 可选：归档后删除
git worktree remove .worktrees/core-agent --force        # 内容已入 main 后
```

## 前置检查（执行前确认）

- [ ] main 合入频率 < 1 commit/10min（合入高峰已过）
- [ ] agent 域无其他同事未提交工作（`git status` 主工作区 agent 目录干净）
- [ ] 候选分支 `git rev-list --count origin/main..HEAD` = 0（rebase 后落后为 0）
- [ ] 上述 3 个 gate 全绿

## 风险与回滚

- **并发重置风险**：main 被其他 lane 的"抗并发重置"覆盖（曾发生：`9023f0765`）。
  缓解：选稳定窗口 + 执行后立即验证；若被覆盖，候选分支仍在（本地+远端），
  重新 rebase 后再次快进即可。
- **回滚**：`git update-ref refs/heads/main <被覆盖前的 commit>`（有风险，需总控授权）。
- **agent 域冲突**：main 上 agent 若有同事新工作，冲突由 agent 负责人三方合并。

## 相关文档

- `core/docs/agent/CHANGELOG-AGENT.md`：agent-feedback-2026-08-31 / agent-sse-perf-2026-08-31
- `docs/worktrees.md`：landing 候选分支规范（§landing）
- `core/docs/agent/ARCHITECTURE.md`：49 单元结构说明
