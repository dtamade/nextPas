# Usability Assessment: nextpas.core.http (cycle-9)

**Kind**: product slice inventory (Wave D)
**Module**: `nextpas.core.http` (L3)
**Baseline**:
- **http worktree HEAD**: `f2c0f8f08` (merge main: absorb cycle-8 Wave C)
- **main HEAD** (at plan): `5120626f0` (Wave C landed + pushed)
**Comparator**: Go `net/http` CONNECT proxy; curl `--proxy` HTTPS tunnel
**Constraint**: dual-compiler isolation — only `nextpas.core.system` may `uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Pre-Wave-D score** | **~98 / 100** (post Wave C) |
| **Target post-Wave-D** | **~98.5 / 100** |
| **Overall risk** | **Medium** (TLS tunnel + pool keying) |
| **This wave** | **D1 HTTPS CONNECT via plain HTTP proxy** · **D2 tests** · **D3 docs** |
| **Still Deferred** | proxy auth · full PSL · Response metadata · Op-everywhere · H3 · H1 direct https |
| **Residual-honest** | cancel ~50 ms slices; OpenSSL factory residual when backend unit linked |
| **Keep** | server Default RW=0; plain http absolute-form proxy; JSON dual raw/ensure |

**One-line judgment**: After Wave C application helpers, Wave D closes the highest-ROI
**enterprise egress** gap: HTTPS through a plain HTTP forward proxy via CONNECT + TLS.

### Dimension focus

| Dimension | Pre | Wave D effect |
|-----------|----:|---------------|
| API usability | 96 | ProxyUrl works for https targets |
| Call consistency | 96 | CONNECT then origin-form over TLS |
| Error message quality | 93 | CONNECT non-2xx → hekConnect |
| Boundary conditions | 94 | http proxy only; no proxy auth |

---

## Findings (Wave D scope)

| ID | Item | Disposition |
|----|------|-------------|
| **D1** | HTTPS CONNECT through `http://` proxy | **Implement** |
| **D2** | e2e CONNECT success + denied + origin-form | **Tests** |
| **D3** | CONTRACT / API_COVERAGE / README / inventory | **Docs** after code |
| E1 | Proxy authentication | **Deferred** |
| E2 | H1 direct https (no proxy) | **Deferred** (still rejected) |
| E3 | full PSL / metadata / Op-all / H3 | **Deferred** |

---

## Priority

| ID | Pri | Action |
|----|-----|--------|
| D1 CONNECT + TLS wrap | P2 product | Implement |
| D2 focused e2e | P2 | Tests |
| D3 docs truth | P2 | Docs |
| Proxy auth / H1 direct https / PSL / H3 | P2–P3 | Stay Deferred |

---

## Next Steps

1. Research + fix-plan (this cycle).
2. Implement D1 → D2 → D3.
3. Focused gates + path-limited land.
