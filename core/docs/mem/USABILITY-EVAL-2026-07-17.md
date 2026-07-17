# nextpas.core.mem 高标准可用性评估（本轮权威）

**日期**: 2026-07-17
**模式**: 只读审查 → 调研/计划 → 统一实施（本文件跟踪全周期）
**范围**: 默认双轨产品路径（DefaultHeap / DefaultAllocator）、过程式 API、插件助手、诊断 env、错误模型、门面、focused gates
**对标**: Go `runtime` + `GODEBUG` / `ReadMemStats`；Rust `GlobalAlloc`/`Layout` + debug/sanitizer 工程习惯
**前序基线**: F1–F7 / R1–R5 / S1–S3 **fixed**；本轮查新残留，不 reopen dual-track 热路径

---

## Summary

| 项 | 值 |
|----|-----|
| **综合分（本轮审查时）** | **9.05 / 10** |
| **综合分（T1–T4 修复后）** | **9.35 / 10**（见 [USABILITY-SCORE.md](USABILITY-SCORE.md)） |
| **等级** | **HIGH** |
| **风险总评** | **LOW–MEDIUM** |
| **F1–F7 / R1–R5 / S1–S3** | 基线 closed |
| **本轮新发现** | **T1–T4** — 实施后 **全部 fixed** |

**一句话**: 双轨零税与诊断/助手已高标；本轮必修是 **AllocArray 溢出错误类型/消息**、**AllocZeroed/AllocArray 对 nil allocator 崩溃**、**Arena Realloc 未走 FormatAllocErrorMsg**。

故意不降分：默认双 free=UB（opt-in SAFETY）；双轨不合并；门面 Tier-2 冻结；全库 pool 历史 raise 大扫除；TryFreeMemOf 对 nil+foreign 比 FreeMemOf 更严（安全偏向）。

---

## Findings

### 本轮 T1–T4

| ID | 维度 | 摘要 | 证据 | 风险 | 优先级 |
|----|------|------|------|------|--------|
| T1 | 错误提示 | Arena `ReallocMem` raise 裸字符串；同单元 FreeMem 已用 FormatAllocErrorMsg | `allocator.arena.pas` | LOW–MED | **P2** |
| T2 | 错误模型 | `AllocArray` 乘法溢出抛 `EOutOfMemory` + 非 Type.Method 消息；ERROR-POLICY 归编程错误 | `mem.pas` AllocArray | **MED** | **P1** |
| T3 | API 易用/边界 | `AllocZeroed`/`AllocArray` 对 nil `IAllocator` 直接虚调用崩溃；与 `ResolveAllocator`/S5 不一致 | `mem.pas` | **MED** | **P1** |
| T4 | 门禁 | T1–T3 无 guardrails 锁 | tests | LOW | **P0**（同批） |

### 已关闭基线（不 reopen）

F1–F7、R1–R5、S1–S3 — 见 [USABILITY-SCORE.md](USABILITY-SCORE.md)。

### 分维评分（审查时 → 修复后）

| 维度 | 审查 | 修复后 | 依据 |
|------|------|--------|------|
| 接口设计 | 9.2 | 9.2 | 双轨清晰；门面冻结 |
| API 易用性 | 8.9 | 9.3 | T3 nil→ResolveAllocator |
| 调用一致性 | 9.2 | 9.3 | S1 已关；助手一致 |
| 错误提示质量 | 8.7 | 9.2 | T1/T2 FormatAllocErrorMsg + 正确码 |
| 边界条件 | 8.9 | 9.3 | T3 nil；T2 溢出类型 |
| 测试覆盖 | 9.2 | 9.5 | T4 guardrails |
| 性能与内存安全 | 9.3 | 9.3 | 默认零税不变 |
| **加权综合** | **9.05** | **9.35** | — |

---

## Risk

| 风险 | 等级 | 说明 | 缓解 |
|------|------|------|------|
| AllocArray 溢出被当成 OOM | MED | except on EAllocError 漏捕；误判资源不足 | T2 |
| nil IAllocator 崩溃 | MED | 插件注入路径传 nil 即 AV | T3 ResolveAllocator |
| Arena Realloc 消息不可机读 stem | LOW | 与 FreeMem 助手不一致 | T1 |
| 默认双 free UB | MED（接受） | 热路径零税 | HEAP_SAFETY opt-in |
| 门禁漂移 | LOW | | T4 |

---

## Priority

1. **P0 T4** 与实现同批
2. **P1 T2 + T3** AllocArray / AllocZeroed
3. **P2 T1** Arena Realloc 消息
4. 复评 SCORE → **9.35**

禁止：默认开 SAFETY；合并双轨；全库 pool raise 扫改。

---

## Next Steps

1. 调研：[USABILITY-FINDINGS-RESEARCH.md](USABILITY-FINDINGS-RESEARCH.md) § T1–T4
2. 计划：[USABILITY-FIX-PLAN.md](USABILITY-FIX-PLAN.md) M16–M19
3. 批量实现 + guardrails + `{SCRATCH}` 日志
4. 更新 [USABILITY-SCORE.md](USABILITY-SCORE.md)

---

## Rust / Go 对标

| 主题 | Go | Rust | nextPas 审查时 | 路径 |
|------|----|------|----------------|------|
| 溢出 / 非法 size | 明确 error | `Layout`/`try_reserve` 错误类型清晰 | AllocArray→EOutOfMemory 混淆 | T2 |
| nil 分配器 | 无用户 free 面 | 类型系统阻止空 Global | nil IAllocator 崩溃 | T3 |
| 错误消息格式 | 包前缀惯例 | thiserror Display | 助手部分路径 | T1 |
| 默认安全税 | GC | 所有权 | 零税 + opt-in | 保持 |
| free/realloc size | N/A | Layout | *Of 助手 | 已对齐 |
