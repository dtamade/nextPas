# mem 可用性实施规划（F1–F7 + R1–R5）

**状态**: R1–R5 implemented
**前置**: [USABILITY-EVAL-2026-07-17.md](USABILITY-EVAL-2026-07-17.md) · [USABILITY-FINDINGS-RESEARCH.md](USABILITY-FINDINGS-RESEARCH.md)
**日期**: 2026-07-17
**确认门**: 评估 + 调研 + 本计划落盘后 **统一实施**（禁止边调边改设计）

### 实施检查清单

- [x] M0–M7 F1–F7（已落地）
- [x] M8 R1+R2 FormatMemStats / TMemStats（heap_safety + arena_strict）
- [x] M9 R3 ReallocMemOf / TryReallocMemOf
- [x] M10 R4 FormatMemDebugProfile
- [x] M11 R5 guardrails + check_usability_docs + score 9.3 + scratch logs

---

## 1. 里程碑（本轮）

| M | 名称 | 交付 | 依赖 | 优先级 |
|---|------|------|------|--------|
| **M8** | Stats 完整 | R1/R2：`ArenaStrictEnabled`；FormatMemStats `heap_safety=` `arena_strict=` | 无 | **P1** |
| **M9** | Sized realloc | R3：`ReallocMemOf` / `TryReallocMemOf` + FreeMemOf 同门控 | M8 无强依赖 | **P1** |
| **M10** | Profile 一行 | R4：`FormatMemDebugProfile` 门面 | M8 | **P2** |
| **M11** | 门禁与复评 | R5：tests + docs + USABILITY-SCORE **9.3** + `{SCRATCH}` | M8–M10 | **P0** |

### 依赖图

```text
M8 (stats fields) ──┬──► M10 FormatMemDebugProfile
                    └──► M11 docs/asserts
M9 ReallocMemOf ─────────► M11 guardrails
```

---

## 2. 实现要点（冻结设计）

1. **不**默认开 HEAP_SAFETY / ARENA_STRICT / DEBUG。
2. ReallocMemOf 门控：`FreeMemOfAllowsSizedHeapFree`（或重命名共享 helper `PluginSizedHeapFastPath`）。
3. sized 成功：`DefaultHeap.ReallocMem(ptr, classSize, newSize)`；否则 `AAllocator.ReallocMem(ptr, newSize)`。
4. FormatMemStats 追加字段位置固定在 `heap_debug=` 附近，保持单行。
5. FormatMemDebugProfile 仅诊断字符串，热路径不调用。

---

## 3. 验证（M11）

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
make focused FOCUS=core/tests/nextpas.core.mem/test_debug_wrap
make hygiene
# logs → {SCRATCH}/
```

| 发现 | 验收 |
|------|------|
| R1 | FormatMemStats 含 `heap_safety=`；SAFETY 开 → `y` |
| R2 | 含 `arena_strict=`；env 开 → `y` |
| R3 | ReallocMemOf 同堆 sized；DEBUG wrap 下 tracking 不 stale |
| R4 | FormatMemDebugProfile 含全部开关键 |
| R5 | check_usability_docs + guardrails 锁上述 |

---

## 4. 回滚

关 env；移除助手调用；FormatMemStats 字段追加可兼容忽略。

## 5. 非目标

双轨合并、默认安全税、EOutOfMemory 继承树大迁移、门面大规模删 Tier-2。
