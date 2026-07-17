# Atomic & Lockfree — Ready / Horizon-2 状态

> **Status**: **H2 complete**（base: R0–R7 + RC Ready；Horizon-2 H2-0…H2-6 landed）
> **Date**: 2026-07-17
> **Owner**: atomic-lockfree lane
> **Scope**: `nextpas.core.atomic` (L0) + `nextpas.core.lockfree` (L1)

Mainline stages **R0–R7 and RC Ready close-out are complete**.
**Horizon-2 (H2-0…H2-6) is complete** — see [`roadmap-h2.md`](roadmap-h2.md).
**Current execution line**: **Maintenance** (consumer bugs, contract amendments, opt-in R8 research only).
**R8** (NUMA / TSX / TLA+) remains **opt-in research** and is **not** a default production item.
Do **not** invent an R9; H2 was the numbered successor for consistency / evidence / consumer work.

Archive: `archive/atomic-lockfree-h2-complete-20260717` (H2-1…H2-6 land HEAD `d93780c27`);
close-out docs: `archive/atomic-lockfree-h2-closeout-20260717`.

---

## Module maturity

| Surface | Maturity | Notes |
|---------|----------|-------|
| **T1 runtime core** (lockfree facade) | **Ready-for-consumer** | Unmanaged elements; `Close → join → Free`; contract + tests aligned; H2-1 Deque `Try*Ex` parity landed |
| **atomic** | **Ready-for-consumer** | Canonical `atomic_*` / `TAtomic*`; legacy CAS documented, not preferred (H2-3) |
| **T2 concurrent containers** | **Available, not a unified production contract** | H2-2 maturity tiers documented; **not** default facade |
| **T3 / research** | Experimental | RTM / NUMA / formal models — direct import only |

Authoritative contract: [`CONTRACT.md`](CONTRACT.md). Product entry: [`README.md`](README.md).
R-line map: [`roadmap.md`](roadmap.md). **H2 charter (complete)**: [`roadmap-h2.md`](roadmap-h2.md).

---

## Horizon-2 progress — **COMPLETE**

| Stage | Name | Status | Evidence |
|-------|------|--------|----------|
| **H2-0** | Charter + status switch | **done** | `03086c0c3` · `archive/atomic-lockfree-h2-0-landed-20260717` |
| **H2-1** | Deque Try\*Ex (T1 parity) | **done** | `042145f1e` (landed on main) |
| **H2-2** | T2 maturity tiers (docs only) | **done** | Docs in H2-1 land surface (`CONTRACT` / `README` / `selection-guide`) |
| **H2-3** | atomic preferred path | **done** | `0b023f687` |
| **H2-4** | bench evidence envelope | **done** | `0e1b86268` |
| **H2-5** | formal / stress deepen | **done** | `bce90f2cb` |
| **H2-6** | real consumer in core | **done** | `d93780c27` · `archive/atomic-lockfree-h2-complete-20260717` |
| **H2 close-out** | READY/roadmap + archive tag | **done** | this document · `archive/atomic-lockfree-h2-closeout-20260717` |

Details, deliverables, non-goals, and acceptance: [`roadmap-h2.md`](roadmap-h2.md).

---

## Acceptance checklist (R0–R7) — baseline Done

All items below remain **done** and form the H2 / Maintenance baseline.

| # | Acceptance item | Status | Evidence |
|---|-----------------|--------|----------|
| 1 | **ClosedPublishPolicy** | Done | CONTRACT §1.3; SegQueue/MPSC/MSQueue/Channel close semantics landed with R1–R2 |
| 2 | **Managed element guards** | Done | T1 generics reject managed types; T2 guards + AnsiString exception table in CONTRACT §0 / §0.1 / §3.1 |
| 3 | **RTL isolation** | Done | Only `nextpas.core.system*` may use FPC RTL directly; atomic/lockfree production + primary tests use framework abstractions (R1–R2) |
| 4 | **Try\*Ex T1 coverage** | Done (rings/stack/channel/deque) | R3 pilot + R4 + H2-1 Deque; CONTRACT §1.4 |
| 5 | **Channel capacity=1** | Done | R5 scheme A; `TestChannelCapacityOneFullEmpty`; CONTRACT §1.5; tag `archive/atomic-lockfree-r5-landed-20260717` |
| 6 | **verify-t1 gate** | Done | `make -C core/tests/nextpas.core.lockfree verify-t1`; R6; tag `archive/atomic-lockfree-r6-landed-20260717` |
| 7 | **consumer-audit** | Done | [`consumer-audit.md`](consumer-audit.md); R7 + H2-6 example; tag `archive/atomic-lockfree-r7-landed-20260717` |

Related earlier landings:

| Tag | Wave |
|-----|------|
| `archive/atomic-lockfree-landed-20260717` | Baseline land |
| `archive/atomic-lockfree-rtl-landed-20260717` | RTL isolation slice |
| `archive/atomic-lockfree-usability-landed-20260717` | Usability wave |
| `archive/atomic-lockfree-wave2-landed-20260717` | Wave-2 |
| `archive/atomic-lockfree-wave3-landed-20260717` | Wave-3 (Try\*Ex pilot) |

---

## Policy during Maintenance (post-H2)

1. **Default**: fix T1/atomic production bugs; amend CONTRACT when semantics change; keep `verify-t1` green.
2. **Do not open R9**. H2 is complete; R8 stays research / opt-in.
3. **Major changes** (Closed semantics, expand default facade to T2, promote R8 to production, delete legacy CAS): stop, revise roadmap, ask.
4. Prefer path-limited landings; do not raw-merge long-lived lane history into `main`.
5. Keep artifact hygiene: no `.o`/`.ppu`/build noise in the source tree; `make hygiene` before land.
6. New feature waves need an explicit charter (do not silently extend H2 numbering).

---

## How to verify

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make hygiene
git diff --check
```

Expected: atomic + lockfree main suite + stress green; log default `core/build/verify-lockfree/verify-t1.log`.

Current main-suite size: **lockfree ~178** tests (includes `TestDequeTryExDiagnostics` from H2-1).

Optional consumer example:

```bash
make -C core/examples/nextpas.core.lockfree/t1_close_join_free clean run
```

---

## Archive tags (R4–R7 + Ready + H2)

| Stage | Tag / SHA |
|-------|-----------|
| R4 Try\*Ex expand | `archive/atomic-lockfree-r4-landed-20260717` |
| R5 Channel cap=1 | `archive/atomic-lockfree-r5-landed-20260717` |
| R6 verify-t1 / docs hygiene | `archive/atomic-lockfree-r6-landed-20260717` |
| R7 consumer audit | `archive/atomic-lockfree-r7-landed-20260717` |
| Ready close-out | `archive/atomic-lockfree-ready-20260717` |
| H2-0 charter | `archive/atomic-lockfree-h2-0-landed-20260717` (`03086c0c3`) |
| H2-1…H2-6 land | `archive/atomic-lockfree-h2-complete-20260717` (`d93780c27`) |
| H2 close-out docs | `archive/atomic-lockfree-h2-closeout-20260717` |

---

## Exclude from land

Do **not** bring the following into mainline commits:

- `.playwright-mcp/` (local Playwright MCP noise)
- One-off migrate scripts such as `scripts/migrate_lockfree_test_rtl.py`
- Temporary agent control files (`task_plan.md`, `findings.md`, `progress.md`, session dumps under `/tmp/…`)
- Temp land helpers: `build/h2_land_remaining.sh`, `build/verify-lockfree/h2_*.js`, `build/verify-lockfree/h2_*.log`
- Build artifacts (`.o`, `.ppu`, `link*.res`, binaries under source trees)
- Accidental whitespace-only edits to archived notes (e.g. `optimization-research.md`)

---

## Document links

| Doc | Role |
|-----|------|
| [`roadmap-h2.md`](roadmap-h2.md) | **H2 charter (complete)** |
| [`CONTRACT.md`](CONTRACT.md) | Runtime / API contract truth |
| [`roadmap.md`](roadmap.md) | R0–R7 record + pointer to H2 complete / Maintenance |
| [`consumer-audit.md`](consumer-audit.md) | R7 uses / Close / legacy CAS audit |
| [`README.md`](README.md) | Module entry + T1 matrix |
| [`../atomic/README.md`](../atomic/README.md) / [`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) | Atomic entry + contract |
| [`selection-guide.md`](selection-guide.md) | Consumer selection tree |
| [`api-reference.md`](api-reference.md) | API summary (sync when API changes) |
| [`bench-envelope.md`](bench-envelope.md) | H2-4 reproducible bench envelope |
