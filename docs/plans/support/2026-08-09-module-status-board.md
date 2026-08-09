# Module Status Board — 2026-08-09

> 快照日期：2026-08-09（会话摸底）。用途：多人并行下恢复上下文。
> 纪律：本板只记录事实；**任何 dirty 均视为他人在进行中的工作，不代提交、不清理**。

## main 分支

- HEAD `c07a541bb`（领先 origin/main 3，均为他人提交）：
  - `1a73814d7` perf(tui): ansi.parse O(n²)→线性（10 万行 570ms→150ms）
  - `2b54f5830` fix(http): HTTP/1.0 隐式 close 尾随字节
  - `c07a541bb` feat(http): 响应补 Date 头
- dirty：`core/src/nextpas.core.tui.widget.input.pas`（+85/-4，**他人进行中，勿动**）
- 本会话已落 main 并推送：`962bb9dda`（tui 颜色动画基础）+ `857df2c6a`（产物清理，11 个 ELF/产物移出跟踪）

## Worktree 实况（14 个）

| Worktree | 分支 | dirty | 归属判断 |
|---|---|---|---|
| `.worktrees/atomic-lockfree` | atomic-lockfree（ahead 20） | `lockfree.workstealing.pas` + `test_lockfree.lpr` | 他人进行中 |
| `.worktrees/bench` | bench | `findings.md` + `bench.stats.pas` + Makefile | 他人进行中 |
| `.worktrees/compiler-system` | codex/compiler-system | 6 个 sema 文件 + `docs/plans/m2/ROADMAP.md`（394 行） | **B5g System.Int intrinsic 进行中**（ROADMAP 2026-07-27 记录，undefined 57→56） |
| `.worktrees/config-json-xml-toml-yaml-csv-ini` | config-json-xml-toml-yaml-csv-ini（ahead 5 / behind 35） | untracked `test_config_cross_fuzz/` | 他人进行中 |
| `.worktrees/core-net-async-io` | core-net-async-io | `io.reactor.iocp.pas` | 他人进行中 |
| `.worktrees/core-text-unicode` | core-text-unicode | **clean** | 本会话已收口 P3-5 confusables（`7f0f48b30`，未推送） |
| `.worktrees/hotfix-ci-workflows-fpc-trunk` | hotfix/ci-workflows-fpc-trunk | 5 个 CI/bench 文件 | 他人进行中 |
| `.worktrees/http` | codex/http（ahead 9） | clean | — |
| `.worktrees/math-simd` | codex/math-simd | 7 个 SIMD 文件 | 他人进行中 |
| `.worktrees/mem` | codex/mem | untracked `PAGEMAP-DESIGN-2026-07-27.md` | 他人进行中（文档） |
| `.worktrees/platform` | codex/platform | clean | — |
| `.worktrees/process-fs-path-env` | process-fs-path-env | clean | — |
| `.worktrees/test` | codex/test | `test.check.pas` + `test_assertions.lpr` | 他人进行中 |
| `.worktrees/tui` | tui（ahead 7 / behind 40） | clean | — |

## 待办 / 挂账

- `core-text-unicode` lane 的 `7f0f48b30`（P3-5 confusables）待推送/landing 决策。
- `compiler-system` B5g 是进行中工作，收口人应为原 owner；本会话不触碰。
- 其余 dirty 全部等各自 owner 收口。
