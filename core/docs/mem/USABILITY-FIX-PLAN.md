# mem 可用性实施规划（含 U1 收口）

**状态**: F1–F7 / R / S / T / **U1 implemented** — 默认双轨可用性主线 **CLOSED**
**前置**: [USABILITY-EVAL-2026-07-17.md](USABILITY-EVAL-2026-07-17.md) · [USABILITY-FINDINGS-RESEARCH.md](USABILITY-FINDINGS-RESEARCH.md)
**日期**: 2026-07-17

### 实施检查清单

- [x] M0–M15 F1–F7 / R1–R5 / S1–S3
- [x] M16 T2 AllocArray overflow → EAllocError + FormatAllocErrorMsg
- [x] M17 T3 AllocZeroed/AllocArray ResolveAllocator
- [x] M18 T1 Arena Realloc FormatAllocErrorMsg
- [x] M19 T4 guardrails + SCORE 9.35
- [x] M20 U1 TryFreeMemOf nil+owned free
- [x] M21 U1 guardrails + SCORE 9.4 + 主线 CLOSED

---

## 1. 里程碑（本轮 U1）

| M | 名称 | 交付 | 依赖 | 优先级 |
|---|------|------|------|--------|
| **M20** | TryFreeMemOf 对称 | U1 | 无 | **P1** |
| **M21** | 门禁与收口 | guardrails + docs + CLOSED | M20 | **P0** |

### 依赖图

```text
M20 ──► M21 guardrails + score CLOSED
```

---

## 2. 实现要点（冻结）

1. `TryFreeMemOf`：sized 快路径不变；非 nil 插件 `FreeMem`；nil 时仅 `TryBlockSize` 自有 → process `FreeMem`；foreign → False。
2. 不改变 `FreeMemOf(nil, foreign)` 过程式回落（UB 面文档已知）。
3. 不默认开 SAFETY/DEBUG；不合并双轨。

---

## 3. 验证

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
make hygiene
```

| 发现 | 验收 |
|------|------|
| U1 | TryFreeMemOf(nil, owned) True 且 free；foreign False；HEAP_DEBUG 下仍 free |

---

## 4. 非目标

双轨合并、默认安全税、全库 pool raise 扫改、HIR Operands / package DTO 整树、EOutOfMemory 继承树改造。

---

## 5. 主线 CLOSED 后

无新 P0/P1 不得在 mem lane 上为「可用性满分」再开 slice。独立 lane：package DTO→TVec；Scorecard host 扩展。
