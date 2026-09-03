# Module Status Board — 2026-09-03（分支/worktree 整理合并专项）

> 用途：分支与 worktree 债务治理快照 + 本轮清理台账。
> 取证：`git worktree list --porcelain`、`scripts/worktree-audit.sh`、`git cherry`、
> 文件级 `git diff main...<branch>`、`make hygiene`（pass）。
> 纪律：dirty worktree 一律不动；已删分支全部打了 `archive/*` tag，可恢复；被删分支在
> origin 上均无对应远端分支，无需远端清理。

## main 分支

- HEAD `b0e8051c`（与 `origin/main` 同步，ahead 0 behind 0）
- 本轮未动 main 文件内容（只删 worktree 元数据、本地分支、加 `archive/*` tag）
- `make hygiene` = pass，`git diff --check` = 干净，`git status` = 干净

## 本轮已清理（Landed：worktree 移除 + 分支删除 + tag 归档）

| 分支 | worktree | 判定依据 | 归档 tag |
|---|---|---|---|
| `agent` | `.worktrees/agent` | 与 main 完全相同（ahead 0 behind 0，diff 空） | 无需（commit 即 main HEAD） |
| `zip` | `.worktrees/zip` | 与 main 完全相同 | 无需 |
| `fix/bytes-ops-ascii-missing` | `.worktrees/fix-bytes-ascii` | 与 main 完全相同 | 无需 |
| `fix/3c5ca-bytes` | `.worktrees/fix-3c5ca` | 过时：基于远古基线，主线 bytes.ops 已用新架构实现 `BytesGrowCapacity`（15 处引用），合入会回退 | `archive/fix-3c5ca-bytes-obsolete-20260903` |
| `fix/8b30-bytes` | `.worktrees/fix-8b30` | 同上过时 | `archive/fix-8b30-bytes-obsolete-20260903` |
| `fix/bytes-capacity-restore` | `.worktrees/fix-bytes-capacity` | 同上过时 | `archive/fix-bytes-capacity-restore-obsolete-20260903` |
| `fix/ccf-bytes-full` | `.worktrees/fix-ccf` | 同上过时 | `archive/fix-ccf-bytes-full-obsolete-20260903` |
| `fix/current-main-fix` | `.worktrees/fix-current` | 同上过时 | `archive/fix-current-main-fix-obsolete-20260903` |
| `codex/core-fix-20260902` | `.worktrees/core-fix-20260902` | bytes 部分过时；其余 3 文件差异仅为注释/方法顺序/去未用 uses，主线已超前 | `archive/codex-core-fix-20260902-obsolete-20260903` |
| `codex/zip-1.0.2` | `.worktrees/zip-1.0.2` | 功能已吸收：`DosMaxUnixSec` 转发主线已有；`FsMkdirAll` 符号链接跟随主线 mkdir_p 已有（lstat→stat 跟随）；`CreateRaw*` 改名仅为风格（主线 compress.pas 保留旧名兼容转发，zip 可编译） | `archive/codex-zip-1.0.2-absorbed-20260903` |
| `codex/rtl-20260902` | 无（orphan） | 与 main diff 为空，完全吸收 | `archive/codex-rtl-20260902-absorbed-20260903` |
| `fix/core-perfection` | 无（orphan） | 与 main diff 为空，完全吸收 | `archive/fix-core-perfection-absorbed-20260903` |

清理效果：worktree 33 → 23（含 main），本地分支 36 → 24。

## 保留：dirty active lane（11 个，一律不动，等 owner Ready）

| worktree | 分支 | 状态 |
|---|---|---|
| `.worktrees/audio` | `audio` | dirty，behind 166 |
| `.worktrees/compiler` | `codex/compiler` | dirty，behind 152 |
| `.worktrees/core` | `core` | dirty，behind 18 |
| `.worktrees/db` | `db` | dirty，behind 245 |
| `.worktrees/graphics` | `graphics` | dirty，behind 125 |
| `.worktrees/respack` | `respack` | dirty，behind 209 |
| `.worktrees/sevenz` | `sevenz` | dirty（behind 4，接近主线） |
| `.worktrees/ssh` | `ssh` | dirty，behind 244 |
| `.worktrees/vfs` | `vfs` | dirty（behind 3，接近主线） |
| `.worktrees/webview` | `webview` | dirty，behind 240 |
| `.worktrees/window` | `window` | dirty，behind 243 |

## 保留：clean 但大幅落后、需 owner 决策（逐个 replay，不要 raw merge）

| worktree | 分支 | ahead/behind | 说明 |
|---|---|---|---|
| `.worktrees/git` | `git` | 47/244 | perfection-50 连载，大跨度，需 owner 出 landing 候选 |
| `.worktrees/js` | `js` | 21/18 | 落后最少的大 lane，优先排 landing 候选 |
| `.worktrees/tar` | `tar` | 45/235 | 44 轮收口连载，需 owner 决策 |
| `.worktrees/cache-singleflight-20250902` | `codex/cache-singleflight-20250902` | 2/162 | diff 140 文件多为基线漂移，需 replay 评估 |
| `.worktrees/cache-ttl-20250902` | `codex/cache-ttl-20250902` | 10/152 | 同上 |
| `.worktrees/fs-object-store-20250902` | `codex/fs-object-store-20250902` | 2/162 | 同上 |
| `.worktrees/pascn-perfection-land` | `codex/pascn-perfection-land` | 10/152 | diff 18 文件，replay 可行性高，排第二批 |
| `.worktrees/landing-audio-1.5.1` | `landing/audio-1.5.1` | 1/162 | 临时候选分支，已 stale；等 audio lane owner 确认后归档或重做 |
| `.worktrees/landing-audio-perfection-20260902` | `landing/audio-perfection-20260902` | 4/223 | 同上 |
| `.worktrees/landing-compiler-big-refactor-20260902` | `landing/compiler-big-refactor-20260902` | 4/146 | 同上（等 compiler lane） |
| `.worktrees/landing-vfs-7b` | `landing/vfs-20260902-7b` | 1/176 | 单 commit 12 文件；vfs lane 正 dirty 推进中，由 vfs owner 决定吸收或归档 |
| 无 worktree | `codex/gateway-c91` | ahead 17/behind 9 | 19 文件差异，orphan 分支，需 owner 认领或归档 |

## 下一步建议（按优先级）

1. `js` lane（21/18）出 `landing/js-*` 候选分支 + `make landing-check`，最接近可合。
2. `sevenz` / `vfs` dirty lane 先由 owner 落盘为 clean，再评估小步 landing（behind 仅 3-4）。
3. `pascn-perfection-land`（18 文件）做 path-limited replay 评估。
4. 其余落后 100+ 的 lane 按 docs/worktrees.md sync 纪律在各自下一次 Ready 中说明同步策略。
