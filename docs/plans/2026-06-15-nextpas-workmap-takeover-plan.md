# nextPas Workmap Takeover Plan

- 状态：采用中
- 日期：2026-06-15
- 范围：新接手 AI 同事的工作地图、治理债清理、并行 lane 推进顺序

## 目的

`docs/architecture/master-roadmap.md` / `compiler-roadmap.md` / `bootstrap-roadmap.md`
负责长期顺序，`docs/architecture/nextpas-goal-tree.md` 负责目标节点，
`docs/plans/2026-03-24-nextpas-master-roadmap-plan.md` 负责 compiler 主线滚动批次。
这份计划只负责一件事：**新接手者**进入 nextPas 后，在治理债没清干净 + 多个 lane
并行 + status-board 过期的现状下，按什么顺序推进、跟哪些 lane 配合、哪些操作必须
先拿到总控授权。

完成 / 失效条件：等所有治理债项被处理掉、status-board 被刷新到当前真实状态后，
本计划归档到 `docs/plans/support/` 或直接关闭，由 master-roadmap-plan 接管常规批次。

## 当前 ground truth（2026-06-15 调研结果）

### main 分支状态

```text
main HEAD     = 9c2479ef1 fix(math.trig): handle Low(Int64) edge case in IntPower
main vs origin = ahead 19, behind 10
dirty files   = core/src/nextpas.core.platform.error.pas (+9/-0)
```

- main 领先 origin 的 19 commit：math.trig 修复、io.mapped.slab_pool、IOCP/socket Wine 修复、
  process/fs/path/env P0-P3 修复；内含若干 `Merge branch 'codex/...'` 形态的 raw merge
  （违反 `docs/worktrees.md` 的 landing 纪律，不能再扩散）。
- main 落后 origin 的 10 commit：全部是 TLS 模块 `TStringList -> TStringArray` 迁移
  + 1 个 `Merge pull request #1 from dtamade/codex/core-system`。
- dirty 改动是 platform 模块工作，应回归 `.worktrees/core-platform` lane 处理。

### Worktree 真实清单（与 module-status-board 对照）

`git worktree list --porcelain` 显示的真实 worktree（去除已不存在的目录）：

| Worktree | 分支 | HEAD | 实况 | board 标注 | 是否对齐 |
|---|---|---|---|---|---|
| `.worktrees/compiler` | codex/compiler | c8225c41 | frozen | frozen | ✅ |
| `.worktrees/core-atomic` | codex/core-atomic | 05740145 | active dirty (lockfree) | active | ✅ |
| `.worktrees/core-config-formats` | codex/yaml-allocator | 51d6defc | active (TOML audit) | active | ✅ |
| `.worktrees/core-http` | codex/core-http | e4806f66 | active dirty (H2 finalization) | active | ✅ |
| `.worktrees/core-net-async-io` | codex/core-net-async-io | 3238673a | active (net+async+io+text) | **未提及** | ❌ board 缺 |
| `.worktrees/core-platform` | codex/core-platform | 5c00afec | **active dirty (IOCP/io.reactor)** | historical | ❌ board 错 |
| `.worktrees/core-process-fs-path-env` | codex/core-process-fs-path-env | 11dbec60 | active (P0-P3 修复完) | **未提及** | ❌ board 缺 |
| `.worktrees/core-simd` | codex/core-simd | d0d0195d | active (contract/coverage) | active | ✅ |
| `.worktrees/core-system` | codex/core-system | ebedd750 | frozen | frozen | ✅ |
| `.worktrees/core-text-unicode` | codex/core-text-unicode | 9cc13c07 | active (Unicode normalization 已完成) | **未提及** | ❌ board 缺 |
| `.worktrees/core-tui` | codex/core-tui | a55b285a | active (Phase 8 进行中) | **未提及** | ❌ board 缺 |
| `core/.claude/worktrees/fix-mktemp` | fix/mktemp-restore | 6e98090c | **prunable**（gitdir 不存在） | 未提及 | ⚠️ 需 prune |

board 提到但 **目录已不存在**：`core-math`、`core-mem`、`compiler-c6g-package-check`、
`core-platform-m2b-usability`、`verify-local-truth`。这些只剩 branch ref，需要决定是否归档。

### 关键事实结论

1. **module-status-board 严重过期**：4 个 active lane 未提及，1 个 active dirty lane 被
   错误标记为 historical，5 个 lane 的目录已不存在但 board 仍把它们当当前事实。
2. **main 上的 dirty 改动是 platform owner 工作**：按规矩必须回到 `.worktrees/core-platform`
   或新开 landing 候选分支处理，不能在 `main` 上直接 commit。
3. **main 的 ahead 19 中包含 raw merge**：再扩张就会污染主线 landing 纪律；后续合并
   必须改走 `make landing-check` + ff-only 候选分支。
4. **origin 领先 10 commit 是 TLS PR**：需要先 fetch 评估，再决定 rebase / merge 还是
   等本地 TLS lane 收口后批量集成。

## 总体推进顺序

```text
P0 治理债（必须先做，无 P1）
  -> P-meta 把工作地图落盘为本文档
  -> P0.1 迁移 main 上的 dirty 改动到 core-platform lane
  -> P0.2 同步 main vs origin/main（需用户授权决定 rebase / merge 策略）
  -> P0.3 prune stale worktree 元数据 + 归档已失效 branch ref
  -> P0.4 刷新 module-status-board 到 2026-06-15

P1 并行 lane 推进（治理稳定后）
  -> P1.1 [compiler] G1.4 / G1.5 / G1.6 sema diagnostics 下一 slice
  -> P1.2 [compiler] G1.7 泛型 G2 约束 + where（按 generics-design.md）
  -> P1.3 [core] 协助 core-http H2 finalization sweep（已 in_progress）
  -> P1.4 [core] 协助 core-config-formats TOML audit Phase 4 报告
  -> P1.5 [core] 协助 core-atomic EBR reclamation 下一 slice
  -> P1.6 [core] 决定 core-net-async-io / core-process-fs / core-text-unicode / core-tui
          的优先级与排期

P2 workspace + tooling 收口
  -> P2.1 G4/G5 package workflow 下一条只读 truth slice
  -> P2.2 doctor / query / env 的下一条 projection

P3-P4 远期（等 P1 sema/G1 收口 + workspace truth 稳定后）
  -> backend/toolchain ABI / layout / debug info
  -> language service / IDE / GUI 主线开启
```

## 我（接手者）的工作边界

按 `docs/architecture/nextpas-goal-tree.md` + `AGENTS.md`：

| 区域 | 我能做 | 我不能做 |
|---|---|---|
| 治理（main 清理、worktree、status-board、文档） | 直接做（受总控授权） | 强删 dirty / force push / 跳过 hygiene |
| compiler 模块（`compiler/`） | 在 `.worktrees/compiler` 下做（lane frozen，开启需总控授权） | 直接在 main 上改 compiler/ |
| core 模块（`core/`） | **不直接改 core/** — 只能在 .worktrees/<core-lane> 内做受总控授权的协助 / 评审 / 提需求 | 在 main 上改 core/、在非自己 lane 的 dirty worktree 改文件 |
| docs/plans/ 这类文档 | 在 main 上写新计划、刷新 status-board 是允许的治理动作 | 改写 docs/architecture/ 或 docs/adr/ 的稳定事实未经授权 |

## P0 治理债处理细则

### P0.1 迁移 dirty 改动到 core-platform lane

**事实**：`core/src/nextpas.core.platform.error.pas` 修改：implementation uses 中按
`NEXTPAS_LINUX` / `NEXTPAS_MACOS` / `NEXTPAS_FREEBSD` 分别引入对应 host base 单元。

**设计合规性**：✅ 完全符合 `core/docs/design-conventions.md` §18 — errno token 必须
由各 host owner 提供。`platform_error_category` 函数本来就在消费 `ESysENOENT` /
`ESysEPERM` / `ESysEACCES` / `ESysEEXIST` / `ESysEINVAL` 等 token，这些 token 的
真实 owner 在 `linux.base.errno.inc` / `darwin.base.errno.inc` / `freebsd.base.errno.inc`。

**推荐处理路径**（两种，等用户授权后执行）：

- **方案 A（推荐）**：把 dirty patch 应用到 `.worktrees/core-platform` lane，由
  platform lane 在自己的工作流里跑 host-matrix forced-compile gate 后 commit。
  main 上的 dirty 用 `git checkout -- core/src/nextpas.core.platform.error.pas`
  恢复（必须用户授权）。

- **方案 B**：在 main 上新建 `landing/platform-error-host-owner-20260615` 候选分支，
  按 `make landing-check BASE_REF=main ALLOW_PATHS=core/src/nextpas.core.platform.error.pas
  FOCUS=core/tests/nextpas.core.platform/...` 跑通后 ff-only merge。这条路径需要
  platform lane 同时确认这个改动不与 lane 内 active dirty 冲突。

不能采用方案：直接在 main 上 commit；这会进一步污染 main 的 landing 纪律。

### P0.2 同步 main vs origin/main

**事实**：main 落后 origin 10 commit，全部是 TLS 模块迁移 + 1 个 PR merge。main 领先
origin 19 commit，包含数个 raw merge。

**风险**：
- 直接 `git pull --rebase` 会让 main 的 raw merge 提交在 rebase 时被打散，可能造成
  不可控的冲突或丢失 merge metadata。
- 直接 `git pull --no-rebase`（merge） 会产生新 merge commit，但保留 main 的 raw
  merge 历史，强化已有 landing 纪律违规。
- 直接 `git push origin main`（force 或 non-ff）会覆盖 origin 上的 TLS 迁移。

**推荐处理路径**（需用户明确指示）：

1. 先 `git fetch origin` 看完整 origin commit 列表
2. 判断 origin 上的 TLS 迁移是否应作为新的 TLS lane（`codex/core-tls`）落地
3. 选择：
   - 选 a：在 main 上 `merge --no-ff` origin/main，保留双方历史，记录这次 sync 是
     "exceptional"（main 历史已经有 raw merge debt，再加一次 merge 不变更纪律性质）
   - 选 b：rebase main onto origin/main，重写本地 19 commit。**风险高**：会改 SHA、
     破坏 raw merge metadata，所有引用 main HEAD 的 status-board / plan 文档都要更新。
   - 选 c：暂不同步，先把本地 19 commit 通过正式 landing-check 各自落到 origin（这
     是最严格但最慢的方案，需要逐个回 lane 重新做 ff-only）

我倾向 a（最小破坏 + 维持 landing 现状），但需要用户授权再动 git。

### P0.3 prune stale worktree 元数据

**事实**：`core/.claude/worktrees/fix-mktemp` gitdir 已不存在，可被 `git worktree prune` 安全清掉。
另有 5 个 board 提及但目录已不存在的 worktree：`core-math`、`core-mem`、
`compiler-c6g-package-check`、`core-platform-m2b-usability`、`verify-local-truth`。

`git worktree list --porcelain` 已经不显示它们了，说明 worktree 元数据已 prune；
但对应的 branch ref 可能还存在。需要：

1. 跑 `git worktree prune -v` 清掉 fix-mktemp 元数据
2. 跑 `git branch -a | grep -E 'codex/(core-math|core-mem|core-platform-m2b)'` 看 branch 是否还在
3. 如果还在且没有 ahead origin 未推：用 `git tag archive/<short-name> <branch>` 打 archive tag，
   再 `git branch -D <branch>` 删除

需要用户授权才能动 branch ref。

### P0.4 刷新 module-status-board

**事实**：`docs/plans/support/2026-06-07-module-status-board.md` 距今已 8 天，
status 严重过期。

**动作**：基于 P0.3 之后的真实 worktree 清单，用今天日期写新版 status-board：
`docs/plans/support/2026-06-15-module-status-board.md`，按"active / frozen / archived"
三档列 12 个仍存在的 worktree，并把 5 个不再存在的旧 lane 列在 "archived" 段。

旧版 board 保留为历史记录，不删除。

## P1 推进策略

### compiler 工作（G1.x）

`.worktrees/compiler` 当前 frozen 在 `c8225c41`。要推进 G1.5/G1.6/G1.7 需要：

1. 用户授权重新激活 compiler lane（或开新 lane `.worktrees/compiler-next`）
2. 在新 lane 内绑定一个具体 G 节点（按 goal tree §G1.5/G1.6/G1.7 选 next slice）
3. 按 5 行报告模板写本轮 task_plan：
   ```text
   目标节点：G1.X.Y
   当前缺口：<具体>
   本轮交付：<具体代码或验证能力>
   验证方式：<具体 verify_local gate>
   本轮不做：<明确边界>
   ```
4. RED 测试 → impl → focused gate → fresh `bash build/verify_local.sh` → 5 行复盘

候选 slice（按 goal tree §G1.5/G1.6/G1.7 + master-plan Batch 84+ 上下文）：
- G1.5: imported callable type mismatch / no-match / multiple target ranking
- G1.5: record/property/array/deref receiver 的 member-call
- G1.6: receiver type 已知但 member kind 不对的诊断分类
- G1.7 G2: where 子句基本形式 + interface 约束（按 `docs/architecture/generics-design.md` 分层）

具体 slice 选择待用户授权时定。

### core lane 协助

按 goal tree "core 由 core 负责人写"，我作为接手 AI 在 core lane 内只做：
- 评审 / 提需求 / source-contract 审计 / 帮跑 focused gate
- 不在 core lane 内主导写产线代码（除非用户明确授权）

候选评审对象（按 active dirty 优先）：
- **core-http**：H2 finalization sweep Phase 2 RED 测试设计 + Huffman padding fix 评审
- **core-config-formats**：TOML audit Phase 4 报告评审
- **core-atomic**：lockfree 5 文件 dirty + EBR reclamation 设计评审
- **core-platform**：IOCP / io.reactor / fs 多文件 dirty 评审（关联 P0.1 dirty 来源）
- **core-process-fs-path-env**：3 个新增 plan + P1-P3 修复评审
- **core-text-unicode**：Unicode normalization 已完成，可看 extension plan
- **core-tui**：Phase 8 进行中评审
- **core-net-async-io**：最近改动跨到 text 模块，可能需要 cross-module review

具体选择待用户授权时定。

## 决策日志

| 时间 | 决策 | 理由 |
|---|---|---|
| 2026-06-15 | 把工作地图写成正式 plan 文档而不是只回复 chat | 用户明确要求落盘 + 需要长期锚点供后续会话恢复 |
| 2026-06-15 | P0 治理债先于任何 P1 实施工作 | dirty 在 main + status-board 过期是高优先级污染源 |
| 2026-06-15 | dirty 改动不直接在 main 上 commit | 违反 AGENTS.md "main 不做模块开发" + goal tree "不碰 core" 双纪律 |
| 2026-06-15 | main / origin sync 等用户授权再动 | git 同步策略选择有高破坏风险，必须用户决策 |
| 2026-06-15 | compiler / core lane 推进等用户授权再动 | compiler frozen 需要授权解冻；core 非接手者主战场 |

## 风险与回退

- **风险 1**：在 main 上做了 dirty patch 的恢复操作但 platform lane 拒收
  - 回退：把 dirty patch 保存为 `.patch` 文件归档到 `docs/plans/support/`，恢复 main
- **风险 2**：main 同步引入新的冲突或 raw merge
  - 回退：保留 sync 前 ref 为 archive tag，sync 失败可 reset 回去
- **风险 3**：刷新 status-board 时漏掉 active lane
  - 回退：保留旧版 board 不删，新板列出"参考旧板对比"段，发现遗漏可补
- **风险 4**：compiler lane 重新激活时本地 stale state 与 spec 不一致
  - 回退：在 lane 内 `make hygiene` + 跑 focused gate 验证 baseline，再开 slice

## 每轮报告模板

按 goal tree §每轮报告格式：

```text
目标节点：
当前缺口：
本轮交付：
验证方式：
本轮不做：
```

收口：

```text
完成节点：
新增能力：
验证结果：
剩余风险：
下一节点：
```
