# nextpas.core.mem 高标准可用性评估（本轮权威）

**日期**: 2026-07-17
**模式**: 只读审查 → 调研/计划 → 统一实施（本文件跟踪全周期）
**范围**: 默认双轨产品路径（DefaultHeap / DefaultAllocator）、过程式 API、插件助手、诊断 env、错误模型、门面、focused gates
**对标**: Go `runtime` + `GODEBUG` / `ReadMemStats`；Rust `GlobalAlloc`/`Layout` + debug/sanitizer 工程习惯
**前序基线**: F1–F7 / R1–R5 / S1–S3 / T1–T4 **fixed**；落地后残留 **U1 fixed**；主线 **CLOSED**

---

## Summary

| 项 | 值 |
|----|-----|
| **综合分（T 轮审查时）** | **9.05 / 10** |
| **综合分（T1–T4 后）** | **9.35 / 10** |
| **综合分（U1 后，权威）** | **9.4 / 10**（见 [USABILITY-SCORE.md](USABILITY-SCORE.md)） |
| **等级** | **HIGH** |
| **风险总评** | **LOW–MEDIUM** |
| **基线** | F/R/S/T **closed** |
| **落地后残留** | **U1** — **fixed** |
| **主线状态** | **CLOSED**（无未关闭 P0/P1） |

**一句话**: 默认双轨可用性已高标收口；U1 补齐 `TryFreeMemOf(nil, owned)` 与 process free / HEAP_DEBUG 对称，foreign 仍 fail-closed。

故意不降分：默认双 free=UB（opt-in SAFETY）；双轨不合并；门面 Tier-2 冻结；全库 pool 历史 raise 大扫除；`FreeMemOf(nil, foreign)` 过程式 UB 面保持文档化。

---

## Findings

### 落地后 U1

| ID | 维度 | 摘要 | 证据 | 风险 | 优先级 |
|----|------|------|------|------|--------|
| U1 | 调用一致性 | `TryFreeMemOf(nil, …)` 在 sized 门关闭时 False 且不释放；owned 在 HEAP_DEBUG 下漏 free | `mem.pas` TryFreeMemOf | MED | **P1** |

### 已关闭基线（不 reopen）

F1–F7、R1–R5、S1–S3、T1–T4 — 见 [USABILITY-SCORE.md](USABILITY-SCORE.md)。

### 分维评分（权威）

| 维度 | 分 | 依据 |
|------|-----|------|
| 接口设计 | 9.2 | 双轨清晰；门面冻结 |
| API 易用性 | 9.3 | T3 nil→ResolveAllocator |
| 调用一致性 | 9.5 | S1 + U1 Try 对称 |
| 错误提示质量 | 9.2 | FormatAllocErrorMsg 路径 |
| 边界条件 | 9.3 | T2/T3；U1 foreign fail-closed |
| 测试覆盖 | 9.5 | guardrails 含 U1 |
| 性能与内存安全 | 9.3 | 默认零税不变 |
| **加权综合** | **9.4** | — |

---

## Risk

| 风险 | 等级 | 说明 | 缓解 |
|------|------|------|------|
| TryFreeMemOf nil 漏 free | MED | HEAP_DEBUG 下 sized 门关 | U1 |
| FreeMemOf(nil, foreign) UB | MED（接受） | 与过程式 FreeMem 同面 | 文档；Try fail-closed |
| 默认双 free UB | MED（接受） | 热路径零税 | HEAP_SAFETY opt-in |

---

## Priority

1. **P1 U1** TryFreeMemOf nil+owned
2. 复评 SCORE → **9.4**，主线 **CLOSED**

禁止：默认开 SAFETY；合并双轨；全库 pool raise 扫改；以 keepers 为可用性阻塞。

---

## Next Steps

1. ~~实现 U1 + guardrails~~ **done**
2. path-limited landing → main
3. **停止** mem 可用性满分迭代；新 slice 需产品压力

---

## Rust / Go 对标

| 主题 | Go | Rust | nextPas | 状态 |
|------|----|------|---------|------|
| free 有效指针 | 必须生效 | 正确 allocator | TryFreeMemOf owned 必 free | U1 |
| 错误指针 | panic | 逻辑错误 | Try fail-closed / FreeMemOf UB 文档 | 接受 |
| 溢出 / 非法 size | 分型 | Layout | aeInvalidLayout | T2 |
| nil 分配器 | N/A | 类型系统 | ResolveAllocator | T3 |
| 默认安全税 | GC | 所有权 | 零税 + opt-in | 保持 |
