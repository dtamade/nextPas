# Usability Assessment: nextpas.core.http (cycle-8)

**Kind**: product slice inventory (Wave C)
**Module**: `nextpas.core.http` (L3)
**Baseline**:
- **http worktree HEAD**: `5f15b17d4` (merge main: absorb cycle-7 Wave B)
- **main HEAD** (at plan): `662f38978` (Wave B landed)
**Comparator**: Go `net/http` client patterns; Rust `reqwest` `.json()` / retry middleware
**Constraint**: dual-compiler isolation — only `nextpas.core.system` may `uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Pre-Wave-C score** | **97 / 100** (post Wave B) |
| **Target post-Wave-C** | **~98 / 100** |
| **Overall risk** | **Low–Medium** (retry opt-in behavior change) |
| **This wave** | **C1 GetJson ensure+decode** · **C2 Retry-After + 429** · **C3 docs** |
| **Still Deferred** | CONNECT · full PSL · Response metadata · Op-everywhere · H3 |
| **Residual-honest** | cancel ~50 ms slices |
| **Keep** | server Default RW=0; JSON dual raw/ensure; stream `EIOError` |

**One-line judgment**: Protocol/timeout/cancel path is production-grade after Wave B.
Wave C closes the highest-ROI **application** gaps: ensure+JSON decode and rate-limit-aware retry.

### Dimension focus

| Dimension | Pre | Wave C effect |
|-----------|----:|---------------|
| API usability | 95 | +GetJson / ReadResponseJson |
| Call consistency | 95 | Retry aligns 429/503 with cloud clients |
| Error message quality | 93 | json Op on parse fail |
| Boundary conditions | 94 | Retry-After cap 60s honesty |

---

## Findings (Wave C scope)

| ID | Item | Disposition |
|----|------|-------------|
| **C1** | No ensure-2xx + `JsonParse` → `IJsonDocument` | **Implement** |
| **C2** | `WithRetry` ignores `Retry-After`; no 429 retry | **Implement** |
| **C3** | Inventory still lists ensure-JSON-decode / Retry-After as open Deferred | **Docs** after code |
| D1 | HTTPS CONNECT | **Deferred** (Wave D) |
| D2 | full PSL | **Deferred** |
| D3 | Response metadata expand | **Deferred** |
| D4 | Op-everywhere | **Deferred** |
| D5 | H3 | **Non-goal** |

---

## Priority

| ID | Pri | Action |
|----|-----|--------|
| C1 GetJson family | P2 product | Implement |
| C2 Retry-After + 429 | P2 product | Implement |
| C3 docs truth | P2 | Docs |
| CONNECT / PSL / metadata / Op-all / H3 | P2–P3 | Stay Deferred |

---

## Next Steps

1. Research + fix-plan (this cycle) — done with plan.
2. Implement C1 → C2 → C3.
3. Focused gates + path-limited land.
