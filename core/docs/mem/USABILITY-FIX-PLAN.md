# mem 可用性实施规划（含 T1–T4）

**状态**: T1–T4 implemented
**前置**: [USABILITY-EVAL-2026-07-17.md](USABILITY-EVAL-2026-07-17.md) · [USABILITY-FINDINGS-RESEARCH.md](USABILITY-FINDINGS-RESEARCH.md)
**日期**: 2026-07-17

### 实施检查清单

- [x] M0–M15 F1–F7 / R1–R5 / S1–S3
- [x] M16 T2 AllocArray overflow → EAllocError + FormatAllocErrorMsg
- [x] M17 T3 AllocZeroed/AllocArray ResolveAllocator
- [x] M18 T1 Arena Realloc FormatAllocErrorMsg
- [x] M19 T4 guardrails + SCORE 9.35 + `{SCRATCH}` logs

---

## 1. 里程碑（本轮）

| M | 名称 | 交付 | 依赖 | 优先级 |
|---|------|------|------|--------|
| **M16** | AllocArray 错误 | T2 | 无 | **P1** |
| **M17** | nil allocator | T3 ResolveAllocator | 无 | **P1** |
| **M18** | Arena Realloc 消息 | T1 | 无 | **P2** |
| **M19** | 门禁与复评 | T4 + docs + scratch | M16–M18 | **P0** |

### 依赖图

```text
M16 / M17 / M18 ──► M19 guardrails + score
```

---

## 2. 实现要点（冻结）

1. AllocArray 溢出：**EAllocError** + **aeInvalidLayout** + FormatAllocErrorMsg（非 EOutOfMemory）。
2. AllocZeroed / AllocArray：`ResolveAllocator(AAllocator).AllocMem(...)`。
3. Arena Realloc：FormatAllocErrorMsg；不改 Traits/no-op Free 默认。
4. 不默认开 SAFETY/DEBUG；不合并双轨。

---

## 3. 验证

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
make focused FOCUS=core/tests/nextpas.core.mem/test_mem
make hygiene
# logs → {SCRATCH}/
```

| 发现 | 验收 |
|------|------|
| T2 | 溢出 raise EAllocError aeInvalidLayout；IsWellFormedAllocErrorMsg stem |
| T3 | AllocZeroed(nil,n)/AllocArray(nil,…) 成功并可 FreeMemOf |
| T1 | 源含 FormatAllocErrorMsg(...ReallocMem...) |
| T4 | guardrails + check_usability_docs |

---

## 4. 非目标

双轨合并、默认安全税、全库 pool raise 扫改、EOutOfMemory 继承树改造。
