# Atomic & Lockfree — Ready / Horizon-2 / Horizon-3 状态

> **Status**: **H3-5 done** → **Q 线**（Q0–Q3 done；下步 Q4/Q5）
> **Date**: 2026-07-20
> **Owner**: atomic-lockfree lane（全权）
> **Scope**: atomic + lockfree + H3 消费者面；执行主线见 [`quality-parity.md`](quality-parity.md)（**Q0–Q5**）

Mainline stages **R0–R7 and RC Ready close-out are complete**.
**Horizon-2 / Horizon-3 (H3-1…H3-5) are complete** — see [`roadmap-h2.md`](roadmap-h2.md) / [`roadmap-h3.md`](roadmap-h3.md).
**Current execution line**: **Q 线** — Q0–Q3 done（见 [`quality-parity.md`](quality-parity.md)）；下步 Q4/Q5 — **not R9**.
**R8** remains **opt-in research** — see [`r8-research-status.md`](r8-research-status.md).
Do **not** invent an R9.

H3 close-out remains the production baseline; Q 线加深质量与可导航规模，不堆 T2 玩具。

H3-1 land HEAD on main: `710ddd7ab` (feat `8d99b07ab` + Wave-1 status docs).
H3-2 evidence: CONTRACT §0.3; `test_lockfree_bag` / `test_lockfree_multimap` H3-2 pins; multimap `Destroy` closes first.
H3-3 evidence: `make -C core/tests/nextpas.core.lockfree verify-h3-consumers`; log `core/build/verify-lockfree/verify-h3-consumers.log`.
H3-4 evidence: active README/selection-guide absolute-Mops scrub; historical banners; api-ref bag/multimap §0.3.
H3-5 evidence: `thread.pool.worksteal` + `test_worksteal` (source-contract + behavior); consumer-audit §2.6.

Archive: `archive/atomic-lockfree-h2-complete-20260717` (H2-1…H2-6 land HEAD `d93780c27`);
close-out docs: `archive/atomic-lockfree-h2-closeout-20260717`.

---

## Module maturity

| Surface | Maturity | Notes |
|---------|----------|-------|
| **T1 runtime core** (lockfree facade) | **Ready-for-consumer** | Unmanaged elements; `Close → join → Free`; contract + tests aligned; H2-1 Deque `Try*Ex` parity landed |
| **atomic** | **Ready-for-consumer** | Canonical `atomic_*` / `TAtomic*`; legacy CAS documented, not preferred (H2-3) |
| **T2 concurrent containers** | **Guarded tiers + H3-2 subset** | H2-2 tiers; **bag/multimap** have H3-2 production contract (§0.3); **not** default facade |
| **T3 / research** | Experimental | RTM / NUMA / formal models — direct import only; R8 status in [`r8-research-status.md`](r8-research-status.md) |
| **Cross-module T1 consumer** | **H3-1 + H3-5 done** | async → mpsc；thread.pool.worksteal → deque |
| **Consumer regression gate** | **H3-3 done** | `verify-h3-consumers` formalizes async + bag/multimap + H2-6 example |

Authoritative contract: [`CONTRACT.md`](CONTRACT.md). Product entry: [`README.md`](README.md).
R-line map: [`roadmap.md`](roadmap.md). **H2**: [`roadmap-h2.md`](roadmap-h2.md). **H3**: [`roadmap-h3.md`](roadmap-h3.md).
**Q 线（当前）**: [`quality-parity.md`](quality-parity.md) — 执行阶段。
**对标目标**: [`parity-go-rust.md`](parity-go-rust.md) — Go/Rust atomic+lockfree 质量与规模矩阵。

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

## Horizon-3

| Item | Status | Evidence |
|------|--------|----------|
| H3 charter | **done** | [`roadmap-h3.md`](roadmap-h3.md) · `archive/atomic-lockfree-h3-charter-20260717` |
| **H3-0e** status switch | **done** | Wave-1 opened then closed on this document |
| **H3-1** async T1 MPSC on `TAsyncLoop.Post` | **done** | feat `8d99b07ab`; land tip `710ddd7ab`; `async.loop` + `test_async` source-contract |
| **H3-2** T2 Guarded subset (bag + multimap) | **done** | CONTRACT §0.3; unit headers; bag/multimap tests H3-2 pins; multimap Destroy→Close |
| **H3-3** consumer regression gate | **done** | `verify-h3-consumers` (async + bag + multimap + t1_close_join_free) |
| **H3-4** evidence / api-ref hygiene | **done** | active docs + historical banners + api-ref §0.3; 2026-07-19 |
| **H3-5** worksteal | **done** | `thread.pool.worksteal` → T1 deque; `test_worksteal`; 2026-07-19 |

Cross-module (H3-1): `nextpas.core.async.loop` → `nextpas.core.lockfree.mpsc` (L1→L1; lockfree must not depend on async).
Lifecycle async: `Close → discard remaining (no fire) → Free`; join Post producers **outside** the loop before Close/Free.
H3-2: direct import bag/multimap only; Close/managed/progress per CONTRACT §0.3.
H3-3: does **not** replace `verify-t1`; run both for Maintenance / land.

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
| 7 | **consumer-audit** | Done | [`consumer-audit.md`](consumer-audit.md); R7 + H2-6 example + **H3-1 async.loop** + **H3-3 gate**; tag `archive/atomic-lockfree-r7-landed-20260717` |

Related earlier landings:

| Tag | Wave |
|-----|------|
| `archive/atomic-lockfree-landed-20260717` | Baseline land |
| `archive/atomic-lockfree-rtl-landed-20260717` | RTL isolation slice |
| `archive/atomic-lockfree-usability-landed-20260717` | Usability wave |
| `archive/atomic-lockfree-wave2-landed-20260717` | Wave-2 |
| `archive/atomic-lockfree-wave3-landed-20260717` | Wave-3 (Try\*Ex pilot) |

---

## Policy during Maintenance + Q 线

1. **Default**: execute **Q0–Q5** ([`quality-parity.md`](quality-parity.md)); fix T1/atomic/H3 consumer bugs; keep **`verify-t1` + `verify-h3-consumers`** (+ `test_worksteal` when relevant) green; absolute Mops only with envelope.
2. **Do not open R9**. H3 is complete; Q 线 is the quality program; R8 stays research / opt-in.
3. **Major changes** (Closed semantics, expand default facade to T2, promote R8 to production, delete legacy CAS): stop, revise roadmap, ask.
4. Prefer path-limited landings; do not raw-merge long-lived lane history into `main`.
5. Keep artifact hygiene: no `.o`/`.ppu`/build noise; `make hygiene` before land.
6. Expanding T2 **production subset** beyond bag/multimap requires a one-page charter under Q4.

---

## Post-H3-5 maintenance checklist

### Allowed without new charter

- T1 / atomic **bugfix**
- H3-2 bag/multimap **regression** (Close / managed / facade isolation)
- H3-1 async MPSC **regression** (keep pending path green)
- H3-5 worksteal **regression** (`test_worksteal` + source-contract)
- **CONTRACT** amendments for **clarity** (no silent semantic flip)
- **`verify-t1` / `verify-h3-consumers` hygiene**
- **Docs sync** (README / api-ref / selection-guide / READY / roadmap pointers)

### Requires new charter stage (post-H3-5 or explicit opt-in)

- New **production features** beyond H3-5 scope
- Additional **cross-module consumer wiring** (http / net, etc.)
- Expanding H3-2 subset to **more T2 types**
- **R8 production promotion**

Charter: [`roadmap-h3.md`](roadmap-h3.md). **H3-1…H3-5 complete → Maintenance.**

### Still forbidden without major-change discussion

- **Closed** semantics change
- Expand **default facade** to T2
- **Delete legacy CAS**
- **Invent R9**

### Opt-in research

- R8 research pack status / close-out: [`r8-research-status.md`](r8-research-status.md)
- Formal models: [`formal/README.md`](formal/README.md)
- Optional gate: `make -C core/tests/nextpas.core.lockfree verify-r8` (does **not** replace `verify-t1`)

---

## How to verify

```bash
export PATH="/opt/fpcupdeluxe/fpc/bin/x86_64-linux:$PATH"
make -C core/tests/nextpas.core.lockfree verify-t1
make -C core/tests/nextpas.core.lockfree verify-h3-consumers
make -C core/tests/nextpas.core.thread/test_worksteal clean test
make hygiene
git diff --check
```

Expected:
- `verify-t1`: atomic + lockfree main suite + stress green; log `core/build/verify-lockfree/verify-t1.log`
- `verify-h3-consumers`: async (H3-1) + bag/multimap (H3-2) + t1_close_join_free (H2-6) green
- `test_worksteal`: H3-5 source-contract + behavior green

Current main-suite size: **lockfree ~178** tests (includes `TestDequeTryExDiagnostics` from H2-1).

Optional R8 research gate (does not replace T1):

```bash
make -C core/tests/nextpas.core.lockfree verify-r8
```

---

## Archive tags (R4–R7 + Ready + H2 + Maint/H3/R8 + H3-1)
