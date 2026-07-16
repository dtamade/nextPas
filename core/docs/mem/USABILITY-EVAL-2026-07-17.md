# nextpas.core.mem 高标准可用性评估（本轮权威）

**日期**: 2026-07-17
**模式**: 只读审查 → 本文件；修复见 research / fix-plan / 实现
**范围**: 默认双轨产品路径（DefaultHeap / DefaultAllocator）、过程式 API、诊断 env、错误模型、门面、focused gates
**对标**: Go `runtime` 分配默认 + `ReadMemStats`/`GODEBUG`；Rust `GlobalAlloc`/`Layout` + debug/sanitizer 工程习惯
**前序**: F1–F7 已落地（9.1）；本轮查**残留**与回归风险，不 reopen dual-track 热路径

---

## Summary

| 项 | 值 |
|----|-----|
| **综合分（本轮审查时）** | **8.9 / 10** |
| **综合分（R1–R5 修复后）** | **9.3 / 10**（见 [USABILITY-SCORE.md](USABILITY-SCORE.md)） |
| **等级** | **HIGH** |
| **风险总评** | **LOW–MEDIUM**（热路径 UB 仍为设计选择；R1–R5 已关） |
| **F1–F7** | 已修复，本轮视为基线 |
| **本轮新发现** | **R1–R5** — **全部 fixed** |

**一句话**: 双轨零税与 F1–F7 观测/安全 opt-in 已达标；残留短板是 **FormatMemStats 未暴露 SAFETY/ARENA_STRICT**、**插件面 sized realloc 助手缺失**、**多 env 无单行 profile**，以及对应契约门禁未锁。

故意不降分项：默认双 free=UB（与 Go 非 GC 手写 free / 零税一致，靠 opt-in SAFETY）；门面 Tier-1/2 兼容面（冻结不收缩）。

---

## Findings

| ID | 维度 | 摘要 | 现状证据 | 风险 | 优先级 |
|----|------|------|----------|------|--------|
| R1 | 诊断可用性 | `TMemStats.HeapSafetyEnabled` 已有，但 `FormatMemStats` **不打印** `heap_safety=` | `default.pas` FormatMemStats 行无 safety | MEDIUM | **P1** |
| R2 | 诊断可用性 | `IsMemArenaStrictEnabled` 存在，**未进** `TMemStats` / FormatMemStats | 无 ArenaStrict 字段 | MEDIUM | **P1** |
| R3 | API 一致性 | 有 `FreeMemOf`/`TryFreeMemOf`，**无** `ReallocMemOf`/`TryReallocMemOf` | 门面仅 sized free 助手 | MEDIUM | **P1** |
| R4 | API 可发现性 | 四枚 env（DEBUG / HEAP_DEBUG / SAFETY / ARENA_STRICT）无**单行 profile**字符串 | doctor/日志需拼多个 Is* | LOW–MED | **P2** |
| R5 | 契约/门禁 | guardrails / `check_usability_docs` **未锁** R1–R4 | 源契约可回归 | LOW | **P0**（与实现同批） |

### 分维评分（审查时 / 1–10）

| 维度 | 分 | 依据 |
|------|----|------|
| 接口设计 | 9.0 | 双轨清晰；门面宽但 FACADES 冻结；缺 sized realloc 助手 |
| API 易用性 | 8.8 | FreeMemOf/Try* 好；env 面需多开关；stats 一行不全 |
| 调用一致性 | 8.7 | 过程式 sized free/realloc 对称；插件面 free/realloc 不对称 |
| 错误提示质量 | 9.0 | FormatAllocErrorMsg + ERROR-POLICY；历史异常类未全迁（已知） |
| 边界条件 | 9.2 | contract_matrix + nil/0/OOM；Arena strict dual-mode |
| 测试覆盖 | 9.0 | guardrails 18 用例；R1–R4 未覆盖 |
| 性能与内存安全 | 9.3 | 默认零税；SAFETY/DEBUG opt-in；热路径 UB 文档化 |
| **加权综合** | **8.9** | — |

### 已关闭（F1–F7，基线）

见 [USABILITY-SCORE.md](USABILITY-SCORE.md) F1–F7 表；本轮不重复开单。

---

## Risk

| 风险 | 等级 | 说明 | 缓解 |
|------|------|------|------|
| 误读 SAFETY 是否生效 | MED | FormatMemStats 无 `heap_safety`，运维以为未开 | R1 |
| Arena strict 静默 | MED | 设了 env 但 stats 不可见 | R2 |
| 插件路径 sized realloc 丢 size | MED | 只能 unsized `IAllocator.ReallocMem` 或绕过 tracking | R3 |
| 多 env 配方错误 | LOW–MED | 假阴性 + 税组合 | R4 + 既有 coverage_gap |
| 门禁漂移 | LOW | 无 source lock 则文档/格式回退 | R5 |
| 默认双 free UB | MED（接受） | 设计选择；非本轮“必改默认” | HEAP_SAFETY 文档 + CI recipe |

---

## Priority

实施顺序（依赖优先）：

1. **P0/P1 R1+R2+R5 stats** — 扩展 TMemStats + FormatMemStats + 文档/契约
2. **P1 R3** — ReallocMemOf 与 FreeMemOf 同门控（wrap 关才 sized 短路）
3. **P2 R4** — `FormatMemDebugProfile`（或等价并入 FormatMemStats 后仍保留薄封装）
4. 重评 USABILITY-SCORE → **9.3** 目标

禁止：默认开 SAFETY；合并双轨；大改异常继承树。

---

## Next Steps

1. 专题调研：[USABILITY-FINDINGS-RESEARCH.md](USABILITY-FINDINGS-RESEARCH.md) § R1–R5（根因 + Go/Rust）
2. 实施规划：[USABILITY-FIX-PLAN.md](USABILITY-FIX-PLAN.md) 里程碑 M8–M11
3. 批量实现 + guardrails/contract/debug_wrap + hygiene
4. 更新权威 [USABILITY-SCORE.md](USABILITY-SCORE.md)

---

## Rust / Go 对标（摘要）

| 主题 | Go | Rust | nextPas 现状 | 差距 → 路径 |
|------|----|------|--------------|-------------|
| 进程 stats 可读性 | `ReadMemStats` 字段齐全 | allocator stats crate 不一 | FormatMemStats 缺 safety/strict | R1/R2 |
| free/realloc 对称 | 用户不 free | `dealloc`/`realloc` 均带 Layout | 过程式对称；插件 free 有助手、realloc 无 | R3 |
| debug 配方 | `GODEBUG` 集中 | RUST_BACKTRACE / sanitizer 独立 | 4 env 分散 | R4 单行 profile |
| 默认安全税 | GC 掩盖 use-after-free | 默认安全，unsafe 显式 | 零税 + opt-in | 保持；不默认开税 |
