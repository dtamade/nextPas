# Research: nextpas.core.http usability cycle-5 findings

**Kind**: root-cause + peer comparison (read-only)
**Baseline**: `fb0bbeae0` (cycle-4 land complete)
**Inputs**: cycle-5 assessment; CONTRACT / API_COVERAGE / README; `client` / `impl.h1` /
  `impl.h2.client` / `websocket` / `impl.tls.stream`; Go `net/http`, gorilla/websocket;
  Rust `reqwest`, `tokio-tungstenite`
**Output**: disposition freeze for fix plan (no implementation in this doc)

---

## 1. Problem inventory (classified)

| Class | IDs | Summary |
|-------|-----|---------|
| **Docs truth** | I1 | CONTRACT §2.1 `IHttpClient` snippet lag vs live interface / API_COVERAGE |
| **Protocol parity (surface)** | I2 | WebSocket client dial unbounded; HTTP client H1/H2 already timed |
| **Verification** | I3 | Dial/cancel OS proof lives in `test_net`; http lacks live hang e2e |
| **API ergonomics** | I4 | JSON dual layer (documented but still dual); no GetJson decode |
| **Error structure** | I5 | Sparse `CreateOp` (≈323 Create vs ≈10 CreateOp) |
| **Server defaults** | I6 | `NewHttpServer` → Default RW=0 (compat; Production exists) |
| **Residual honest** | I7 | ~50 ms cancel slice (net design) |
| **Deferred product** | D1–D5 | CONNECT, Retry-After, PSL, response metadata, JSON decode ensure |
| **Non-goal** | N1 | H3/QUIC |
| **Closed this baseline** | C1–C4 | H2 ConnectTimeout, H2 cancel, WithConnectTimeout, TLS FInner re-arm |

---

## 2. Root-cause analysis

### I1 — CONTRACT §2.1 snippet stale

**Symptom**: Live `IHttpClient` has `WithConnectTimeout`, `WithProxyUrl`, `WithCookieJar`,
`GetString`/`GetBytes`/`PostString`/…; CONTRACT §2.1 abbreviated interface still lists only
`WithTimeout` / `WithMaxRedirects` / `WithFollowRedirects` / `WithRetry`.

**Root cause**:
1. CONTRACT §2.2 prose was updated for dial/cancel (cycle-4 era), but the **code block** in
   §2.1 was not regenerated from `intf.pas`.
2. “最后更新：2026-07-16” predates cycle-4 land stamp.
3. API_COVERAGE / README carry current-truth; multi-doc authority split without single
   snippet generation.

**Impact range**: Developers and agents that treat CONTRACT as sole public API inventory
under-discover fluent connect/proxy and ensure helpers; over-engineer options-only paths.

**Peer**: Go godoc and reqwest docs keep builder surfaces in one place; drift is a common
docs failure mode, not a runtime bug.

**Fix strategy**:
1. Rewrite §2.1 `IHttpClient` / related snippets to match `intf.pas` (abbreviated but complete
   method groups).
2. Bump version / last-updated; cross-link cycle-5 assessment.
3. Optional: one-line note in GOAL_TREE current position for cycle-5 open items.

**Risk of fix**: **None** (docs only). Must not invent APIs not in source.

---

### I2 — WebSocket client unbounded dial

**Symptom**: `ConnectWebSocket` establishes TCP via `TcpConnect(LHost, LPort)` with **no**
timeout argument; no `SetCancelToken` before connect/handshake I/O.

**Root cause**:
1. HTTP client dial budget model landed on H1 then H2 (net+http waves / cycle-4).
2. WebSocket client is a **parallel dial path** outside `IHttpTransport.RoundTrip`; it was
   never ported to `TcpConnect(..., ms)` when OS dial timeout arrived.
3. `TWebSocketOptions` currently has origin/check knobs, not ConnectTimeout/Timeout/CancelToken.

**Impact range**: All `ws://` / `wss://` client connects to slow/blackhole peers; production
WS clients hang until OS TCP timeout (minutes-scale), diverging from HTTP client 30s default
discipline.

**Peer**:
- Go: `websocket.Dialer.HandshakeTimeout` / net dialer timeout.
- Rust: `connect_timeout` on client builders; tokio timeouts around connect.

**Fix strategy** (prefer minimal, H1-shaped):
1. Add optional fields to `TWebSocketOptions` (or dedicated connect options):
   - `ConnectTimeout` / `Timeout` (ms semantics aligned to HTTP client where sensible).
   - Optional `IHttpCancelToken` if already used elsewhere for WS (only if low blast).
2. Dial: `TcpConnect(host, port, dialMs)` when budget > 0.
3. Post-dial: apply read/write deadline for handshake I/O (upgrade request/response).
4. Clear deadlines after upgrade success per current connection ownership model.
5. Tests: source-contract for timed dial call; optional local backlog-full live test if stable.
6. Docs: CONTRACT WebSocket section honesty.

**Risk**: Medium — WS options record is public; must keep Default compatible (0 = document
fallback: recommend Production-like defaults or inherit 30s for connect only). Prefer
**additive** fields with 0 = legacy unbounded **or** align Default ConnectTimeout to 30000
with explicit Compatibility note (decide in plan; recommend **Default ConnectTimeout=30000**
for production discipline, with tests updated).

**Recommendation**: Default `ConnectTimeout = 30000` for new discipline; if that is considered
behavior change for tests that assume hang, use 0 default + document must-set — but that
reproduces the footgun. Prefer **30000 default** + tests that expect bounded dial.

---

### I3 — Thin live http-layer dial/cancel e2e

**Symptom**: `test_net` proves OS `TcpConnect(..., ms)` timeout and mid-read cancel.
HTTP tests prove plumbing via source contracts and H2 fake streams; **no**
`NewHttpClient` → blackhole/backlog hang → `hekTimeout` live path in http suite.

**Root cause**:
1. Cycle-4 M3 intentionally deferred flaky blackhole (192.0.2.1) and preferred source contracts.
2. Live hang tests are slower and environment-sensitive; net suite already owns OS semantics.

**Impact**: HTTP-layer regression (e.g. registry drops ConnectTimeout again) might only be
caught by source-contract string matches, not behavioral e2e.

**Peer**: Go stdlib and mature clients usually have integration tests for dial timeouts.

**Fix strategy**:
1. Add **one** H1 live test: local listen backlog-full or non-accepting listener + short
   ConnectTimeout → expect timeout/connect error kind (mirror `test_net` technique).
2. Add **one** mid-read cancel path through real H1 client if stable (slow server holds body;
   cancel token; expect `hekCanceled` within slice bound).
3. Keep source contracts as cheap regression nets.
4. Do **not** require full 35-suite soak for this; focused client (+ optional h2_facade) gates.

**Risk**: Low–Medium (flaky CI). Mitigate with localhost-only, short timeouts, retries avoided.

---

### I4 — JSON dual layer

**Symptom**: Method `PostJson` returns raw response; free `HttpPostJson` ensures 2xx + string.
Types differ (`TJsonValue` vs `IJsonDocument` on free path). No decode-to-value helper.

**Root cause**: Historical layering — transport convenience methods vs app-level ensure helpers.
Documented in API_COVERAGE/README after cycle-4; still dual by design.

**Impact**: Usability friction, not correctness.

**Peer**: reqwest `.json()` ensure+decode; Go usually manual status + json.Unmarshal.

**Fix strategy**:
1. Docs-first: CONTRACT one-paragraph dual-layer table (raw methods vs ensure free-fns vs
   GetString family).
2. Code: only if zero-ambiguity thin alias (e.g. do **not** rename `PostJson` to ensure).
3. Full ensure+decode product → **Deferred**.

**Risk**: Low for docs; Medium if rename/overload confuses existing callers.

---

### I5 — Sparse CreateOp

**Symptom**: ~323 `EHttpError.Create` vs ~10 `CreateOp` across http sources; client ~28 vs ~4.

**Root cause**: Kind taxonomy landed first; Op field optional and only hot-path wired
(transport wrap, download, round_trip).

**Impact**: Structured logging/metrics by operation incomplete.

**Fix strategy**: P2 pass limited to client Send/redirect/retry/download and H1/H2 RoundTrip
boundary — **not** Op-everywhere (parser/huffman noise).

**Risk**: Low if additive Op only.

---

### I6 — Server Default RW=0

**Symptom**: `NewHttpServer(Handler)` → `THttpServerOptions.Default` with Read/Write timeout 0.

**Root cause**: Explicit compatibility for tests; `Production` + examples use 30s.

**Impact**: Copy-paste production hang (same class as Go unbounded Server by default).

**Fix strategy**: Keep Default; reinforce docs; do **not** change Default in cycle-5 (behavior
blast across tests). Optional future: deprecate bare overload in docs only.

**Risk of changing Default**: High test churn — out of scope.

---

### I7 — Cancel slice residual

**Net design**: SO_RCVTIMEO ~50 ms poll; not OS interrupt. Document and pair with Timeout.

**Disposition**: Residual-honest; no fake “instant cancel” claim.

---

## 3. Closed items (do not re-open)

| ID | Item | Evidence |
|----|------|----------|
| C1 | H2 ConnectTimeout plumbing | registry + H2ClientDial + tests |
| C2 | H2 cancel wire + pool clear | Apply/ClearCancelToken tests |
| C3 | `IHttpClient.WithConnectTimeout` | intf + client + forwarder + tests |
| C4 | TLS deadline re-arm to FInner | tls.stream + h2_client regression |
| C5 | Public hekArgument construction | cycle-3 |
| C6 | FPC RTL isolation http path | rg clean |

---

## 4. Deferred product (explicit non-cycle-5)

| ID | Item | Why deferred |
|----|------|--------------|
| D1 | HTTPS CONNECT / proxy auth | Separate design (TLS tunnel) |
| D2 | Retry-After aware retry | Policy product |
| D3 | Full public suffix list | Data + maintenance |
| D4 | `IHttpResponse` metadata expand | API surface freeze discipline |
| D5 | ensure-2xx JSON decode | Type ownership (json module) |
| N1 | H3/QUIC | Blocked on QUIC module |

---

## 5. Impact matrix (for prioritization)

| ID | User-visible? | Correctness? | Blast | Effort | Priority |
|----|---------------|--------------|-------|--------|----------|
| I1 docs | Yes (discoverability) | No | Low | S | P0 |
| I2 WS dial | Yes | Timeout safety | Medium | M | P1 |
| I3 live e2e | Indirect (regression) | Safety net | Low | M | P1 |
| I4 JSON docs | Yes | No | Low | S | P2 |
| I5 CreateOp | Ops | No | Low | S–M | P2 |
| I6 server Default | Yes if misuse | Hang | High if changed | — | Keep |
| I7 residual | Latency | No | — | — | Honest |

---

## 6. Peer comparison (summary)

| Concern | nextpas now | Go | Rust (reqwest / tungstenite) | Cycle-5 action |
|---------|-------------|----|------------------------------|----------------|
| HTTP connect timeout | Landed H1/H2 | Dialer.Timeout | connect_timeout | Maintain |
| HTTP cancel | Landed slice | context | cancel/Drop | Maintain + e2e |
| WS connect timeout | Missing | Dialer timeout | timeouts | **Implement** |
| Docs single source | Multi-doc drift | godoc | docs.rs | **CONTRACT sync** |
| JSON helper | Dual | manual | .json() | Docs / Deferred |

---

## 7. Fix strategy freeze (input to plan)

1. **M0 docs**: CONTRACT §2.1 + last-updated + cycle-5 pointers (API_COVERAGE current-truth line).
2. **M1 WS dial**: timed connect + handshake deadline; options Default discipline; tests.
3. **M2 verification**: selective live H1 dial timeout (+ optional mid-read cancel) in
   `test_http_client`.
4. **M3 polish**: JSON dual-layer CONTRACT table; optional hot-path CreateOp.
5. **Out of scope**: Default server RW change, CONNECT, PSL, H3, GetJson decode product,
   Op-everywhere, OS-level cancel interrupt.

---

## 8. Risk assessment for implementation wave

| Risk | Mitigation |
|------|------------|
| WS Default timeout breaks tests expecting hang | Update WS tests; use short explicit timeouts in hang tests |
| Live dial e2e flaky | Local backlog-full only; bound runtime; quarantine if CI unstable |
| CreateOp message churn | Keep message text stable; only add Op field |
| Scope creep into Deferred | Plan checklist; reject CONNECT/PSL in same PR |

**Overall implementation risk**: **Low–Medium**.
