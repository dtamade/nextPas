# Multi-Lane Quick Review

- 日期：2026-06-15
- 评审者：接手 AI（按 takeover plan §P1 / 全权授权）
- 评审对象：6 个 active lane 的快评（不做单独的详细 review 文档）
- 范围：core-atomic、core-config-formats、core-process-fs-path-env、core-text-unicode、
  core-tui、core-net-async-io
- 性质：**初步意见**，最终由各 lane owner 判断

各 lane 的详细单独 review（core-platform、core-http）已分别落盘为
`2026-06-15-core-platform-lane-review.md` 和 `2026-06-15-core-http-lane-review.md`。

## 综合视图

| Lane | HEAD | 落后 main | 当前 slice | 治理质量 |
|---|---|---|---|---|
| core-atomic | `057401450` | 5 | EBR-backed MPMC SegQueue (task_plan Phase 2/3) | ✅ 健康 |
| core-config-formats | `51d6defcb` | 5 | TOML audit Phase 4 报告交付中 | ✅ 健康 |
| core-process-fs-path-env | `11dbec603` | 1 | Phase 2 backlog plan 已写，准备 9 任务 sweep | ✅ 健康 |
| core-text-unicode | `9cc13c071` | 6 | Phase 5 已全完成（NFD/NFC/NFKD/NFKC + Hangul） | ✅ 健康 |
| core-tui | `a55b285ad` | **148** | Phase 8 Step 2+3 | ⚠️ 落后过大 + cross-merge |
| core-net-async-io | `3238673ac` | **104** | net+async+io+text(strutils+Format) | ⚠️ 杂烩 lane |

落后 main commit 数都不严重（main 已被推进），但 **core-tui 148** 和
**core-net-async-io 104** 显示这两个 lane 的 baseline 与 main 偏离过大；多次 sync
积累的 cross-merge / cross-module 改动让责任边界模糊。

## core-atomic ✅

- **HEAD**: `057401450 feat(lockfree): add conservative EBR reclamation domain`
- **Dirty**: 5 M + 1 ?? `core/src/nextpas.core.lockfree.segqueue.pas`
- **Slice 形态**: 端到端完整（source + facade + tests + stress + benchmark + forced compile）

### 设计评审

新文件 `nextpas.core.lockfree.segqueue.pas` 实现 EBR-backed unbounded MPMC SegQueue：
- Generic class `TSegQueueImpl<T>` + `TSegQueue<T> = class(specialize TSegQueueImpl<T>)`
  — 符合 nextpas.core.lockfree 现有 generic wrapper pattern
- Segment-based with `SEGQUEUE_SEGMENT_CAPACITY = 32`：Vyukov segmented MPMC queue 风格
- `TSegSlot.Sequence + Value`：每个 slot 用 sequence number 协调（CAS-only）
- EBR (Epoch-Based Reclamation) `TEbrDomain` 安全释放老 segment
- `Create` 强制 `IsManagedType(T) = False`（避免 GC 复杂性）：合理 contract

### 建议

1. ✅ 当前 slice 可以按"完成 task_plan Phase 3 → Phase 4 verification → commit"流程收尾
2. 建议 commit 拆分：
   - `feat(lockfree): add EBR-backed segqueue` (source + facade re-export)
   - `test(lockfree): add segqueue tests + stress + forced compile`
   - `bench(lockfree): add segqueue benchmark`
3. 跑 `make -C core/tests/nextpas.core.lockfree/test_lockfree clean test/test-forced-compile`
   + `test_lockfree_stress clean test` + `bench_lockfree clean build` 验证 task_plan §Verification Target

## core-config-formats ✅

- **HEAD**: `51d6defcb fix(platform): add platform_fs_mktemp_handle function`
- **当前**: TOML audit Phase 4 报告即将交付

### 评审

findings.md 已识别 1 High + 4 Medium + 1 Low + 5 Coverage Gaps，质量非常高：

**High（公共内存安全 footgun）**：
- `TTomlValue.Create` 是 borrowed record 的公开构造函数，外部调用者可伪造
  out-of-range `FIdx` 触发未检查的 `FDoc^.Node(FIdx)` 访问
- 内部 call site 正确，但公开 API 表面有真实安全隐患

**Medium（多个 audit-only finding）**：
- 错误位置报告基于 token-end 而非 offending-byte（escape failure / datetime parse）
- `FindByPath` 不感知 quoted keys（按 `.` 简单 split）
- `AsInt` 静默截断 float / `AsFloat` 提升 int — 非对称类型策略
- 原始字节 UTF-8 验证缺失（escaped Unicode 已正确编码，但 raw bytes 透传）

**Low**：
- writer 硬编码 128 segment ceiling，parser 接受 source shape 会在 stringify 时超限

### 建议

1. ✅ Phase 4 报告交付后由用户决定是否进 Phase 5（修复 High 项 + 至少 2-3 个 Medium）
2. High 项推荐修复：把 `TTomlValue.Create` 标 `protected` 或加 `Validate` precondition
3. Coverage gaps（5 个）建议作为后续 lane slice 直接补
4. lane 分支名 `codex/yaml-allocator` 与 TOML audit 范围不一致，建议后续 lane 名跟随实际工作内容

## core-process-fs-path-env ✅

- **HEAD**: `11dbec603 fix(core): P2/P3 text, path, and owner polish`
- **Phase 1 已完成**（4 commit 已 commit）
- **Phase 2 plan 极详细**：9 任务约 4-5 工作日

### 评审 Phase 2 plan 设计

**质量**：plan 文档 1180 行，每个任务都有 file map / Pascal code 示例 / risk 评估 /
estimate / commit 命名建议。这是非常高质量的 lane planning 文档。

**优先级排序合理**：
1. FsWalk rewrite（唯一硬 P0 blocker）
2. spawn_* cleanup（先识别 test 依赖再删）
3. ExpandEnv（独立 P1）
4. ReadFile / CopyFile / 常量整理（性能 + cleanup）
5. path facade unification（最高风险，留到最后）
6. WriteFileLines（低风险 sweep tail）

**Task 8 风险点**：
- path facade unification 改 public compatibility surface
- 推荐"choose fs.path as implementation owner + nextpas.core.path 变 thin facade"
- 我同意这个方向：保留 ExtractFilePath/ExtractFileName/ExtractFileExt/ChangeFileExt 公共 API
  避免破坏 consumer

### 建议

1. ✅ Phase 2 plan 设计完整，直接按 sub-skill `superpowers:subagent-driven-development`
   或 `superpowers:executing-plans` 执行即可
2. ⚠️ Task 3 spawn_* cleanup 提醒：现有 plan 文档已经识别"production 是死代码但 test 还用"
   的微妙点，按 plan 走（先迁 test 再删 wrapper）
3. 建议每完成一个 task 就一个独立 commit，按 worktrees.md 纪律保持小步可回滚

## core-text-unicode ✅

- **HEAD**: `9cc13c071 feat(text.unicode): add Unicode normalization NFD/NFC/NFKD/NFKC`
- **Phase 1-5 全部完成**

### 评审

task_plan 显示 Phase 1-5 全部 ✅ 完成：
- Phase 1 Discovery
- Phase 2 RED tests
- Phase 3 Generator + 数据（Unicode 16.0）
- Phase 4 Implementation（含 Hangul algorithmic + quick check）
- Phase 5 Verification（focused test + git diff --check + hygiene）

3 个 commit 已 land：
- normalization NFD/NFC/NFKD/NFKC
- case mapping + case folding
- UCD property tables + base types + codepoint property queries

### 建议

1. ✅ 该 lane 当前可以**报 Ready 进入 landing 队列**：HEAD 已就绪、Phase 5 verification 已过
2. 1 个未跟踪 `2026-06-13-text-unicode-extension-plan` 建议归档到 `docs/plans/`
   或保持 lane 内（如果是 lane 自己的 next slice plan）
3. lane next slice 建议：normalization + case mapping + property 之后，可以是 grapheme
   cluster boundary / word boundary（UAX #29）或 collation（UAX #10）

## core-tui ⚠️

- **HEAD**: `a55b285ad feat(tui): typed shared-state accessor + ext-first demo pack (Phase 8 Step 2+3)`
- **落后 main 148 commit**（最大！）
- 最近 commit 序列：4 个 merge 把 codex/core-base-errors-exception /
  codex/core-id-hash-random / codex/core-net-async-io / codex/core-config-formats merge 进来

### 评审

**正面**：
- Phase 8 Step 2+3 完成 typed shared-state accessor + ext-first demo pack
- 主动 merge 上游 lane 修复（base/errors/exception、id/hash/random、net/async/io、config 等）
  显示 lane owner 知道 dep 升级

**问题**：
- **落后 main 148 commit** 表明 lane baseline 严重老化
- 4 次 merge 让 lane HEAD 充满 cross-lane merge metadata
- 这种 cross-lane merge 模式违反 worktrees.md "不要 raw merge 长期模块 lane 到 main"
  的反向情形 — lane 反向吸收别的 lane 也是同样的"raw merge debt"

### 建议

1. ⚠️ 建议 lane owner **停下来评估 baseline sync 策略**：
   - 是继续每隔 N 周吸收一次上游？(累积 raw merge debt)
   - 还是把 Phase 8 工作 cherry-pick 到 `landing/tui-phase8-20260615` 候选分支后
     ff-only 上 main? (按 worktrees.md 规则)
2. 当前 lane 应该尽快推 Phase 8 完整收口（如果 Step 2+3 是最后两步），然后用候选分支落地
3. 不建议继续在本 lane 上叠新功能 — landed slice branch 不应该当 continuation lane
4. Phase 8 完成后，建议把 codex/core-tui 归档（archive tag）+ 新开 lane

## core-net-async-io ⚠️

- **HEAD**: `3238673ac docs(net,async): sync README truth matrix with source contract tests`
- **落后 main 104 commit**（第 2 大！）
- 最近 commit 跨越多模块：net + async + io + text(Format + strutils)

### 评审

**问题**：
- 这个 lane 已经变成"杂烩 lane"
  - `docs(net,async)`：net + async 文档
  - `test(text)`、`feat(text)`：text(Format) — 不属于 net/async/io
  - `test(strutils)`、`feat: strutils`：strutils 是 L1 模块，也不属于 net/async/io
- 违反 worktrees.md "一个 worktree 只负责一个模块或一条明确治理线"

**可能的合理化**：
- 也许这些是同一个开发者在多模块间快速迭代的实战记录
- text.Format / strutils 可能是 net/async/io 工作的必要依赖（need-for-implementation 的
  跨模块改动）

### 建议

1. ⚠️ 建议 lane owner **梳理 commit 历史**：
   - 哪些 commit 是 net + async + io 主线工作？
   - 哪些 commit 是 text.Format + strutils 作为 cross-module dependency 工作？
2. 推荐拆分：
   - `landing/core-net-async-io-net-slice-20260615`：只挑 net + async + io commit
   - `landing/core-text-format-strutils-20260615`：把 text + strutils commit cherry-pick
     出来作为独立 slice
3. 拆分后两个 slice 各自走 landing-check + ff-only
4. 后续 lane owner 应该把 text + strutils 工作放到 `core-text-unicode` 或新开 `core-strutils` lane

## 综合下一步建议

按风险与可推进性排序：

| 优先级 | Lane | 推荐动作 |
|---|---|---|
| P1 | core-text-unicode | 直接 ready → landing（Phase 5 已绿） |
| P1 | core-atomic | 完成 task_plan Phase 3-4 → ready |
| P1 | core-config-formats | Phase 4 报告交付 → 用户决定是否 Phase 5 修复 |
| P1 | core-process-fs-path-env | 按 Phase 2 plan 执行 9 任务（4-5 工作日） |
| P2 | core-tui | 停下来评估 baseline sync 策略；不建议继续叠新功能 |
| P2 | core-net-async-io | 梳理 commit 历史，拆分 net 主线与 text + strutils 跨模块 |
| 等 | core-http | 见 `2026-06-15-core-http-lane-review.md`（MSG_NOSIGNAL 跨模块要先解决） |
| 等 | core-platform | 见 `2026-06-15-core-platform-lane-review.md`（4 dirty 拆 4 commit + sync main） |

## 跨 lane 治理建议

1. **建立 lane 命名一致性**：
   - `codex/core-config-formats` 分支名 `codex/yaml-allocator` 不匹配 → 重命名或新开
   - `codex/core-net-async-io` 实际跨 net + async + io + text + strutils → 拆分
2. **建立 main sync 节奏**：
   - lane 落后 main 超过 N commit（例如 50？100？）必须停下来 sync
   - 不要让 lane 累积 100+ commit 后才一次性 merge
3. **建立 landing 候选分支模板**：
   - lane HEAD 准备 land 时，先开 `landing/<lane>-YYYYMMDD` 候选分支
   - 跑 `make landing-check BASE_REF=main ALLOW_PATHS=... FOCUS=...`
   - ff-only merge 到 main
   - 不要直接在 lane 分支上 `git merge main` 后 push（产生 raw merge）

## 评审纪律说明

按 nextpas-goal-tree.md "core 由 core 团队推进"，本评审：

- ❌ 不动任何 lane 代码
- ❌ 不在 lane 内创建/修改文档
- ✅ 只读分析 + 主线治理文档形式留下评审记录
- ✅ 输出由各 lane owner 自行采纳或反驳

跨 lane 治理建议（命名、sync 节奏、landing 模板）属于仓库治理范畴，建议由总控考虑
是否纳入下一版 `docs/worktrees.md` 修订或单独 RFC。
