# math-simd Goal Queue

> Last updated: 2026-07-17
> Lane: `math-simd` worktree
> Purpose: **single CURRENT pointer** so agents run end-to-end cards without human “继续”.

## How to execute (agent contract)

1. Read **only** `CURRENT` card + linked roadmap/GOAL_TREE sections it cites.
2. Implement within **IN_SCOPE_PATHS**; anything outside → **STOP** (Blocked).
3. Run **GATES** exactly; on failure fix or Blocked (do not skip).
4. Update docs required by **DoD**; one logical **commit** (message = card intent).
5. Set `CURRENT` to card **NEXT** (same commit or tiny follow-up commit).
6. **Do not** wait for the user to say 继续. One session = one card closed or Blocked.
7. On **STOP / BLOCKED_UNTIL**: report Blocked and exit; do not open the next card.

### Card template (copy for new goals)

```text
GOAL_ID:
STATUS: pending | in_progress | done | blocked
NEXT:
WHY:
IN_SCOPE_PATHS:
OUT_OF_SCOPE:
DELIVERABLES:
GATES:
DoD:
STOP:
BLOCKED_UNTIL: (optional)
```

---

## CURRENT

```text
CURRENT=Q1
```

---

## Wave 0 — Goal OS

### G0 — Queue + pointers  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (this file + plan/GOAL_TREE/roadmap pointers) |
| **NEXT** | S23a |
| **WHY** | Explicit queue so execution does not depend on chat “继续” |
| **DELIVERABLES** | `GOAL_QUEUE.md`; `core/docs/simd/plan.md` points here; `core/docs/math/GOAL_TREE.md` residual + pointer; roadmap “默认下一刀” → CURRENT |
| **GATES** | `git diff --check`; docs-only hygiene if needed |
| **DoD** | CURRENT points at first code card; agent contract above is present |

---

## Wave 1 — simd kernel (main)

### S23a — NEON BatchF32 ArrayAdd/Sub/Mul  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done |
| **NEXT** | S23b |
| **WHY** | Close the largest NEON “all Batch inherits scalar” gap with high-ROI leaves |
| **IN_SCOPE_PATHS** | `core/src/nextpas.core.simd.neon.pas`; `core/src/nextpas.core.simd.neon.register.inc`; `core/src/nextpas.core.simd.neon.facade.asm.inc` and/or new `neon.batch*.inc`; `core/src/nextpas.core.simd.neon.facade.scalar.inc` / scalar batch fallback include; `core/tests/nextpas.core.simd/nextpas.core.simd.dispatchapi.testcase.pas`; `core/docs/simd/{roadmap,plan,README}.md`; this file |
| **OUT_OF_SCOPE** | BatchF64 / BatchInteger leaves; full BatchF32 table; RVV; math production code; public ABI renames; raw-merge main; dead `NEONX := ScalarX` registered wrappers |
| **DELIVERABLES** | Symbols `NEONArrayAddF32` / `NEONArraySubF32` / `NEONArrayMulF32`: AArch64 asm (`assembler; nostackframe`, ICE-safe loads) under `NEXTPAS_SIMD_NEON_ASM_ENABLED`; scalar fallbacks when asm off; register bind **only** under ASM_ENABLED; contracts: PlatformFacadeSlots no longer forbids all BatchF32 overrides—assert remaining Batch* still scalar; FacadeFastSlots (or equivalent) requires asm/register/runtime expectations for the three; docs: BatchF32 ownership progress |
| **GATES** | `make focused FOCUS=core/tests/nextpas.core.simd`; `make -C core/tests/nextpas.core.simd neon-optin-focused`; `make hygiene`; `git diff --check` |
| **DoD** | Gates green; three slots source+runtime contract; CURRENT→S23b; one feat commit |
| **STOP** | Need public ABI break; want whole Batch table; must touch math; ICE/compiler blocks asm and no safe fallback path |

**Symbol list (fixed):**

1. `NEONArrayAddF32(aSrc1, aSrc2, aDst: PSingle; aCount: SizeUInt)`
2. `NEONArraySubF32(...)`
3. `NEONArrayMulF32(...)`

**Pattern:** same ownership as Phase 22 Memory — real asm leaf + non-asm scalar symbol + register only when ASM enabled. Names match `static.inc` (`NEONArray*F32`).

### S23b — NEON BatchF32 Min/Max/Abs/Neg (+ optional Div)  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (Min/Max/Abs/Neg; Div deferred) |
| **NEXT** | M-C1 |
| **WHY** | Second high-frequency BatchF32 band without filling F64/Integer |
| **IN_SCOPE_PATHS** | Same neon/batch/test/docs set as S23a |
| **OUT_OF_SCOPE** | BatchF64/Integer full tables; transcendence ArraySin/Exp; math API |
| **DELIVERABLES** | At least `NEONArrayMinF32` / `Max` / `Abs` / `Neg`; optional `Div`; register+contracts+docs |
| **GATES** | Same as S23a |
| **DoD** | Gates green; CURRENT→M-C1; commit |
| **STOP** | Scope creep into full table |

### S23c — Optional BatchF32 Fma/Axpy or reduce sample  【optional】

| Field | Content |
|-------|---------|
| **STATUS** | pending (skip if S23b already enough for lane goals) |
| **NEXT** | M-C1 (if not done) or S24a |
| **WHY** | Only if profile/consumer pressure; not required for “lane complete” |
| **OUT_OF_SCOPE** | Whole table |
| **DELIVERABLES** | 1–3 extra leaves max |
| **GATES** | Same focused set |
| **DoD** | Or mark skipped in CURRENT notes |

### S24a — RVV Memory/Batch honesty  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | S25a |
| **WHY** | No silent “native” claims without leaves |
| **IN_SCOPE_PATHS** | RVV register/docs/tests source-contracts; roadmap |
| **OUT_OF_SCOPE** | Fake RVV wrappers; claiming Phase-3 hardware without evidence |
| **DELIVERABLES** | Document+contract: Memory/Batch intentionally scalar unless real leaf |
| **GATES** | focused (or RVV opt-in smoke if exists); hygiene; diff-check |
| **DoD** | Honesty matrix green; CURRENT advanced |
| **BLOCKED_UNTIL** | — (software-only) |
| **EVIDENCE** | `Test_RISCVV_MemoryBatch_Intentionally_Scalar_Until_RealLeaf` locks no `table.Memory.` / `table.Batch*` register overrides, no `Mem*_RISCVV` / `RISCVVArray*` dead wrappers, runtime Memory 15 + Batch representative slots == scalar; register.inc honesty comment; roadmap matrix updated |

### S24b — RVV real leaves  【blocked】

| Field | Content |
|-------|---------|
| **STATUS** | blocked |
| **BLOCKED_UNTIL** | RISC-V hardware or approved QEMU evidence path |
| **NEXT** | S25a |
| **WHY** | Optional 1–N Memory/Batch leaves with real evidence |

### S25a — Benchmark methodology + remeasure hotspots  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | S25b |
| **WHY** | High-performance requires reproducible SIMD vs true-scalar |
| **IN_SCOPE_PATHS** | `core/benchmarks/nextpas.core.simd/**`; simd docs § performance; related test benches |
| **OUT_OF_SCOPE** | Changing public API to chase scores |
| **DELIVERABLES** | Method note (anti FPC auto-vectorization); remeasure ArrayMulF32 etc.; record host/flags |
| **GATES** | Documented command runs; hygiene |
| **DoD** | Numbers in roadmap/README with method; CURRENT→S25b |
| **EVIDENCE** | `bench_hotspots` + `performance-methodology.md`; vsTrue AddF32 4.51x / AddF64 6.36x / MulF32 4.12x / MemEqual 43.98x @ AVX2 Xeon E5-2696 v4 |

### S25b — Optimize or revise targets  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) — **re-baseline**, no leaf opt |
| **NEXT** | M-V1 |
| **WHY** | Close or honestly re-baseline underperforming targets under **vsTrue** primary metric |
| **IN_SCOPE_PATHS** | Hot leaf impls + docs；可引用 `performance-methodology.md` |
| **OUT_OF_SCOPE** | Silent target deletion without reason；把 vsLib 当主指标 |
| **DELIVERABLES** | Revised vsTrue SLA + rationale（Mul 4x 达标保留；AddF32 正式 4x+ / stretch 6x+） |
| **GATES** | focused + hygiene（无叶改动 → 不强制 bench_hotspots 重跑） |
| **DoD** | CURRENT→M-V1 |
| **EVIDENCE** | roadmap §5 SLA 表；performance-methodology §6；四热点 vsTrue 相对正式 SLA 全绿 |

---

## Wave 2 — math residual (secondary)

### M-C1 — math consumer smoke after NEON Batch  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | S24a |
| **WHY** | math must keep working when simd Batch leaves appear (public-only) |
| **IN_SCOPE_PATHS** | `core/tests/nextpas.core.math/**` (run); math docs only if needed |
| **OUT_OF_SCOPE** | math production rewrites; private simd imports |
| **DELIVERABLES** | `make -C core/tests/nextpas.core.math clean test` green evidence; note in GOAL_TREE |
| **GATES** | math clean test; hygiene if any file touch |
| **DoD** | Evidence recorded; CURRENT advanced |
| **STOP** | Failures requiring private simd coupling |
| **EVIDENCE** | `make -C core/tests/nextpas.core.math clean test` → exit 0; `MATH_API_SURFACE OK: scanned=70 findings=0`; 16 Pascal suites / 305 tests, 0 failed; heaptrc 0 unfreed on all suites |

### M-V1 — vec.batch Double minimal parity  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | M-V2 |
| **WHY** | Complete advanced public batch symmetry (F32-first gap) |
| **IN_SCOPE_PATHS** | `core/src/nextpas.core.math.vec.batch*`; root facade; tests `test_vec_batch*`; `core/docs/math/API.md` |
| **OUT_OF_SCOPE** | Value-type SIMD methods; M9; private simd |
| **DELIVERABLES** | Minimal Double set mirroring F32 vec.batch core ops |
| **GATES** | `make -C core/tests/nextpas.core.math clean test`; api-surface if API grows; hygiene |
| **DoD** | Tests+API.md; CURRENT→M-V2 |
| **EVIDENCE** | Double overloads: BatchDot(2d/3d/4d), Normalize(2d/3d/4d + 3d src-dst), Transform(Mat3d×2d, Mat4d×3d MultPoint), Lerp/Clamp TVec3d; value-type loops; facade re-export; test_vec_batch +6 Double cases |

### M-V2 — math residual docs + lane mode  【done】

| Field | Content |
|-------|---------|
| **STATUS** | done (2026-07-17) |
| **NEXT** | Q1 |
| **WHY** | Clean backlog: in-lane vs deferred vs out-of-lane |
| **IN_SCOPE_PATHS** | `core/docs/math/**` (+ pointer docs as needed) |
| **OUT_OF_SCOPE** | Code changes unless docs demand |
| **DELIVERABLES** | GOAL_TREE residual sections; macOS/M9 blocked; lane complete checklist |
| **GATES** | diff-check |
| **DoD** | CURRENT→Q1 |
| **EVIDENCE** | GOAL_TREE: residual closed; backlog classified; math lane-complete checklist; macOS/M9 blocked table |

### M9 — fafafa.game cutover  【blocked】

| Field | Content |
|-------|---------|
| **STATUS** | blocked |
| **BLOCKED_UNTIL** | Product authorization + cross-lane plan |
| **OUT_OF_SCOPE** | Entire math-simd default queue |

### macOS trig host proof  【blocked】

| Field | Content |
|-------|---------|
| **STATUS** | blocked |
| **BLOCKED_UNTIL** | macOS runner / CI host |

---

## Wave 3 — quality / elegance

### Q1 — Pointer freshness  【CURRENT】

| Field | Content |
|-------|---------|
| **STATUS** | pending |
| **NEXT** | Q2 |
| **WHY** | CURRENT, README, roadmap §1 must not drift |
| **IN_SCOPE_PATHS** | simd/math docs |
| **DELIVERABLES** | Align phase headers, verification counts, CURRENT |
| **GATES** | diff-check |
| **DoD** | CURRENT→Q2 or IDLE |

### Q2 — math↔simd linkage table

| Field | Content |
|-------|---------|
| **STATUS** | pending |
| **NEXT** | IDLE (or S26 blocked note) |
| **WHY** | Prevent wrong-module edits in future goals |
| **DELIVERABLES** | Short table in this file or both READMEs |

### IDLE

When CURRENT=`IDLE`: lane has no in-lane code goal. Agent only re-verifies gates or stops.

---

## Wave 4 — external walls (never auto-start)

| ID | Item | BLOCKED_UNTIL |
|----|------|----------------|
| S26 | Compiler built-in SIMD | compiler lane |
| S27 | LASX/WASM/VSX/MSA | FPC/toolchain + validation |
| S24b | RVV hardware leaves | hardware/QEMU policy |
| M9 | fafafa.game | product auth |

---

## Lane-complete definition (this worktree)

### simd lane-complete

- [x] Nested dispatch + honest ownership discipline
- [x] NEON Memory 15/15 + SharedMask
- [x] NEON BatchF32 high-frequency representative set (S23a/S23b; Div deferred)
- [x] RVV honesty (S24a)
- [x] Perf method + hotspot remeasure (S25a)
- [x] Hotspot close-or-revise (S25b re-baseline)
- [ ] Docs CURRENT coherent (Q1)

### math lane-complete

- [x] M0–M8 available-host gates
- [x] Public batch F32/F64 via public simd
- [x] vec.batch Double minimal parity (M-V1)
- [x] Residual backlog clean (M-V2)
- [x] Consumer smoke after Batch leaves (M-C1)
- [x] M9/macOS explicitly blocked (not silent)

### Non-goals (always)

- Dead scalar wrappers registered as “native”
- math importing private simd backend units
- Value-type methods → SIMD without profile + design review
- raw-merge long-lived lane to main
- Claiming blocked hardware/compiler work done

---

## Default order (happy path)

```text
G0 ✅ → S23a ✅ → S23b ✅ → M-C1 ✅ → S24a ✅ → S25a ✅ → S25b ✅ → M-V1 ✅ → M-V2 ✅ → Q1 → Q2 → IDLE
         (S23c optional)                       (S24b only if hardware)
```

## Agent session prompt (paste)

```text
You are the math-simd lane executor on branch math-simd.
1. Open core/docs/math-simd/GOAL_QUEUE.md and execute only CURRENT.
2. Follow that card’s paths, gates, DoD, STOP.
3. Commit when DoD is met; advance CURRENT to NEXT.
4. Do not ask for 继续. One card per session unless CURRENT was G0 docs-only chaining into the same session by human request.
5. On STOP/BLOCKED: report Blocked with evidence and exit.
```
