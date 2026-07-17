# nextpas.core.mem 路线图（权威）

**状态**: **Steady**（Era D Steward 维护姿态；A–C 已闭合；D0/D1/D4 已交付）
**Owner**: mem lane（`.worktrees/mem`）
**更新**: 2026-07-17
**原则**: 只维护一份活路线图；历史 phase 清单进 [archive/](archive/)
**最近 land**: `d2b704ffe`（D0/D1）· 本 slice D4 Scorecard 刷新

---

## 1. 一句话

`nextpas.core.mem` 已从「分配器博物馆」收敛为 **stdlib 级默认堆 + 契约 + 诊断 + 上层集成**。
**下一代工作只跟真实 consumer / 回归 / 可证明性能走**，禁止无消费方的新 allocator Phase。

---

## 2. 时代总览

| 时代 | 主题 | 状态 | 证据 / 档案 |
|------|------|------|-------------|
| **A** | 分配器能力扩张（Phase 12–28、内联重构） | **CLOSED** | [archive/ROADMAP-ALLOCATOR-PHASES.md](archive/ROADMAP-ALLOCATOR-PHASES.md) 等 |
| **B** | 标准库质量（门面 Tier、契约矩阵、Default 双轨、Scorecard、DEBUG） | **CLOSED** | [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md)（90 天 M1–M3 全勾） |
| **C** | 可用性 + 产品表 dual-track + consumer-audit 全修 | **CLOSED** | [USABILITY-SCORE.md](USABILITY-SCORE.md) · [CONSUMER-AUDIT-SUMMARY-2026-07-17.md](CONSUMER-AUDIT-SUMMARY-2026-07-17.md) |
| **D** | **平台 steward**：回归锁、按需集成、性能可信、治理卫生 | **Steady** | 下文 §4 |

成功标准 S1–S7（时代 B）见 [README.md](README.md)；可用性主线无未关 P0/P1。

---

## 3. 时代 A–C 收口（不必再读旧 phase）

### 3.1 已交付能力（稳定）

- **热路径**: `DefaultHeap` / 过程式 `GetMem`/`FreeMem(ptr,size)`（Growing）
- **插件轨**: `DefaultAllocator` = Growing IAllocator 根 + 可选 `NEXTPAS_MEM_DEBUG` 链
- **生命周期**: Arena / VirtualArena / HTTP RequestArena / compiler session·unit scope
- **契约**: `test_contract_matrix`；门面 Tier-0/1/2；Tier-3 不出门面
- **诊断**: `FormatMemStats` / HEAP_DEBUG / HEAP_SAFETY / ARENA_STRICT
- **助手**: `FreeMemOf` / `ReallocMemOf` / `TryBlockSize` / `FormatAllocErrorMsg`
- **Consumer 纪律**: L1+ 关键路径接 mem；L0 platform **不得** `uses mem`；swiss 禁错误 `IAllocator` API

### 3.2 明确不重开

| 项 | 原因 |
|----|------|
| 无 consumer 的 allocator Phase 28+ | 门面与生态已够用；见质量计划 §9 |
| 产品表 dynarray→TVec 冲刺 | dual-track **CLOSED**；keepers 在 USABILITY-SCORE |
| CA-011 product-table keepers | 有意 WAIVED |
| 把 `MemSize`/`AllocAligned` 塞回 `IAllocator` | 接口冻结 |
| 在 mem 内重做 platform 同步语义 | owner 边界 |

### 3.3 历史文档怎么读

| 文档 | 怎么用 |
|------|--------|
| 本文件 `ROADMAP.md` | **唯一活路线图** |
| [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) | 时代 B 执行档案 + Tier 分层权威 |
| [USABILITY-SCORE.md](USABILITY-SCORE.md) | 可用性评分权威（主线 CLOSED） |
| [archive/ROADMAP-*.md](archive/) | 时代 A 清单；**勿当待办** |
| USABILITY-FIX / AUDIT / EVAL / FINDINGS | 可用性履历；主线已关 |

---

## 4. 时代 D — 平台 Steward（新路线图）

**目标**: 在不膨胀表面的前提下，让 mem **难回退、易接入、数字可信**。
**节奏**: 小 slice；默认只改 mem 测试/文档/门面契约；跨模块仅在有命名 consumer 与额外 gate 时做。

### 4.1 主题（按优先级）

| ID | 主题 | 目标 | 验收 | 优先级 |
|----|------|------|------|--------|
| **D0** | 文档单源 | 路线图不乱；README 只链活文档 | 本文件 + README 索引更新 | **DONE** `d2b704ffe` |
| **D1** | 回归锁进主线 | consumer-audit 源契约在 `main` 可跑 | path-limited land `check_consumer_audit_contracts` + guardrails | **DONE** `d2b704ffe` |
| **D2** | 契约不漂移 | Tier-0/1 行为与文档一致 | `test_contract_matrix` + `test_usability_guardrails` 常绿 | P0 持续 |
| **D3** | Consumer 按触达升级 | 已知 size → sized free / `FreeMemOf`；OOM → `FormatAllocErrorMsg` | **谁改谁顺手**；禁止全仓机械扫 | P1 持续 |
| **D4** | Scorecard 可信 | RELEASE 基线可复现；对外说数字有出处 | `make -C …/scorecard clean test RELEASE=1` + [SCORECARD.md](SCORECARD.md) 刷新 | **DONE** 2026-07-17 |
| **D5** | 多 host 契约 | Linux 行为在 Windows/FreeBSD 编译门禁不退 | 既有 cross-OS compile gate 维持；有红点再开 | P1 |
| **D6** | 接入可发现 | API-GUIDE 保持「30 秒 + 反例」；新助手必有门禁 | guardrails / docs contract | P1 |
| **D7** | 错误面收敛（可选） | 评估统一 `EAllocError` 爆炸半径 | **先设计备忘，默认不做代码** | P2 按需 |
| **D8** | 新 API | 仅当 **命名上层模块** 提交需求 + 测试用例 | 新类型默认 Tier-3；进门面需 STDLIB 规则 | P2 按需 |

### 4.2 近期切片（可执行）

| Slice | 内容 | 依赖 | 状态 |
|-------|------|------|------|
| D0-a | 归档时代 A ROADMAP\*；本文件成为权威 | — | **landed** `d2b704ffe` |
| D1-a | consumer-audit 门禁 path-limited → main | main 安静窗口 | **landed** `d2b704ffe` |
| D2-a | 默认 lane gate 不变：`lane-focused LANE=mem` | — | 已落地 |
| D4-a | 刷新 SCORECARD 发布数字（`RELEASE=1` SC1–SC9 全 PASS） | 本机安静跑 | **done** 2026-07-17 |
| D3-a | 不主动扫仓；其它 lane 触达堆路径时提供 review 清单 | 其它模块 owner | 持续 |

### 4.3 退出条件（时代 D 何时算「够稳」）

同时满足即可把时代 D 标为 **Steady**（维护模式，不必再开大里程碑）：

1. D1 门禁在 `origin/main` — **已满足**（`d2b704ffe`）
2. 连续两次 mem landing 无可用性/契约回归 — **2/2**（`d2b704ffe` + 本 D4 docs land）
3. SCORECARD RELEASE 基线有日期戳且与文档一致 — **已满足**（SCORECARD 2026-07-17）
4. 无命名 consumer 的开放 P0/P1 需求单 — 当前无

**Steady 判定（2026-07-17）**: 上述 1–4 均满足 → 时代 D 进入 **Steady** 维护姿态。
Steady 之后默认：**只做 D3 顺手升级 + 修回归**；新里程碑需总控或命名 consumer 发起。

---

## 5. 明确不做（时代 D 有效期内）

1. 新开「Phase 29：再加一打 allocator」
2. 全仓库 unsized `FreeMem` 机械替换
3. 倒逼 L0 platform `uses nextpas.core.mem`
4. 在 mem worktree 上冲 package DTO / HIR Operands 等 **非 mem owner** 产品表
5. raw merge 整条 `mem` 分支进 main
6. 把 Tier-3 实验类型重新塞回门面

跨模块真正需要动别人生产代码时：先 `Needs Review`，path-limited land，验证双方 gate。

---

## 6. 验证与默认入口

```bash
# 默认 mem lane
make lane-focused LANE=mem
# ≡
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix

# 按表面追加
make focused FOCUS=core/tests/nextpas.core.mem/test_debug_wrap
make focused FOCUS=core/tests/nextpas.core.mem/scorecard
make hygiene
```

Consumer-audit 回归：`check_consumer_audit_contracts.sh`（挂在 usability guardrails 的 source-contract）。

---

## 7. 文档权威层级

1. **方向 / 做什么不做**: 本 `ROADMAP.md`
2. **可用性分数**: [USABILITY-SCORE.md](USABILITY-SCORE.md)
3. **Tier / 门面规则**: [STDLIB-QUALITY-PLAN.md](STDLIB-QUALITY-PLAN.md) §3 + [FACADES-SURFACE.md](FACADES-SURFACE.md)
4. **怎么用**: [README.md](README.md) + [API-GUIDE.md](API-GUIDE.md) + [ERROR-POLICY.md](ERROR-POLICY.md)
5. **契约正文**: [CONTRACT.md](CONTRACT.md)
6. **架构边界**: [ARCHITECTURE.md](ARCHITECTURE.md)

冲突时：以编号更小者为准；过时数字以带日期的 SCORE / SCORECARD 刷新为准。

---

## 8. 变更记录

| 日期 | 变更 |
|------|------|
| 2026-07-17 | 初版权威路线图：归档时代 A 多文件 ROADMAP；标注 A–C 闭合；开启时代 D（Steward） |
| 2026-07-17 | D0/D1 path-limited land → `origin/main` `d2b704ffe`；切片状态与退出条件同步 |
| 2026-07-17 | D4-a Scorecard RELEASE=1 基线刷新；时代 D → **Steady** |
