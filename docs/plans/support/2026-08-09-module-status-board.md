# Module Status Board — 2026-08-09（v2，worktree 整理后）

> 更新：2026-08-09（会话内第二次快照，worktree 全面整理后）。
> 用途：多人并行下恢复上下文 + 未提交工作恢复台账。
> 纪律：他人 dirty 一律不动原文件；用命名 stash 固化（零丢失、可恢复）；不代他人 sync/landing。

## main 分支（当前）

- HEAD `8de6f9ea1`，**与 origin/main 零偏差**（已推送）
- 本会话落地并推送的提交：
  - `962bb9dda` feat(tui): 颜色动画基础（ColorInterp/CopyStrToBuf/BeginTableRaw）
  - `857df2c6a` chore(hygiene): 移除误入库的 11 个构建产物
  - `1716ec8d9` docs(governance): v1 状态板
  - `7974a124d` feat(text.unicode): P3-5 UTS#39 confusables 收口
  - `3e8b81dd4` fix(text.unicode): internalSkeleton 补 Default_Ignorable 移除
  - `8de6f9ea1` chore(text.unicode): confusables.txt 规范化行尾空白
- 他人提交（保留未动）：`1a73814d7` ansi.parse 线性化、`2b54f5830` HTTP/1.0 close、`c07a541bb` Date 头、`d0d2c7b9b` sqlite FFI
- **他人 dirty（未提交，勿动）**：`core/src/nextpas.core.http.impl.h1.conn.pas`、`core/src/nextpas.core.http.impl.h1.writer.pas`、`core/src/nextpas.core.tui.terminal.pas`、`core/src/nextpas.core.tui.widget.input.pas`、`core/tests/nextpas.core.http/test_http_h1writer/test_http_h1writer.lpr`、`core/tests/nextpas.core.tui/test_tui_terminal/test_tui_terminal.lpr`

## Worktree 实况（15 个，整理后）

| Worktree | 分支 | HEAD | 状态 | 动作 |
|---|---|---|---|---|
| main 根 | main | 8de6f9ea | dirty（他人 6 文件） | 未动 |
| `.worktrees/atomic-lockfree` | atomic-lockfree | 6533d1d7 | clean（已 stash） | stash@{8} |
| `.worktrees/bench` | bench | 9c84c277 | clean（已 stash） | stash@{7} |
| `.worktrees/compiler-system` | codex/compiler-system | 9245e720 | clean（已 stash） | stash@{6}（B5g sema 394 行） |
| `.worktrees/config-json-xml-toml-yaml-csv-ini` | config-json-xml-toml-yaml-csv-ini | 009a2939 | clean（已 stash） | stash@{5} |
| `.worktrees/core-net-async-io` | core-net-async-io | 339935d9 | clean（已 stash） | stash@{4} |
| `.worktrees/core-text-unicode` | core-text-unicode | 8de6f9ea | clean，已收敛 main | ✅ 本会话收口 |
| `.worktrees/hotfix-ci-workflows-fpc-trunk` | hotfix/ci-workflows-fpc-trunk | 098c65d5 | clean（已 stash） | stash@{3} |
| `.worktrees/http` | codex/http | dcc29cd3 | clean，stale（ahead 112/behind 59） | 未动（他人 lane） |
| `.worktrees/math-simd` | codex/math-simd | 8ee7fab0 | clean（已 stash） | stash@{2} |
| `.worktrees/mem` | codex/mem | decaa9f0 | clean（已 stash） | stash@{1} |
| `.worktrees/platform` | codex/platform | f304bacf | clean，stale（ahead 33） | 未动（他人 lane） |
| `.worktrees/process-fs-path-env` | process-fs-path-env | 96a630e2 | clean，stale（ahead 6） | 未动（他人 lane） |
| `.worktrees/test` | codex/test | e6b2889b | clean（已 stash） | stash@{0} |
| `.worktrees/tui` | tui | 92cbc09b | clean，stale（ahead 7/behind 48） | 未动（他人 lane） |

## 🔒 Stash 台账（2026-08-09 固化，恢复方法：进入对应 worktree → `git stash pop`）

| stash | 来源分支 | 内容摘要 | 日期 |
|---|---|---|---|
| stash@{0} | codex/test | test.check.pas + test_assertions.lpr | 07-26 |
| stash@{1} | codex/mem | PAGEMAP-DESIGN-2026-07-27.md（untracked） | 07-27 |
| stash@{2} | codex/math-simd | 7 个 SIMD 文件 + 测试 Makefile + asm_clobber 契约脚本 | 07-26 |
| stash@{3} | hotfix/ci-workflows-fpc-trunk | 5 个 CI/bench 文件 | 07-26 |
| stash@{4} | core-net-async-io | io.reactor.iocp.pas | 07-26 |
| stash@{5} | config-json-xml-toml-yaml-csv-ini | test_config_cross_fuzz/（untracked） | 07-26 |
| stash@{6} | codex/compiler-system | 6 个 sema 文件 + m2/ROADMAP.md（B5g 后 FixupInterfaceParentImt） | 08-02 |
| stash@{7} | bench | findings.md + bench.stats.pas + Makefile | 07-27 |
| stash@{8} | atomic-lockfree | lockfree.workstealing.pas + test_lockfree.lpr | 07-26 |
| stash@{9..14} | 历史遗留 stash（2026-07-15 前） | 原样保留 | — |

⚠️ 注意：stash 是仓库级共享；**任何人 pop 前先看 message 确认是自己的工作**。
恢复命令示例：`cd .worktrees/math-simd && git stash pop stash@{2}`

## 待 owner 决策（本会话未代做）

1. **compiler-system B5g**：stash@{6} 是 08-02 的进行中 sema 工作，收口人应为原 owner。
2. **tui / process-fs-path-env / platform / http**：均有已提交但未 landing 的工作（7/6/33/112 提交），
   按纪律不代他人 landing；需要 owner 自评或总控授权。
3. **历史遗留 stash（stash@{9..14}）**：是否归档/清理由总控决定。

## 已完成的治理动作（2026-08-09）

- ✅ 9 个 dirty worktree 全部命名 stash 固化（`wip-audit-20260809-<name>`），零丢失
- ✅ `git worktree prune`（无失效元数据）
- ✅ 失效 worktree `/tmp/main-check` 已在上轮清理
- ✅ landing 候选分支/worktree 已清理，archive tag：`archive/core-text-unicode-confusables-20260809`
