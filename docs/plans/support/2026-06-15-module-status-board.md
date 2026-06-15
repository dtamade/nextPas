# 2026-06-15 Module Status Board

> 本板替代 `2026-06-07-module-status-board.md`。旧板严重过期：未列出 4 个 active lane，
> 把 1 个 active dirty lane 错误标为 historical，列出的 5 个 lane 目录已不存在。
> 旧板保留为历史记录，不删除。本板基于 `git worktree list --porcelain` 实际清单
> 和每个 worktree 的 `git log -3 + git status --short` 取证。

## Summary

仓库当前真实并行状态：

- **active 9 lane**：core-http、core-config-formats、core-simd、core-atomic、
  core-net-async-io、core-platform、core-process-fs-path-env、core-text-unicode、core-tui
- **frozen 2 lane**：compiler、core-system
- **prunable 1**：`core/.claude/worktrees/fix-mktemp`（gitdir 不存在，下一次
  `git worktree prune` 即清除）
- **archived（branch ref 可能仍存）**：core-math、core-mem、compiler-c6g-package-check、
  core-platform-m2b-usability、verify-local-truth

`main` 状态：HEAD `9c2479ef1`，与 origin/main 偏离 ahead 19 / behind 10，且仓库根有
1 个 dirty 文件 `core/src/nextpas.core.platform.error.pas`（应回到 core-platform lane 处理）。

下一步重点不是再扫一轮 landing；先处理 `docs/plans/2026-06-15-nextpas-workmap-takeover-plan.md`
里写出的 P0 治理债（迁 dirty / 同步 main / prune stale / 刷 board），再继续并行 lane 推进。

## 2026-06-15 晚间更新（P0 收尾 + 健康体检）

> 本节为接手 AI 在 P0 完成后追加。下方原始 "Main State" 等小节是 P0 进行中的快照，已被本节与
> `docs/plans/2026-06-15-nextpas-workmap-takeover-plan.md` 的 P0 收尾日志取代。

- **main 实况**：HEAD `3d1e481f1`，工作树 clean，`make hygiene` pass，领先 origin/main 的未推 commit
  为本日治理批次（worktrees 治理章节 + 健康体检报告）。原始 "Main State" 的 ahead 19 / behind 10
  与 dirty `platform.error.pas` 已随 P0.1/P0.2 处理完毕，不再成立。
- **健康体检**：9 条 active lane 代表性 focused gate 全 green（含 0 unfreed），详见
  `docs/plans/support/2026-06-15-fullrepo-worktree-health-check.md`。
- **core-system 标签修正**：下方仍列为 frozen，但实测带 18 个 TLS 文件 dirty，经只读调查是连贯的
  "消除 TLS 外部 RTL 依赖" 重构（`uses SysUtils`→`nextpas.core.base/.fs/...`、`FileExists`→`fs.Exists`、
  `StrAlloc/StrPCopy`→自写 helper），**非 main TLS 迁移的重复**。应重新视为 active mid-refactor，
  由 owner commit 这批 slice（先跑 TLS forced-compile gate）后再规划同步（仅落后 main 36）。
- **3 条 lane 确认被 main 完全吸收**（`git cherry` / `main..` 取证）：core-net-async-io（clean）、
  core-process-fs-path-env（仅 3 个未跟踪 plan 文档）、core-text-unicode（5 commit 已 cherry-pick 进 main，
  仅 1 个未跟踪 plan 文档）。三者为归档候选；破坏性归档（删 worktree/branch + 处理残留文档）待用户确认。

## Main State

- Branch: `main`
- HEAD: `9c2479ef1` `fix(math.trig): handle Low(Int64) edge case in IntPower`
- main vs origin/main: ahead 19, behind 10
- Dirty: `core/src/nextpas.core.platform.error.pas`（按 host owner 引入 linux/darwin/freebsd.base）
- 已知违规：main 领先 19 commit 中含若干 `Merge branch 'codex/...'` 形态的 raw merge，
  违反 `docs/worktrees.md` landing 纪律；后续 sync 不能再放大这条债

## Lane Classes

### Active lanes

#### `core-http`

- Worktree: `.worktrees/core-http`
- Branch: `codex/core-http`
- HEAD: `e4806f667` `fix(http): validate HPACK Huffman padding`
- Dirty: `core/docs/http/ARCHITECTURE.md` / `GOAL_TREE.md` / `README.md` +
  `core/src/nextpas.core.http.impl.h2.client.pas` + `core/src/nextpas.core.http.impl.h2.stream.pas`
- 当前 slice: H2 Finalization Sweep, Phase 2（RED tests for RFC 9113 must-do/should-do gaps）
- 控制规则: 继续 Phase 2 → Phase 3 实施 → Phase 4 commit → Phase 5 final verify

#### `core-config-formats`

- Worktree: `.worktrees/core-config-formats`
- Branch: `codex/yaml-allocator`
- HEAD: `51d6defcb` `fix(platform): add platform_fs_mktemp_handle function`
- Dirty: clean（task_plan 显示 Phase 4 报告待交付）
- 当前 slice: TOML module audit Phase 4（报告结构化 finding，audit-only 不改产线代码）
- 控制规则: Phase 4 报告交付后停在 Ready 等下一指令

#### `core-simd`

- Worktree: `.worktrees/core-simd`
- Branch: `codex/core-simd`
- HEAD: `d0d0195df` `docs(simd): add historical gate fail-close note to maintenance debt table`
- Dirty: 状态未单独抓取（前次为 `core/docs/simd/GOAL_TREE.md` + `check_simd_contract_roadmap.py`）
- 当前 slice: contract / coverage / maintenance debt 文档化
- 控制规则: 继续保持 final-API 纪律 + focused test evidence

#### `core-atomic`

- Worktree: `.worktrees/core-atomic`
- Branch: `codex/core-atomic`
- HEAD: `057401450` `feat(lockfree): add conservative EBR reclamation domain`
- Dirty: 5 files（bench_lockfree、lockfree、test_lockfree、test_lockfree_facade_forced_compile、
  test_lockfree_stress）
- 当前 slice: EBR reclamation 集成 + lockfree contract 强化
- 控制规则: 继续，stop at Needs Review 而不是 drifting

#### `core-net-async-io`

- Worktree: `.worktrees/core-net-async-io`
- Branch: `codex/core-net-async-io`
- HEAD: `3238673ac` `docs(net,async): sync README truth matrix with source contract tests`
- 最近 commit 含 `feat(text): add Format function with {N} placeholders (Phase 3)` —
  **可能跨模块**，需评估是否应拆到 core-text-unicode lane
- Dirty: clean
- 当前 slice: net + async + io 三模块协同（旧版 board 未提及，状态需评估）
- 控制规则: 需要用户决定本 lane 是否继续保持三模块联合，或拆分

#### `core-platform`

- Worktree: `.worktrees/core-platform`
- Branch: `codex/core-platform`
- HEAD: `5c00afec5` `docs(platform): update P3/P4 with Wine CI matrix evidence`
- Dirty: 4 files M + 1 file ??（core/src/nextpas.core.io.reactor.iocp.pas、
  core/src/nextpas.core.platform.fs.pas、test_poller_windows_contract、test_reactor_iocp_wine、
  + 未跟踪 test_platform_wine_ci_matrix_contract/ 目录）
- 当前 slice: Wine CI matrix + IOCP/io.reactor 完善
- 控制规则: 该 lane **仍 active**（旧板错标 historical）。也是 main 上 dirty
  `platform.error.pas` 的合理收纳 lane

#### `core-process-fs-path-env`

- Worktree: `.worktrees/core-process-fs-path-env`
- Branch: `codex/core-process-fs-path-env`
- HEAD: `11dbec603` `fix(core): P2/P3 text, path, and owner polish`
- Dirty: 3 个未跟踪 plan 文档（2026-06-13-process-fs-path-env-audit / -plan /
  2026-06-15-process-fs-path-env-phase2）
- 当前 slice: 已完成 P0-P3 修复批次，进入 Phase 2 规划
- 控制规则: 继续

#### `core-text-unicode`

- Worktree: `.worktrees/core-text-unicode`
- Branch: `codex/core-text-unicode`
- HEAD: `9cc13c071` `feat(text.unicode): add Unicode normalization NFD/NFC/NFKD/NFKC`
- Dirty: 1 个未跟踪 plan（2026-06-13-text-unicode-extension-plan）
- 当前 slice: Unicode normalization 已落地，进入 extension 规划
- 控制规则: 继续

#### `core-tui`

- Worktree: `.worktrees/core-tui`
- Branch: `codex/core-tui`
- HEAD: `a55b285ad` `feat(tui): typed shared-state accessor + ext-first demo pack (Phase 8 Step 2+3)`
- Dirty: clean
- 当前 slice: TUI migration Phase 8（typed shared-state accessor + ext-first demo pack）
- 控制规则: 继续按 Phase 8 slice 推进

### Frozen lanes

#### `compiler`

- Worktree: `.worktrees/compiler`
- Branch: `codex/compiler`
- HEAD: `c8225c41` （C6-H1 已 land 之后冻结）
- Status: frozen
- 控制规则: 不主动启动 C6-H2/C6-H3；要做 G1.5/G1.6/G1.7 推进需要总控明确 spec 后再
  在本 lane 内或新开 `.worktrees/compiler-next` 类似 lane 内做

#### `core-system`

- Worktree: `.worktrees/core-system`
- Branch: `codex/core-system`
- HEAD: `ebedd750`
- Status: frozen（main 已经合并了 codex/core-system 相关变更，本 lane 等新 slice）
- 控制规则: 不重启；只在 consumer 出现明确 system 需求时再开 slice

### Prunable

#### `core/.claude/worktrees/fix-mktemp`

- Branch: `fix/mktemp-restore`
- HEAD: `6e98090c`
- Status: prunable —  `git worktree prune --dry-run` 报 "gitdir 文件指向一个不存在的位置"
- 控制规则: 下一次 `git worktree prune` 自动清除元数据，branch ref 单独评估

### Archived（旧 board 提及，目录已不存在）

- `core-math` — 历史 active；HEAD 已并入 main（main HEAD 即来自 codex/core-math）
- `core-mem` — historical frozen，目录已删
- `compiler-c6g-package-check` — historical packaging check，目录已删
- `core-platform-m2b-usability` — 已 land，目录已删
- `verify-local-truth` — historical verify lane，目录已删

需 P0.3 阶段评估对应 branch ref 是否仍存在、是否需要打 archive tag 后删除。

## Recommended Next Priority

### Priority 0：清治理债（先于任何 P1 实施）

按 `docs/plans/2026-06-15-nextpas-workmap-takeover-plan.md` §P0：

1. 迁移 main 上的 dirty `platform.error.pas` 到 core-platform lane（需用户授权动 main）
2. 同步 main vs origin/main（需用户授权 sync 策略 a/b/c）
3. prune stale worktree 元数据 + 评估 archived branch ref
4. 刷新本 board（本文件即此动作的交付物）

### Priority 1：active lane 推进

按当前 active dirty 情况：

1. core-http（H2 Finalization Sweep Phase 2-5）
2. core-config-formats（TOML audit Phase 4 报告）
3. core-atomic（EBR reclamation 完整集成）
4. core-platform（Wine CI matrix + IOCP/io.reactor + 接收 dirty `platform.error.pas`）
5. core-process-fs-path-env（Phase 2 规划落地）
6. core-text-unicode（extension 规划）
7. core-tui（Phase 8 完成）
8. core-simd（contract / coverage 维护）
9. core-net-async-io（评估三模块联合是否继续）

### Priority 2：compiler 推进（等用户授权解冻 lane）

按 `docs/architecture/nextpas-goal-tree.md` P1：

- G1.5 / G1.6：imported callable type mismatch / no-match / multiple target ranking、
  receiver type 已知但 member kind 不对的诊断
- G1.7 G2：where 子句 + interface 约束（按 generics-design.md）

## Control Rules

继承自旧板 + 本次修订：

- 不把 landed slice branch 当成下一个 continuation lane
- 不重启 frozen lane
- 不 raw-merge 历史 lane（main 上已经有的 raw merge 是历史债，不允许扩大）
- 优先用 focused gate
- 状态报告只发节点：Ready / Needs Review / Blocked / Landed
- main 不做模块开发，只做总控 landing
- core 由 core 团队推进，非 core 任务不直接修改 core/
- 接手 AI 在治理工作（worktree 清理、status-board、文档新增）上可主动；
  在 git sync、main 上动 dirty、动 branch ref、动 core/ 代码 上需用户授权
