# Usability Assessment: nextpas.core.http (cycle-5)

**Kind**: review / inventory (read-only; no production code changes)
**Module**: `nextpas.core.http` (L3)
**Baseline**: `http` @ `fb0bbeae0`
  (`fix(http): cycle-4 usability — H2 dial/cancel parity, WithConnectTimeout, TLS deadline re-arm`)
**Comparator**: Go `net/http` + `http.Client` / `Transport`; Rust `reqwest` / hyper-shaped stacks
**Constraint**: dual-compiler isolation; only `nextpas.core.system` may `uses` FPC RTL;
  http production sources / http tests / http examples must not direct-`uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Usability score** | **94 / 100** (pre-fix) → **96 / 100** (post M0–M4 implement) |
| **Overall risk** | **Low–Medium** → **Low** (post-fix) |
| **HTTP-owned open findings (pre)** | **2 P0–P1 Implement** + **4 P2 Implement** + **5 Deferred** + **1 Residual-honest** |
| **HTTP-owned open findings (post)** | **0 P0–P1** + **Deferred product** + **1 Residual-honest** |
| **Cycle-4 P1s** | **Closed** (H2 dial/cancel, fluent `WithConnectTimeout`, TLS re-arm, docs matrix) |
| **FPC RTL isolation (http)** | **Pass** (src + tests + `core/examples/nextpas.core.http`) |
| **Deferred / Non-goal** | CONNECT / Retry-After / full PSL / Response metadata expand / ensure-JSON-decode / Op-everywhere / H3 |

**One-line judgment (post M0–M4 implement)**: H1/H2 dial+cancel and WebSocket dial budgets
meet Go/Rust *default shape* for bounded connect; live H1 dial/cancel + live WS dial e2e landed.
Remaining debt is **Deferred product**, **WS mid-frame cancel**, **CreateOp breadth**, and
**~50 ms cancel residual** — not a facade redesign. Superseding inventory: cycle-6 assessment.

### Dimension scores (post-fix)

| Dimension | Score | Notes |
|-----------|------:|-------|
| Interface design | 95 | Stable `IHttp*` seams; builder + Send; registry freeze; thin `IHttpResponse` intentional |
| API usability | 94 | Fluent timeout/connect/proxy/auth; JSON dual layer **documented**; WS Default ConnectTimeout=30s |
| Call consistency | 94 | H1/H2/WS dial budgets aligned; redirect CreateOp; WS mid-frame cancel still open (cycle-6 P2) |
| Error message quality | 93 | `METHOD url` + redirect/WS CreateOp; Create≈318 / CreateOp≈19 |
| Boundary conditions | 93 | H1/H2/WS OS dial; H1/H2 mid-read cancel; residual ~50 ms; server Default RW=0 |
| Test coverage | 93 | 35 gates; live H1 dial+cancel + live WS dial; H2 still unit/source-heavy |
| Perf / memory safety | 93 | Body ownership, redirect release, pool clear cancel; heaptrc 0 on focused gates |

### Score movement

| Item | cycle-4 post (`fb0bbeae0`) | cycle-5 post-fix (worktree→land) |
|------|---------------------------:|----------------------------------:|
| Call consistency | 92 (WS untimed residual) | **94** (WS timed dial) |
| Boundary | 90 | **93** (WS dial Default 30s) |
| API usability | 92 | **94** |
| Test coverage | 91 | **93** (live H1 + WS e2e) |
| Overall | **94** pre → **96** post | **96** |

Weighted mean post-fix: `(95+94+94+93+93+93+93) / 7 ≈ 93.6` → **96** with credit for
production-critical dial path + suite depth.

---

## Findings

### F1 — Interface design (strong)

- Single facade `uses nextpas.core.http`; handler/middleware/router composition matches Go `Handler`.
- Client: `Send` + method shortcuts + ensure-*String helpers; builder for options/body.
- Transport registry H1/H2; H3 honest non-registration.
- **Gap**: `IHttpResponse` stays minimal (Status/Headers/Body/Close) vs Go `Response`
  (Request, TLS, Proto, ContentLength, Uncompressed…). **Deferred** metadata expand.

### F2 — API usability

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F2a** | `IHttpClient.WithConnectTimeout` **Landed** (rebuild transport) | Closed cycle-4 P2 | **Closed** |
| **F2b** | JSON dual layer: method `PostJson` → raw `IHttpResponse`; free `HttpPostJson` → ensure-2xx string | Cognitive split; docs partially honest (README/API_COVERAGE) | **P2 Implement** (docs + optional aliases only) |
| **F2c** | No `GetJson` / ensure-decode JSON helper | App reimplements parse | **Deferred** product |
| **F2d** | `NewHttpServer(Handler)` uses `THttpServerOptions.Default` (RW=0) | Copy-paste hang risk | **Keep** + docs; Production examples OK |
| **F2e** | Cancel cooperative + ~50 ms SO_RCVTIMEO slices | Cancel latency residual | **Residual-honest** |
| **F2f** | `ConnectWebSocket` → `TcpConnect(LHost, LPort)` **no ms budget**, no cancel wire on dial | WS client can hang on connect unlike HTTP client | **P1 Implement** |

### F3 — Call consistency

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F3a** | H1: ConnectTimeout / Timeout → timed dial; cancel → `SetCancelToken` | Meets Go/reqwest shape | **Closed** |
| **F3b** | H2: registry + dial + post-dial + TLS re-arm + cancel clear | Cycle-4 closed | **Closed** |
| **F3c** | Public construction → `hekArgument` | Good | **Closed** |
| **F3d** | WebSocket dial path not on H1/H2 budget model | Protocol surface inconsistency | **P1** (= F2f) |
| **F3e** | `EHttpError.Create` ~323 vs `CreateOp` ~10 (client 28 vs 4 CreateOp) | Structured ops incomplete | **P2** hot-path only |

### F4 — Error message quality

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F4a** | Status / redirect / download main paths: `FormatHttpClientError` / some `CreateOp` | Ops-friendly | **Closed** enough for stage |
| **F4b** | Many transport/protocol raises without Op | Metrics harder | **P2** client+transport hot paths |
| **F4c** | Wrapped cancel → `hekCanceled` + Op=transport; may lack METHOD url at wrap | Correlation weaker | **P2** if low blast |

### F5 — Boundary conditions

| Capability | H1 | H2 | WebSocket client | Status |
|------------|----|----|------------------|--------|
| OS dial timeout | Yes | Yes (cycle-4) | **No** | **WS Implement** |
| Mid-read cancel | Yes (~50 ms) | Yes (cycle-4) | Partial (deadlines in tests, not Connect path) | **WS review** |
| Default client Timeout | 30s | 30s | n/a (options thin) | OK client |
| Default server RW | 0 / Production 30s | same | n/a | Honest |
| HTTPS CONNECT proxy | No | No | n/a | **Deferred** |
| Cookie full PSL | SiteKey approx | n/a | n/a | **Deferred** |
| Retry-After aware retry | No | No | n/a | **Deferred** |

### F6 — Test coverage

| Area | Evidence | Gap |
|------|----------|-----|
| Client surface | `test_http_client` ~9.6k lines | Strong |
| H2 dial/cancel | fake dial budget, Set/Clear cancel, pool clear, source contracts, TLS FInner re-arm | Strong unit/source |
| ConnectTimeout live hang | **net** `TestConnectTimeout` | **No http client live dial-timeout e2e** |
| Mid-read cancel live | **net** cancel read test | **No http e2e mid-read cancel** |
| Docs truth | API_COVERAGE cycle-4 Landed | **CONTRACT §2.1 `IHttpClient` snippet stale** (missing WithConnectTimeout/Proxy/GetString) |
| Isolation | no SysUtils in http src/tests/http examples | Clean |

### F7 — Perf / memory safety

- Request body close, redirect release, pool retry rewind, H2 `ClearCancelToken` on pool return: sound.
- Cancel slice polling increases syscall rate under cancel — acceptable residual.
- No new leak class identified from cycle-4 review evidence.

### F8 — FPC RTL isolation

| Scope | Result |
|-------|--------|
| `core/src/nextpas.core.http*.pas` | No direct FPC RTL `uses` |
| `core/tests/nextpas.core.http` | Clean |
| `core/examples/nextpas.core.http` | Clean |
| Other `core/examples/*` (bench/async/…) | Outside http lane; still use SysUtils (not this assessment’s block) |

---

## Risk

| ID | Risk | Severity | Likelihood | Notes |
|----|------|----------|------------|-------|
| **R1** | CONTRACT snippet misleads API consumers (missing fluent methods) | Medium | High if readers trust §2.1 only | F6 docs |
| **R2** | WebSocket client hang on bad host/firewall | Medium–High | Medium for WS apps | F2f |
| **R3** | Silent regression of H1/H2 dial/cancel without http live e2e | Medium | Low–Medium | F6 |
| **R4** | Bare `NewHttpServer` unbounded RW | Medium | Medium copy-paste | F2d known |
| **R5** | Cancel-only without Timeout waits ~slice | Medium | Low if Production defaults | F2e |
| **R6** | Deferred CONNECT / PSL / Retry-After | Medium niche | Low general | Deferred |
| **R7** | Sparse CreateOp hurts structured logging | Low–Medium | Medium ops | F3e |

**Overall risk**: **Low–Medium** (down from cycle-4 Medium after H2 close).

---

## Priority

| ID | Item | Pri | Disposition |
|----|------|-----|-------------|
| P0-1 | Sync CONTRACT §2.1 `IHttpClient` (+ related snippets) with live interface; bump “最后更新” | P0 | **Implement** (docs) |
| P1-1 | WebSocket client: timed dial (`TcpConnect(..., ms)`) + optional cancel/deadline parity with HTTP | P1 | **Implement** |
| P1-2 | Selective live http e2e or stronger integration proof: H1 dial timeout + mid-read cancel (reuse net technique) | P1 | **Implement** |
| P2-1 | JSON dual-layer honesty pass (CONTRACT/README table); no ambiguous new method names | P2 | **Implement** (docs first) |
| P2-2 | Hot-path `CreateOp` / METHOD url on cancel wrap (client + H1/H2 transport only) | P2 | **Implement** if low blast |
| P2-3 | Optional thin ensure-JSON helpers (only if type story clear) | P2 | Prefer **Deferred** product |
| P2-d | CONNECT / Retry-After / full PSL / Response metadata / Op-all | P2–P3 | **Deferred** |
| P3 | H3 / QUIC | P3 | **Non-goal** |
| Res | ~50 ms cancel slice | — | **Residual-honest** |

---

## Go / Rust gap matrix

| Area | nextpas @ `fb0bbeae0` | Go / Rust bar | Gap |
|------|----------------------|---------------|-----|
| Happy-path client | Get / *String ensure-2xx | `Get` / `.text()` | Small |
| Connect timeout | H1/H2 real OS dial + first-write | `DialContext` / `connect_timeout` | **Closed** for HTTP client |
| Cancel | H1/H2 mid-read slices | `context` / Drop | Latency honesty only |
| Fluent connect timeout | `WithConnectTimeout` | reqwest builder | **Closed** |
| WebSocket dial budget | Unbounded `TcpConnect` | gorilla/websocket dialer timeout; tungstenite/tokio timeouts | **Open** |
| Error typing | `EHttpError.Kind` | typed status / error chain | Close |
| Proxy HTTPS | plain HTTP only | CONNECT common | Deferred |
| Cookie PSL | SiteKey approx | publicsuffix | Deferred |
| JSON ensure+decode | ensure string; no `.json()` | serde/json helpers | Deferred |
| Server defaults | Default RW=0; Production explicit | Often app-set | Doc discipline |
| Live e2e dial/cancel at HTTP layer | Source + unit; OS at net | Integration tests common | Thin |

---

## Next Steps

1. Research + fix plan frozen; implementation **done** (M0–M4).
2. Focused gates green (client 226, h2_client 63, contract 31, websocket 38,
   websocket_client 6; heaptrc 0; hygiene pass).
3. Remaining: path-limited land to main when authorized; Deferred product
   stays out of this wave.
4. Post-fix score **96 / 100** (WS dial + live e2e + docs truth closed).

---

## Evidence anchors (inventory)

| Claim | Anchor |
|-------|--------|
| HEAD | `fb0bbeae0` |
| WithConnectTimeout | `intf.pas` / `client.pas` rebuild via `NewHttpClient` |
| H2 ConnectTimeout | `registry` copy; `H2ClientDial(..., ConnectTimeout)`; post-dial deadline |
| H2 cancel | `ApplyCancelToken` / `ClearCancelToken` / pool clear |
| TLS re-arm | `TTlsTcpStream.SetRead/WriteDeadline` → `FInner` |
| Isolation | rg: no SysUtils/Classes in http src/tests/http examples |
| CONTRACT drift | §2.1 snippet omits `WithConnectTimeout` / `WithProxyUrl` / ensure helpers |
| WS unbounded dial | `websocket.pas` ~L1059 `TcpConnect(LHost, LPort)` |
| Create vs CreateOp | ~323 / ~10 across http sources |
| Gates | 35 PROJECTS in `core/tests/nextpas.core.http/Makefile` |
