# Atomic & Lockfree — Ready Close-out

> **Status**: **Ready / Maintenance**
> **Date**: 2026-07-17
> **Owner**: atomic-lockfree lane
> **Scope**: `nextpas.core.atomic` (L0) + `nextpas.core.lockfree` (L1)

Mainline stages **R0–R7 are complete**. Remaining work on this lane is **bugfix / maintenance only**. **R8** (NUMA / TSX / TLA+) is **opt-in research** and is **not** a default production roadmap item. Do **not** invent an R9 without an explicit roadmap revision and total-control decision.

---

## Module maturity

| Surface | Maturity | Notes |
|---------|----------|-------|
| **T1 runtime core** (lockfree facade) | **Ready-for-consumer** | Unmanaged elements; `Close → join → Free`; contract + tests aligned |
| **atomic** | **Ready-for-consumer** | Canonical `atomic_*` / `TAtomic*`; legacy CAS documented, not preferred |
| **T2 concurrent containers** | **Available, not a unified production contract** | Managed guards or AnsiString exception table; many progress models are lock-based |
| **T3 / research** | Experimental | RTM / NUMA / formal models — direct import only, not default facade |

Authoritative contract: [`CONTRACT.md`](CONTRACT.md). Product entry: [`README.md`](README.md). Roadmap: [`roadmap.md`](roadmap.md).

---

## Acceptance checklist (R0–R7)

All items below are **done**. Evidence points to landed mainline tags, docs, and the standard verify gate.

| # | Acceptance item | Status | Evidence |
|---|-----------------|--------|----------|
| 1 | **ClosedPublishPolicy** | Done | CONTRACT §1.3; SegQueue/MPSC/MSQueue/Channel close semantics landed with R1–R2 |
| 2 | **Managed element guards** | Done | T1 generics reject managed types; T2 guards + AnsiString exception table in CONTRACT §0 / §0.1 / §3.1 |
| 3 | **RTL isolation** | Done | Only `nextpas.core.system*` may use FPC RTL directly; atomic/lockfree production + primary tests use framework abstractions (R1–R2) |
| 4 | **Try\*Ex T1 coverage** | Done | R3 pilot + R4 rings/MPSC/Stack; CONTRACT §1.4; tag `archive/atomic-lockfree-r4-landed-20260717` |
| 5 | **Channel capacity=1** | Done | R5 scheme A (empty/full sequence); `TestChannelCapacityOneFullEmpty`; CONTRACT §1.5; tag `archive/atomic-lockfree-r5-landed-20260717`; lockfree suite **177** tests |
| 6 | **verify-t1 gate** | Done | `make -C core/tests/nextpas.core.lockfree verify-t1`; R6; tag `archive/atomic-lockfree-r6-landed-20260717` |
| 7 | **consumer-audit** | Done | [`consumer-audit.md`](consumer-audit.md); R7 legacy CAS preference + T2 naming footnotes; tag `archive/atomic-lockfree-r7-landed-20260717` |

Related earlier landings (baseline waves):

| Tag | Wave |
|-----|------|
| `archive/atomic-lockfree-landed-20260717` | Baseline land |
| `archive/atomic-lockfree-rtl-landed-20260717` | RTL isolation slice |
| `archive/atomic-lockfree-usability-landed-20260717` | Usability wave |
| `archive/atomic-lockfree-wave2-landed-20260717` | Wave-2 |
| `archive/atomic-lockfree-wave3-landed-20260717` | Wave-3 (Try\*Ex pilot) |

---

## Maintenance policy

1. **Bugfix only** on T1/atomic contracts unless a production bug forces a contract amendment (then update CONTRACT first).
2. **No new R\* stage numbers** (including R9) without revising [`roadmap.md`](roadmap.md) and an explicit go-ahead.
3. **R8** stays research / opt-in; does not expand the default facade or weaken T1 contracts.
4. Prefer path-limited landings; do not raw-merge long-lived lane history into `main`.
5. Keep artifact hygiene: no `.o`/`.ppu`/build noise in the source tree; `make hygiene` before land.

---

## How to verify

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make hygiene
git diff --check
```

Expected: atomic + lockfree main suite + stress green; log default `core/build/verify-lockfree/verify-t1.log`.

Current main-suite size after R5: **lockfree 177** tests (R4 was 176; +`TestChannelCapacityOneFullEmpty`).

---

## Archive tags (R4–R7)

| Stage | Tag |
|-------|-----|
| R4 Try\*Ex expand | `archive/atomic-lockfree-r4-landed-20260717` |
| R5 Channel cap=1 | `archive/atomic-lockfree-r5-landed-20260717` |
| R6 verify-t1 / docs hygiene | `archive/atomic-lockfree-r6-landed-20260717` |
| R7 consumer audit | `archive/atomic-lockfree-r7-landed-20260717` |
| Ready close-out (this document) | `archive/atomic-lockfree-ready-20260717` |

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
| [`CONTRACT.md`](CONTRACT.md) | Runtime / API contract truth |
| [`roadmap.md`](roadmap.md) | Stage map; mainline complete |
| [`consumer-audit.md`](consumer-audit.md) | R7 uses / Close / legacy CAS audit |
| [`README.md`](README.md) | Module entry + T1 matrix |
| [`../atomic/README.md`](../atomic/README.md) / [`../atomic/CONTRACT.md`](../atomic/CONTRACT.md) | Atomic entry + contract |
| [`selection-guide.md`](selection-guide.md) | Consumer selection tree |
| [`api-reference.md`](api-reference.md) | API summary (sync when API changes) |
