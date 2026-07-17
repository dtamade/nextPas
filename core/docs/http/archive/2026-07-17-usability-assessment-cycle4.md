# Usability Assessment: nextpas.core.http (cycle-4)

**Kind**: review / inventory (read-only; no production code changes)
**Module**: `nextpas.core.http` (L3) + controlled cross-module seams (`net` dial/cancel already landed)
**Baseline**: `http` / `main` @ `a12f8dd9b`
  (`feat(net/http): OS dial timeout and mid-read cancel`)
**Comparator**: Go `net/http` + `http.Client` / `Transport`; Rust `reqwest` / hyper-shaped stacks
**Constraint**: dual-compiler isolation; only `nextpas.core.system` may `uses` FPC RTL;
  http production sources/tests/examples must not direct-`uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Usability score** | **91 / 100** (post dial/cancel land; cycle-3 post-fix was ~96 on *claimed* close-out, but H2/doc residual re-opened ~5 pts) |
| **Overall risk** | **Medium** (H1 happy-path strong; H2 dial/cancel parity + doc truth lag) |
| **HTTP-owned open findings** | **8 Implement** + **5 Deferred** + **1 Residual-honest** |
| **Net-owned residual** | Cancel slice latency (~50 ms) — capability landed, not OS interrupt |
| **Deferred / Non-goal** | CONNECT / Retry-After / full PSL / Response metadata expand / ensure-JSON-decode / Op-everywhere / H3 |

**One-line judgment**: After landing real OS dial timeout and mid-read cancel, H1 client paths
are production-grade and close to Go/Rust *defaults for bounded connect + cancel*. Remaining
usability debt is **protocol parity (H2)**, **fluent API completeness**, **docs/current-truth
lag**, and **http-level e2e proof** — not a redesign of the public facade.

### Dimension scores

| Dimension | Score | Notes |
|-----------|------:|-------|
| Interface design | 95 | Stable `IHttp*` seams; builder + Send; registry freeze; thin response surface intentional |
| API usability | 90 | Production helpers; **no** `IHttpClient.WithConnectTimeout`; JSON dual layer (raw vs ensure) |
| Call consistency | 84 | Public → `hekArgument` closed; **H2 dial ignores ConnectTimeout; H2 cancel wire missing** |
| Error message quality | 91 | `METHOD url` on main client paths; `CreateOp` partial; transport wrap solid |
| Boundary conditions | 88 | H1 OS dial + mid-read cancel **Landed**; H2 incomplete; cancel ~50 ms slice residual |
| Test coverage | 86 | Thick gates; net proves dial/cancel; **http lacks live e2e** for dial hang / mid-read cancel |
| Perf / memory safety | 91 | Body ownership, redirect release, heaptrc gates clean on focused suites |

### Score movement vs cycle-3

| Item | cycle-3 (pre-net) | cycle-4 (post `a12f8dd9b`) |
|------|-------------------:|---------------------------:|
| Boundary | 82 (Blocked dial/cancel) | 88 (H1 landed; H2 gap) |
| Call consistency | 88 (transport hekArgument residual then closed) | 84 (**H2 parity regression relative to H1**) |
| Docs truth | Partially honest Blocked table | CONTRACT/README updated; **API_COVERAGE still claims Blocked** |
| Overall | 93–96 claimed after cycle-3 http-only fixes | **91** honest with H2 + docs + test gaps |

---

## Findings

### F1 — Interface design (strong)

- Single facade `uses nextpas.core.http`; handler/middleware/router composition matches Go `Handler` shape.
- Client: `Send` + method shortcuts + ensure-*String helpers; builder for options/body.
- Transport registry H1/H2; H3 honest non-registration.
- **Gap**: `IHttpResponse` stays minimal (Status/Headers/Body/Close) vs Go `Response` (Request, TLS, Proto, ContentLength, Uncompressed…). Documented deferred metadata expand.

### F2 — API usability

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F2a** | `IHttpClient` has `WithTimeout` / `WithProxyUrl` but **no** `WithConnectTimeout` fluent; only `THttpClientOptions.WithConnectTimeout` | Callers who learned fluent chain cannot set dial budget without rebuilding options | **Implement** |
| **F2b** | `IHttpClient.PostJson` returns raw `IHttpResponse`; free `HttpPostJson` is ensure-2xx + string body; types differ (`TJsonValue` vs `IJsonDocument`) | Cognitive dual layer; easy to assume ensure on method | **Implement** (docs + optional method ensure helpers) |
| **F2c** | No `GetJson` / ensure-decode JSON helper (reqwest `.json()` / common Go patterns) | App code reimplements parse + ensure | **Deferred** (product expand) or **P2 Implement** thin helper |
| **F2d** | `NewHttpServer(Handler)` still bases on `THttpServerOptions.Default` (RW=0); Production is explicit | Footgun for copy-paste production servers | **Keep** + reinforce docs (compat); optional P2 warn path only |
| **F2e** | Cancel still cooperative + ~50 ms SO_RCVTIMEO slices (not kernel interrupt) | Cancel latency residual; must stay honest in docs | **Residual-honest** |

### F3 — Call consistency

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F3a** | H1: `ConnectTimeout` / `Timeout` → `H1ClientDial` → `TcpConnect(..., ms)`; cancel → `SetCancelToken` adapter | Meets Go DialTimeout + context cancel *shape* | **Closed** |
| **F3b** | H2: registry only copies `Timeout` into `TH2ClientTransportOptions`; **no ConnectTimeout field**; dial uses `FOptions.Timeout` only | Explicit `ConnectTimeout` **ignored** on H2; dial/IO budget conflated | **Implement P1** |
| **F3c** | H2 client path: **no** `SetCancelToken` / `HttpThrowIfCanceled` mid-exchange wire (grep empty) | Cancel on H2 only at higher client checkpoints, not blocked socket read | **Implement P1** |
| **F3d** | Public construction preconditions → `hekArgument` (cycle-3 closed); bare `EArgumentError` gone from http production sources | Good | **Closed** |

### F4 — Error message quality

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F4a** | Status / redirect / download main paths use `FormatHttpClientError` / `CreateOp` | Ops-friendly | **Closed** |
| **F4b** | Many `EHttpError.Create(Kind, Msg)` without `Op` (client ~28 Create vs ~4 CreateOp) | Harder structured logging / metrics by op | **Deferred** Op-everywhere or **P2** transport+client hot paths only |
| **F4c** | Wrapped `ECancelledError` → `hekCanceled` + Op=transport; message may lack METHOD url at wrap site | Correlation weaker until client rewraps | **P2** if easy at RoundTrip boundary |

### F5 — Boundary conditions

| Capability | H1 | H2 | Status |
|------------|----|----|--------|
| OS dial timeout | Yes (`TcpConnect` timed) | Partial (uses Timeout only; no ConnectTimeout split) | **H2 Implement** |
| Mid-read cancel | Yes (~50 ms slices) | Missing wire | **H2 Implement** |
| Default client Timeout | 30s | 30s via options | OK |
| Default server RW | 0 (Default) / 30s (Production) | same | Honest |
| HTTPS CONNECT proxy | No | No | **Deferred** |
| Cookie full PSL | No (SiteKey approx) | n/a | **Deferred** |
| Retry-After aware retry | No | No | **Deferred** |

### F6 — Test coverage

| Area | Evidence | Gap |
|------|----------|-----|
| Client surface | `test_http_client` ~221 | Strong |
| Server / protocol | server 281, h1/h2 suites | Strong |
| ConnectTimeout option | field defaults only | **No live http client dial-timeout e2e** (net has it) |
| Cancel | Send-entry hekCanceled | **No http e2e mid-read cancel** through real socket |
| H2 dial/cancel | fake dials / unit frames | **No ConnectTimeout/cancel source+runtime contracts** |
| Docs current-truth | CONTRACT/README updated | **API_COVERAGE still says Blocked** for dial/cancel |
| Isolation | no SysUtils in http src | Clean |

### F7 — Perf / memory safety

- Request body close, redirect release, pool retry rewind: sound.
- Focused gates run with `-gh`; zero unfreed blocks on client/server/net suites reviewed this cycle.
- Cancel slice polling increases syscall rate under cancel token — acceptable residual; document.
- No new leak class from dial/cancel slice found in review.

### F8 — FPC RTL isolation

| Scope | Result |
|-------|--------|
| `core/src/nextpas.core.http*.pas` | No direct FPC RTL `uses` |
| Tests / examples | Clean of SysUtils (one test fake may raise `EArgumentError` for stream position — test-only) |

---

## Risk

| ID | Risk | Severity | Likelihood | Notes |
|----|------|----------|------------|-------|
| **R1** | H2 production clients ignore dedicated ConnectTimeout | Medium–High | Medium if H2 + custom dial budget | F3b |
| **R2** | H2 blocked read ignores cancel token | Medium–High | Medium under cancel-only ops | F3c |
| **R3** | Docs claim dial/cancel still Blocked → operators under-trust / over-engineer | Medium | High (stale API_COVERAGE) | F6 docs |
| **R4** | Bare `NewHttpServer` unbounded RW hang | Medium | Medium copy-paste | F2d known |
| **R5** | Cancel-only without Timeout still waits ~slice + no bound if no token/deadline | Medium | Low if Production defaults used | F2e residual |
| **R6** | Deferred CONNECT / PSL / Retry-After product gaps | Medium niche | Low general | Deferred |
| **R7** | Missing http e2e for dial/cancel → silent H1 regression possible | Medium | Low–Medium | F6 |

**Overall risk**: **Medium**.

---

## Priority

| ID | Item | Pri | Disposition |
|----|------|-----|-------------|
| P0-1 | Truth-update API_COVERAGE / assessment archives pointer / GOAL_TREE if stale | P0 | **Implement** (docs only) |
| P1-1 | H2 plumb `ConnectTimeout` (registry + dial + post-dial first-write parity with H1) | P1 | **Implement** |
| P1-2 | H2 wire cancel token → `SetCancelToken` + checkpoints / wrap `ECancelledError` | P1 | **Implement** |
| P1-3 | Http e2e or source-contract proofs: H1 dial timeout + mid-read cancel; H2 ConnectTimeout plumbing | P1 | **Implement** |
| P2-1 | `IHttpClient.WithConnectTimeout` fluent (+ decorator rebind) | P2 | **Implement** |
| P2-2 | JSON dual-layer honesty: README/API table; optional `PostJsonString` ensure helpers | P2 | **Implement** (docs first; code optional) |
| P2-3 | Hot-path `CreateOp` / METHOD url on cancel wrap | P2 | **Implement** if low blast |
| P2-d | CONNECT / Retry-After / full PSL / Response metadata / GetJson decode / Op-all | P2–P3 | **Deferred** |
| P3 | H3 / QUIC | P3 | **Non-goal** |
| Res | ~50 ms cancel slice | — | **Residual-honest** (do not fake OS interrupt) |

---

## Go / Rust gap matrix

| Area | nextpas @ `a12f8dd9b` | Go / Rust bar | Gap |
|------|----------------------|---------------|-----|
| Happy-path client | Get / *String ensure-2xx | `Get` / `.text()` | Small |
| Connect timeout | H1 real OS dial; H2 Timeout-only | `DialContext` / `connect_timeout` | **H2 parity** |
| Cancel | H1 mid-read slices; H2 incomplete | `context` cancel / Drop | **H2 wire + latency honesty** |
| Fluent connect timeout | Options only | `Client.Timeout` + transport dialer / reqwest builder | **WithConnectTimeout** |
| Error typing | `EHttpError.Kind` | typed status / error chain | Close |
| Proxy HTTPS | plain HTTP only | CONNECT common | Deferred |
| Cookie PSL | SiteKey approx | publicsuffix | Deferred |
| JSON ensure+decode | ensure string helpers; no `.json()` | serde/json decode helpers | Deferred / P2 |
| Server defaults | Default RW=0; Production explicit | Often app-set; Go defaults unbounded too | Doc discipline |

---

## Next Steps

1. **Research report** freezes root cause, impact, fix strategy, risk (`2026-07-17-usability-cycle4-research.md`).
2. **Fix plan** freezes milestones / deps / gates (`2026-07-17-usability-cycle4-fix-plan.md`).
3. **User confirmation** before any production code change.
4. Single implementation pass → focused gates → Ready / land path-limited.

---

## Scoring rubric (how 91 is computed)

Weighted average (equal weights for seven dimensions):

`(95+90+84+91+88+86+91) / 7 = 89.3` → rounded with **+1.7** credit for landed H1 dial/cancel (production critical path) and thick existing suite depth → **91**.

If H2 parity + docs + e2e close in the next fix pass, expected **94–96**.
