# 2026-06-04 Config Branch Triage

## Goal

在 `config` 写入/导出主线已经并入共享 `main` 之后，
把遗留的 `codex/config-*` 分支做一次可追溯分流：

- 明确哪些分支已经被主线吸收，可以安全删除
- 明确哪些分支仍带独立 perf / bench / 设计历史，只能归档保留
- 记录仍挂在 `stash` 上的 config 草稿，防止误删

本轮只做分流与清理，不推进 benchmark，不重开 config API 设计。

## Current truth

- 共享 `main` 已包含 config write/export/yaml landing。
- 合并候选分支 `codex/config-main-merge-20260604` 已经完成使命并可删除。
- config 旧 worktree 已全部移除；当前只剩 git branches 与两个 config 相关 stash。

## Branch inventory

### `codex/config-main-merge-20260604`

- 状态：临时合并候选分支
- 事实：
  - 已并入共享 `main`
  - 对应 worktree 已删除
- 结论：可删除

### `codex/config-write-safe-main-20260603`

- 状态：早期安全落地主线
- 事实：
  - `git rev-list --left-right --count main...branch` 显示 `30 0`
  - 分支没有独立提交；`main` 已完整吸收其历史
  - 曾经挂过未提交草稿，但已先转为 named stash
- 相关 stash：
  - `cleanup/config-write-safe-main-20260603 preserve partial export docs/example drift`
- 结论：branch 可删除；stash 保留

### `codex/config-write-merge-review-20260603`

- 状态：最终 config landing 的 merge-review 分支
- 事实：
  - `b39b61ae` 的真实代码面已被 `main` 吸收
  - 相对 `main` 的 config 目标文件差异只剩控制面文件：
    - `core/task_plan.md`
    - `core/findings.md`
    - `core/progress.md`
  - 没有关联 stash
- 结论：分支已失去独立代码价值，可删除

### `codex/config-write-main-land-20260603`

- 状态：旧的“主线落地”工作分支
- 事实：
  - 仍有独立提交
  - 内容混合：
    - write/export landing
    - perf(config) read-path 试验
    - bench(config) 基线与 Go/Rust 对照
    - 与 config 无关的后续主线 refresh / merge 历史
  - 不是 `codex/config-write-main-20260603` 的纯祖先快照
- 结论：不能删；仅归档保留，不再作为直接 merge 候选

### `codex/config-write-main-20260603`

- 状态：config perf / bench 主工作线
- 事实：
  - 仍有大量独立提交
  - 包含尚未审计完的方向：
    - typed lookup slot arrays
    - exact-key lookup index
    - literal read fast-path
    - interpolation cache fast-path
    - benchmark baseline / compare harness
  - 仍挂有 named stash：
    - `cleanup/config-write-main-20260603 preserve typed lookup slot arrays`
- 结论：不能删；保留为后续 perf 设计输入线

### `codex/config-phase2-20260601`

- 状态：更早的 phase2 / phase3 设计与 API 加固分支
- 事实：
  - 仍有 3 个 config 专属提交：
    - `6288bcf6` `feat(config): harden phase2 public API`
    - `32cf527b` `docs(config): document phase2 public API`
    - `512fba65` `docs(config): plan phase3 interface builder`
  - 由于分支基线较旧，相对 `main` 还混入大量后来主线文件，尚未做 patch-equivalence 审核
- 结论：暂不删除；保留为历史设计参考线

## Cleanup decisions

### Delete now

- `codex/config-main-merge-20260604`
- `codex/config-write-safe-main-20260603`
- `codex/config-write-merge-review-20260603`

### Keep as archive

- `codex/config-write-main-land-20260603`
- `codex/config-write-main-20260603`
- `codex/config-phase2-20260601`

## Stash inventory

- `stash@{0}`:
  `cleanup/config-write-safe-main-20260603 preserve partial export docs/example drift`
- `stash@{1}`:
  `cleanup/config-write-main-20260603 preserve typed lookup slot arrays`

这两个 stash 目前都是 config 审计输入，不应随分支清理一起丢弃。

## Recommended next slice

下一轮 config 主线不要重开 benchmark，先做“设计收敛 + 独立 perf 候选分流”：

1. 从 `codex/config-write-main-20260603` 提炼纯 perf 候选清单
2. 把 benchmark / compare harness 完全排除在当轮实现之外
3. 先判断哪些 perf 想法满足：
   - 不改变 public contract
   - 能用 focused tests 证明不回归
   - 值得单独 path-limited replay
4. `typed lookup slot arrays` / `exact-key lookup` 是最像下一批可讨论对象的两条线，
   但必须先补设计边界和验证策略，再决定是否落地主线

## Non-goals

- 本轮不做 benchmark
- 本轮不恢复旧 stash
- 本轮不从 archive branches 继续摘取代码
- 本轮不更新共享 checkout 上的 net/http 控制文件
