# Usability Assessment: nextpas.core.http (cycle-11)

**Kind**: product slice inventory (Wave F)
**Module**: `nextpas.core.http` (L3)
**Baseline**:
- **http worktree HEAD**: post Wave E absorb (`26edfe0c5`)
- **main HEAD** (at plan): `2820157d2` (Wave E landed + pushed)
**Comparator**: cloud SDK Retry-After (IMF-fix); reqwest/custom TLS; GetJson symmetry for POST
**Constraint**: dual-compiler isolation — only `nextpas.core.system` may `uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Pre-Wave-F score** | **~99 / 100** (post Wave E) |
| **Target post-Wave-F** | **~99.3 / 100** |
| **Overall risk** | **Low** (retry parse + fluent options + free-fn helpers) |
| **This wave** | **F1 HTTP-date Retry-After** · **F2 WithTLSContext** · **F3 JSON write ensure+decode** |
| **Still Deferred** | full PSL · Response metadata · Op-everywhere · H3 · Digest/SOCKS |
| **Residual-honest** | cancel ~50 ms slices; OpenSSL factory residual when backend unit linked |
| **Keep** | server Default RW=0; dual raw/ensure-string JSON; CONNECT + direct HTTPS |

**One-line judgment**: After Wave E closed TLS/proxy product gaps, Wave F polishes
**retry honesty**, **TLS ergonomics**, and **JSON write-path ensure+decode symmetry**.

### Dimension focus

| Dimension | Pre | Wave F effect |
|-----------|----:|---------------|
| API usability | 98 | Fluent TLSContext; Post/Put/Patch JsonDocument helpers |
| Call consistency | 98 | GetJson-style ensure+decode on write methods |
| Error message quality | 93 | Unchanged Kind/Op semantics for JSON |
| Boundary conditions | 96 | Retry-After IMF-fix + cap 60s; past → 0 |

---

## Findings (Wave F scope)

| ID | Item | Disposition |
|----|------|-------------|
| **F1** | `WithRetry` HTTP-date `Retry-After` | **Implement** |
| **F2** | `WithTLSContext` options + fluent client | **Implement** |
| **F3** | `HttpPost/Put/PatchJsonDocument` ensure+decode | **Implement** |
| G1 | full PSL / metadata / Op-all / H3 | **Deferred** |

---

## Priority

| ID | Pri | Action |
|----|-----|--------|
| F1 HTTP-date Retry-After | P2 product | Implement |
| F2 WithTLSContext | P2 product | Implement |
| F3 JSON write document | P2 product | Implement |
| PSL / H3 / Digest / SOCKS | P2–P3 | Stay Deferred |

---

## Next Steps

1. Research + fix-plan (this cycle).
2. Implement F1 → F2 → F3.
3. Focused gates + path-limited land.
