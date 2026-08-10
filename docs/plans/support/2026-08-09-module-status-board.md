# Module Status Board — 2026-08-11（v4，stash 治理收口后）

> 更新：2026-08-11（会话内第四次快照，历史遗留 stash 全量处置、治理面闭环）。
> 用途：多人并行下恢复上下文 + 未提交工作恢复台账。
> 纪律：他人 dirty 一律不动原文件；用命名 stash 固化（零丢失、可恢复）；不代他人 sync/landing。

## main 分支（当前）

- HEAD `5b113b9cf`，**与 origin/main 零偏差**（已推送）
- 本会话（2026-08-09 之后）落地并推送的提交：
  - `5b113b9cf` docs(http): IOCP 回调错误码语义漂移 residual 记录
  - `87f8eac61` ci: trunk FPC verify job + bench 基线 schema 修复 + flake 取证
  - `90d2fc26a` docs(bench): F-34 诚实化 + 门禁失败取证汇总行
  - `0f326215a` test(config): absorb cross-format differential fuzz suite
  - `c56f647be` fix(yaml): decode double-quoted escapes + fold single-quoted ''（YAML 1.2 §7.3）
- **他人 dirty（未提交，勿动）**：`core/src/nextpas.core.tui.terminal.pas`、`core/src/nextpas.core.tui.widget.input.pas`、`core/tests/nextpas.core.tui/test_tui_terminal/test_tui_terminal.lpr`
  （v3 记录的 `collections.concurrent.hashmap.pas` / `hashmap.swiss.pas` 已由他人提交或清理，本会话未触碰）

## 🔒 Stash 台账（2026-08-11 收口后，仅剩 1 个）

| stash | 来源分支 | 内容摘要 | 状态 |
|---|---|---|---|
| stash@{0} | codex/compiler-system | 08-02 B5g sema 进行中工作 6 文件 + m2/ROADMAP.md（FixupInterfaceParentImt） | **保留，待 owner 收口** |

### 处置记录（2026-08-09 固化 9 个 + 历史遗留 6 个，→ 2026-08-11 收口）

| 处置 | 内容 | 存档 / 去向 |
|---|---|---|
| ✅ 吸收 | @0 StringDiff 评估后代码全仓零调用 → 删除（存档） | `build/stash-archive/0-wip-audit-20260809-test-*.patch` |
| ✅ 吸收 | @1 mem PAGEMAP-DESIGN 文档（源码已实现，文档过时）→ 删除（存档） | `build/stash-archive/1-...mem-*.patch` |
| ✅ 吸收 | @2 math-simd 7 文件 + asm_clobber 契约 → 重命名动机不明，删除（存档） | `build/stash-archive/2-...math-simd-*.patch` |
| ✅ 吸收 | @3 → @9 ini 去 fs 重写（风险高）→ 删除（存档） | `build/stash-archive/9-wip-foreign-...patch` |
| ✅ 吸收 | @4 io.reactor.iocp（IocpMapOsError 无法在 Linux 验证）→ 记录 residual，补丁存档 | `core/docs/http/ROADMAP.md` + `build/stash-archive/4-...core-net-async-io-*.patch` |
| ✅ 吸收 | @5 config cross-format fuzz → 提交 `0f326215a`（顺带修复 yaml 转义 bug） | `c56f647be` fix(yaml) |
| ✅ 吸收 | @6 workstealing F-047（LIFO→FIFO，无基准证据）→ 删除（存档） | `build/stash-archive/8-...atomic-lockfree-*.patch` |
| ✅ 吸收 | @7 bench F-34 诚实化 + 门禁行 → 提交 `90d2fc26a` | `build/stash-archive/7-...bench-*.patch` |
| ✅ 吸收 | @8 CI 5 文件 → 提交 `87f8eac61` | `build/stash-archive/3-...hotfix-ci-*.patch` |
| ✅ 删除 | mem PAGEMAP-DESIGN（文档过时） | `build/stash-archive/mem-PAGEMAP-untracked.patch` |
| ✅ 删除 | 历史遗留 @1 tmp-k（mem.stack_pool 5 行，main 已吸收同模式） | `build/stash-archive/hist1-tmp-k.patch` |
| ✅ 删除 | 历史遗留 @2 PAsyncLoop transitional（class 版已落地） | `build/stash-archive/hist2-pasyncloop.patch` |
| ✅ 删除 | 历史遗留 @3 non-platform dirt 隔离（含已推迟 system.classes） | `build/stash-archive/hist3-nonplatform-dirt.patch` |
| ✅ 删除 | 历史遗留 @4 main dirt 清理快照（153K 行删除快照） | `build/stash-archive/hist4-main-dirt.patch` |
| ✅ 删除 | 历史遗留 @5 test-audit WIP（大删除中间态） | `build/stash-archive/hist5-test-audit-wip.patch` |

> 处置原则：丢弃前一律 `git stash show -u -p` 全量存档到 `build/stash-archive/`（本地
> ignored 目录，零丢失保障）；吸收内容以小提交落入 main；无法验证的（IocpMapOsError）
> 记录 residual 不吸收未验证代码。

## Worktree 实况（收口后，他人 lane 未动）

| Worktree | 分支 | 状态 | 动作 |
|---|---|---|---|
| main 根 | main | dirty（他人 tui 3 文件） | 未动 |
| `.worktrees/compiler-system` | codex/compiler-system | clean，stash@{0} 待 owner | 未动 |
| `.worktrees/http` | codex/http | clean，stale（他人 lane） | 未动 |
| `.worktrees/platform` | codex/platform | clean，stale（他人 lane） | 未动 |
| `.worktrees/process-fs-path-env` | process-fs-path-env | clean，stale（他人 lane） | 未动 |
| `.worktrees/tui` | tui | clean，stale（他人 lane） | 未动 |
| 其余 9 个（test/bench/mem/math-simd/...） | 已收敛或已处置 | 见 v3 台账 | ✅ 收口 |

## 待 owner 决策（本会话未代做）

1. **compiler-system B5g**（stash@{0}）：08-02 的进行中 sema 工作，收口人应为原 owner；
   如需继续 M2 下一桶请基于最新 main（5b113b9cf）重开 lane。
2. **tui / process-fs-path-env / platform / http**：均有已提交但未 landing 的工作
   （stale ahead），按纪律不代他人 landing；需要 owner 自评或总控授权。
3. **IocpMapOsError**：修复补丁已存档，待 Windows 交叉编译环境（ppcrossx64）验证后落地。

## 已完成的治理动作（2026-08-11）

- ✅ 处置 2026-08-09 固化的 9 个命名 stash + 历史遗留 6 个：吸收 5 个（fuzz→发现并修复
  yaml 转义 bug、bench F-34、CI 5 文件）、删除 11 个（全部先存档 `build/stash-archive/`）
- ✅ 历史遗留 5 个深度确认后 drop：tmp-k（main 已吸收）、PAsyncLoop（过渡态）、
  non-platform dirt（含已推迟 system.classes）、main dirt（153K 行清理快照）、
  test-audit WIP（删除中间态）——drop 前逐一存档，零丢失
- ✅ 验证证据：yaml spec 36 / scanner 16 / roundtrip 12 / fuzz 7 / builder 26 全绿 + config
  fuzz 4/4（0 unfreed）；bench `[GATE-ALL-GREEN] 22 suites`；CI 改动 bash -n + yaml.safe_load
- ✅ `git diff --check` / `make hygiene` 通过；main 已推送至 5b113b9cf