# Atomic & Lockfree — Ready / Horizon-2 状态

> **Status**: **H2 in progress**（base: R0–R7 + RC Ready complete）
> **Date**: 2026-07-17
> **Owner**: atomic-lockfree lane
> **Scope**: `nextpas.core.atomic` (L0) + `nextpas.core.lockfree` (L1)

Mainline stages **R0–R7 and RC Ready close-out are complete**.
**Current execution line**: **Horizon-2 (H2-0…H2-6)** — see [`roadmap-h2.md`](roadmap-h2.md).
**R8** (NUMA / TSX / TLA+) remains **opt-in research** and is **not** a default production item.
Do **not** invent an R9; H2 is the numbered successor for consistency / evidence / consumer work.

---

## Module maturity

| Surface | Maturity | Notes |
|---------|----------|-------|
| **T1 runtime core** (lockfree facade) | **Ready-for-consumer** | Unmanaged elements; `Close → join → Free`; contract + tests aligned; H2-1 adds Deque `Try*Ex` parity |
| **atomic** | **Ready-for-consumer** | Canonical `atomic_*` / `TAtomic*`; legacy CAS documented, not preferred (H2-3 deepens) |
| **T2 concurrent containers** | **Available, not a unified production contract** | H2-2 documents maturity tiers; **not** default facade |
| **T3 / research** | Experimental | RTM / NUMA / formal models — direct import only |

Authoritative contract: [`CONTRACT.md`](CONTRACT.md). Product entry: [`README.md`](README.md).
R-line map: [`roadmap.md`](roadmap.md). **H2 charter**: [`roadmap-h2.md`](roadmap-h2.md).

---

## Horizon-2 progress

| Stage | Name | Status |
|-------|------|--------|
| **H2-0** | Charter + status switch | **in progress** |
| H2-1 | Deque Try\*Ex (T1 parity) | pending |
| H2-2 | T2 maturity tiers (docs only) | pending |
| H2-3 | atomic preferred path | pending |
| H2-4 | bench evidence envelope | pending |
| H2-5 | formal / stress deepen | pending |
| H2-6 | real consumer in core | pending |
| H2 close-out | READY/roadmap + archive tag | pending |

Details, deliverables, non-goals, and acceptance: [`roadmap-h2.md`](roadmap-h2.md).

---

## Acceptance checklist (R0–R7) — baseline Done

All items below remain **done** and form the H2 baseline.

| # | Acceptance item | Status | Evidence |
|---|-----------------|--------|----------|
| 1 | **ClosedPublishPolicy** | Done | CONTRACT §1.3; SegQueue/MPSC/MSQueue/Channel close semantics landed with R1–R2 |
| 2 | **Managed element guards** | Done | T1 generics reject managed types; T2 guards + AnsiString exception table in CONTRACT §0 / §0.1 / §3.1 |
| 3 | **RTL isolation** | Done | Only `nextpas.core.system*` may use FPC RTL directly; atomic/lockfree production + primary tests use framework abstractions (R1–R2) |
| 4 | **Try\*Ex T1 coverage** | Done (rings/stack/channel); H2-1 extends Deque | R3 pilot + R4; CONTRACT §1.4; tag `archive/atomic-lockfree-r4-landed-20260717` |
| 5 | **Channel capacity=1** | Done | R5 scheme A; `TestChannelCapacityOneFullEmpty`; CONTRACT §1.5; tag `archive/atomic-lockfree-r5-landed-20260717` |
| 6 | **verify-t1 gate** | Done | `make -C core/tests/nextpas.core.lockfree verify-t1`; R6; tag `archive/atomic-lockfree-r6-landed-20260717` |
| 7 | **consumer-audit** | Done | [`consumer-audit.md`](consumer-audit.md); R7; tag `archive/atomic-lockfree-r7-landed-20260717` |

Related earlier landings:

| Tag | Wave |
|-----|------|
| `archive/atomic-lockfree-landed-20260717` | Baseline land |
| `archive/atomic-lockfree-rtl-landed-20260717` | RTL isolation slice |
| `archive/atomic-lockfree-usability-landed-20260717` | Usability wave |
| `archive/atomic-lockfree-wave2-landed-20260717` | Wave-2 |
| `archive/atomic-lockfree-wave3-landed-20260717` | Wave-3 (Try\*Ex pilot) |

---

## Policy during H2

1. **Execute H2-0…H2-6** per [`roadmap-h2.md`](roadmap-h2.md); small commits + focused verify.
2. **Do not open R9**. H2 is the execution line; R8 stays research / opt-in.
3. **Major changes** (Closed semantics, expand default facade to T2, promote R8 to production, delete legacy CAS): stop, revise roadmap, ask.
4. Prefer path-limited landings; do not raw-merge long-lived lane history into `main`.
5. Keep artifact hygiene: no `.o`/`.ppu`/build noise in the source tree; `make hygiene` before land.
6. T1/atomic production bugs still get fixes; contract amendments update CONTRACT first.

---

## How to verify

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make hygiene
git diff --check
```

Expected: atomic + lockfree main suite + stress green; log default `core/build/verify-lockfree/verify-t1.log`.

Current main-suite size after R5: **lockfree 177** tests (R4 was 176; +`TestChannelCapacityOneFullEmpty`). H2-1 may add Deque Try\*Ex cases.

---

## Archive tags (R4–R7 + Ready)

| Stage | Tag |
|-------|-----|
| R4 Try\*Ex expand | `archive/atomic-lockfree-r4-landed-20260717` |
| R5 Channel cap=1 | `archive/atomic-lockfree-r5-landed-20260717` |
| R6 verify-t1 / docs hygiene | `archive/atomic-lockfree-r6-landed-20260717` |
| R7 consumer audit | `archive/atomic-lockfree-r7-landed-20260717` |
| Ready close-out | `archive/atomic-lockfree-ready-20260717` |
| H2 stages | `archive/atomic-lockfree-h2-*-…` (as each lands) |

---

## Exclude from land

Do **not** bring the following into mainline commits:

- `.playwright-mcp/` (local Playwright MCP noise)
- One-off migrate scripts such as `scripts/migrate_lockfree_test_rtl.py`
- Temporary agent control files (`task_plan.md`, `findings.md`, `progress.md`, session dumps under `/tmp/…`)
- Build artifacts (`.o`, `.ppu`, `link*.res`, binaries under source trees)

---

## Document links

| Doc | Role |
|-----|------|
| [`roadmap-h2.md`](roadmap-h2.md) | **H2 execution charter** |
| [`CONTRACT.md`](CONTRACT.md) | Runtime / API contract truth |
| [`roadmap.md`](roadmap.md) | R0–R7 record + pointer to H2 |
| [`consumer-audit.md`](consumer-audit.md) | R7 uses / Close / legacy CAS audit |
| [`README.md`](README.md) | Module entry + T1 matrix |
| [`../atomic/README.md`](../atomic/README.md) / [`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) | Atomic entry + contract |
| [`selection-guide.md`](selection-guide.md) | Consumer selection tree |
| [`api-reference.md`](api-reference.md) | API summary (sync when API changes) |
