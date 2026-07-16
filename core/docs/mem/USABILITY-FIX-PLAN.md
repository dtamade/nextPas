# mem 可用性 F1–F7 实施规划

**状态**: Implemented
**前置**: [USABILITY-FINDINGS-RESEARCH.md](USABILITY-FINDINGS-RESEARCH.md)
**日期**: 2026-07-16 / 实施 2026-07-17
**确认门**: 调研 + 本计划落盘后统一实施（OBJECTIVE：完整实施）

### 实施检查清单

- [x] M0 F7 纪律（空断言 / 评分 rubric）
- [x] M1 F5 FormatAllocErrorMsg
- [x] M2 F1 debug_process / debug_coverage_gap
- [x] M3 F3 HEAP_SAFETY
- [x] M4 F2 FreeMemOf
- [x] M5 F4 ARENA_STRICT
- [x] M6 F6 FACADES-SURFACE + source check
- [x] M7 focused gates + scratch logs + score finalize

### M7 验证证据（2026-07-17）

```text
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails  → 17 passed
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix       → 19 passed
make focused FOCUS=core/tests/nextpas.core.mem/test_debug_wrap            → (log)
make hygiene → pass
logs: /tmp/grok-goal-03b162e4031a/implementer/
```

---

## 1. 里程碑

| M | 名称 | 交付 | 依赖 | 优先级 |
|---|------|------|------|--------|
| **M0** | 纪律与基线 | F7：删空断言；USABILITY-SCORE 独立 rubric（先记基线 7.7） | 无 | **P0** |
| **M1** | 错误助手 | F5：`FormatAllocErrorMsg` / `IsWellFormedAllocErrorMsg` + contract | 无 | **P2**（先做因 F4 复用） |
| **M2** | 诊断可观测 | F1：`TMemStats` 覆盖缺口 + `FormatMemStats` 字段 + guardrails | M0 | **P1** |
| **M3** | Safety profile | F3：`NEXTPAS_MEM_HEAP_SAFETY` → process 路由 + 默认 tracking/sentinel | M2（共用 cache） | **P1** |
| **M4** | Sized free 助手 | F2：`FreeMemOf` / `TryFreeMemOf` + 过程式 sized 契约 | M0 | **P1** |
| **M5** | Arena strict | F4：`NEXTPAS_MEM_ARENA_STRICT` + 双模式测试 | M1 | **P2** |
| **M6** | 门面冻结 | F6：FACADES-SURFACE / README + source-contract | 无 | **P2** |
| **M7** | 复评与验证 | 更新 USABILITY-SCORE；focused gates；`{SCRATCH}` 日志 | M0–M6 | — |

---

## 2. 优先级与排序

```text
P0  M0 F7
P1  M2 F1 → M3 F3 → M4 F2   (可 M4 与 M2 并行，但 M3 依赖 debug_wrap)
P2  M1 F5 (建议在 M5 前) → M5 F4 → M6 F6
    M7 收口
```

实施批次（编码时一次合入，逻辑顺序如下）：

1. `mem.error` 助手（F5）
2. `mem.debug_wrap` safety/arena-strict env + HEAP_DEBUG 合成（F3/F4 env）
3. `mem.default` stats/format 覆盖缺口（F1）
4. `mem.pas` / `default` FreeMemOf（F2）
5. `allocator.arena` strict FreeMem（F4）
6. 文档：ERROR-POLICY、README、API-GUIDE、DEBUG-WRAP、FACADES-SURFACE、USABILITY-SCORE（F6/F7）
7. 测试：guardrails、contract_matrix 扩展 / 新小 gate

---

## 3. 依赖图

```text
M0 F7 ──────────────────────────────┐
M1 F5 ──► M5 F4                     │
M0 ──► M2 F1 ──► M3 F3              ├──► M7 verify
M0 ──► M4 F2                        │
M6 F6 ──────────────────────────────┘
```

---

## 4. 文件触点（预期）

| 区域 | 文件 |
|------|------|
| 错误 | `core/src/nextpas.core.mem.error.pas` |
| DEBUG | `core/src/nextpas.core.mem.debug_wrap.pas` |
| 默认堆/统计 | `core/src/nextpas.core.mem.default.pas` |
| 门面 | `core/src/nextpas.core.mem.pas` |
| Arena 适配 | `core/src/nextpas.core.mem.allocator.arena.pas` |
| 测试 | `test_usability_guardrails`, `test_contract_matrix`（及必要新用例） |
| 文档 | ERROR-POLICY, README, API-GUIDE, DEBUG-WRAP-DESIGN, USABILITY-SCORE, 本计划/调研, FACADES-SURFACE.md |
| 可选 | `scripts/stage0-heap-debug-env-recipe.sh`（若 FormatMemStats 字段被 recipe 断言） |

---

## 5. 验收映射（↔ plan acceptance）

| Finding | 验收信号 |
|---------|----------|
| F1 | `FormatMemStats` 含 `debug_process` 与缺口指示；DEBUG-only 时 gap 可测 |
| F2 | `FreeMemOf`/`TryFreeMemOf` 同堆 sized 路径测试通过 |
| F3 | `HEAP_SAFETY=1` 时过程式 GetMem 进入 tracking；默认关 |
| F4 | strict off = no-op；strict on + FreeMem(non-nil) raise |
| F5 | `FormatAllocErrorMsg` contract；ERROR-POLICY 更新 catch 面 |
| F6 | facade freeze 文档 + 禁止 Tier-3 uses 的 source check |
| F7 | 无 `Check(True,`；USABILITY-SCORE 无 `++++` 链 |

---

## 6. 验证命令

```bash
make focused FOCUS=core/tests/nextpas.core.mem/test_usability_guardrails
make focused FOCUS=core/tests/nextpas.core.mem/test_contract_matrix
make hygiene
# if recipe touched:
make rebuild-compiler   # if needed
make stage0-heap-debug-recipe
```

日志写入 goal scratch（implementer 目录）。
