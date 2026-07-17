# Research: nextpas.core.http usability cycle-4 findings

**Kind**: root-cause + peer comparison (read-only)
**Baseline**: `a12f8dd9b` (dial/cancel land)
**Inputs**: cycle-4 assessment; CONTRACT §2.2 / §2.2.0a; `impl.h1` / `impl.h2.client` / `impl.registry`; Go `net/http`, Rust `reqwest`
**Output**: disposition freeze for fix plan (no implementation in this doc)

---

## 1. Problem inventory (classified)

| Class | IDs | Summary |
|-------|-----|---------|
| **Protocol parity** | I1, I2 | H2 missing ConnectTimeout plumb + cancel wire that H1 already has |
| **API ergonomics** | I3, I4 | No fluent `WithConnectTimeout`; JSON method vs free-fn dual layer |
| **Truth / docs** | I5 | API_COVERAGE (and older assessment archives) still claim dial/cancel Blocked |
| **Verification** | I6 | Dial/cancel proven in `test_net`; http client lacks live e2e / H2 source contracts |
| **Error structure** | I7 | Partial `CreateOp` / METHOD url on cancel wrap |
| **Residual honest** | I8 | ~50 ms cancel slice (net design; not a fake) |
| **Deferred product** | D1–D5 | CONNECT, Retry-After, PSL, response metadata, JSON decode ensure |
| **Non-goal** | N1 | H3/QUIC |

---

## 2. Root-cause analysis

### I1 — H2 ignores dedicated ConnectTimeout

**Symptom**: Setting `THttpClientOptions.ConnectTimeout` affects H1 dial/first-write budget but not H2 dial.

**Root cause**:
1. `impl.registry` maps client options → H1 with `ConnectTimeout`; H2 mapping only sets `Timeout` (and server-ish fields).
2. `TH2ClientTransportOptions` has no `ConnectTimeout` field.
3. `H2ClientDial(..., FOptions.Timeout)` collapses dial budget into total request Timeout.

**Why it happened**: Dial/cancel slice was wired first on H1 (primary production path) in a cross-module net+http land; H2 dial already used timed `TcpConnect` via Timeout only — incomplete port of the H1 split semantics.

**Impact range**: All `WithVersion(hvHttp2)` / H2 registry clients; apps that set short ConnectTimeout + long Timeout expect dial to fail fast (Go/reqwest behavior) — on H2 dial can consume full Timeout.

**Peer**:
- Go: `http.Transport.DialContext` / `Dialer.Timeout` independent of `ResponseHeaderTimeout`.
- reqwest: `connect_timeout` vs `timeout` separate.

**Fix strategy**:
1. Add `ConnectTimeout` to `TH2ClientTransportOptions`.
2. Registry copy from `THttpClientOptions.ConnectTimeout`.
3. Dial with `EffectiveConnectTimeout` semantics aligned to H1 (`ConnectTimeout>0` else fallback Timeout).
4. Post-dial first-write deadline: same rule as H1 (`ConnectTimeout` re-arm if >0 else full Timeout).
5. Tests: option plumbing source contract + optional live dial if stable in CI.

**Risk of fix**: Low–Medium (H2 options record + registry + dial call sites). Must not break cleartext H2 facade tests.

---

### I2 — H2 missing mid-read cancel wire

**Symptom**: `IHttpCancelToken` mid-blocked-read cancel works on H1 after dial; H2 path has no `SetCancelToken` usage.

**Root cause**:
1. H1 introduced `THttpNetCancelAdapter` + `H1ClientApplyCancelToken` after dial.
2. H2 connection holds `ITcpStream` but never applies cancel token from request options.
3. Higher-level `HttpThrowIfCanceled` may still run in client facade, but not during H2 frame read/write blocks.

**Impact**: Cancel-driven clients on H2 hang until Timeout / peer close — violates “cancel works” mental model after H1 land.

**Peer**: Go context cancel aborts RoundTrip on both HTTP/1 and HTTP/2; reqwest cancel drops the future.

**Fix strategy**:
1. After dial / before handshake and on reused conn checkout: `SetCancelToken` adapter from request EffectiveCancelToken.
2. Clear token when returning connection to pool (avoid cancel leaking across requests).
3. Ensure `HttpWrapTransportException` / H2 RoundTrip maps `ECancelledError` → `hekCanceled` (reuse base helper).
4. Unit/fake stream or source-contract that H2 path calls SetCancelToken; optional live test.

**Risk**: Medium — pool reuse must clear token; handshake vs per-request cancel ownership must be defined (per-request on stream for duration of RoundTrip only).

---

### I3 — No fluent WithConnectTimeout

**Symptom**: Fluent chain `WithTimeout` / `WithProxyUrl` exists; ConnectTimeout only via options record.

**Root cause**: Options field added in wave-5/6; fluent surface lagged; dial was Blocked then landed without fluent follow-up.

**Impact**: Usability friction, not correctness (options path works).

**Peer**: reqwest builder `connect_timeout`; Go usually sets Transport dialer (less fluent on Client).

**Fix strategy**: Add `IHttpClient.WithConnectTimeout` rebuilding client options like `WithProxyUrl` (or options merge if existing pattern for timeout decorator).

**Risk**: Low.

---

### I4 — JSON dual layer / type split

**Symptom**:
- `IHttpClient.PostJson(..., TJsonValue): IHttpResponse` — no ensure.
- `HttpPostJson(..., IJsonDocument): string` — ensure-2xx + body string.
- No decode helper.

**Root cause**: Intentional layering (raw vs ensure free-fns) evolved; types split across json APIs.

**Impact**: Medium cognitive load; not a runtime bug if docs honest.

**Peer**: reqwest separates `.send()` vs `.error_for_status()` / `.json()`; Go often manual.

**Fix strategy**:
1. **Docs first**: table “raw method vs ensure free-fn”.
2. Optional: `PostJsonString` method aliases free-fn; avoid breaking PostJson signature.
3. GetJson decode = Deferred product unless thin `HttpGetJsonDocument` is cheap.

**Risk**: Low for docs; Medium if renames/break API.

---

### I5 — Docs claim dial/cancel still Blocked

**Symptom**: `API_COVERAGE.md` “当前结论” still lists OS dial + mid-read cancel as Blocked; older cycle-3 assessment archives frozen pre-land.

**Root cause**: Land commit updated CONTRACT/README; API_COVERAGE matrix not rewritten in same slice.

**Impact**: High trust damage — operators plan workarounds for fixed issues; auditors distrust honesty tables.

**Fix strategy**: Rewrite API_COVERAGE current-truth block; point to cycle-4 assessment; mark H2 residual explicitly (not “Blocked net”).

**Risk**: None (docs).

---

### I6 — Http-level verification gap

**Symptom**: `test_net` has Connect timeout + Read cancel token; `test_http_client` has option defaults + Send-entry cancel + source window for H1ClientDial; no live “client dial hangs → hekTimeout” or “mid-body cancel → hekCanceled”.

**Root cause**: Net gate owned capability; http land relied on source contracts + net tests under time pressure.

**Impact**: Regression risk on H1 wiring; H2 gaps invisible to green gates.

**Fix strategy**:
1. Source-contract: H1/H2 dial helper uses timed TcpConnect; SetCancelToken present.
2. Prefer deterministic local hang (backlog-full listen) over 192.0.2.1 (proxy environments fake-connect).
3. Mid-read cancel: slow server + cancel after headers or net-level already sufficient if source-contract locks wire — prefer one http e2e if stable.

**Risk**: Flaky CI if using real network; prefer local backlog technique proven in net tests.

---

### I7 — CreateOp / METHOD url partial

**Root cause**: Historical Create(string/Kind) growth; CreateOp added for transport/download.

**Impact**: Low–Medium observability.

**Fix strategy**: P2 only on cancel wrap + RoundTrip failure paths; no mass rewrite.

---

### I8 — Cancel slice latency (~50 ms)

**Root cause**: Net design uses SO_RCVTIMEO slices instead of interruptible syscall cancel (portable, simple).

**Impact**: Cancel not instantaneous; documented residual.

**Disposition**: **Residual-honest**. Do not invent OS-level interrupt in http. Optional future net epic (eventfd/poll cancel) out of cycle-4 scope.

---

## 3. Impact scope matrix

| Finding | Paths | Callers affected | Cross-module? |
|---------|-------|------------------|---------------|
| I1 H2 ConnectTimeout | `impl.h2.client`, `impl.registry`, maybe types/options record | H2 clients | http only |
| I2 H2 cancel | `impl.h2.client` (+ adapter reuse from h1 or base) | H2 + cancel token | http (+ net API already exists) |
| I3 fluent | `intf`, `client` | fluent chains | http only |
| I4 JSON docs | docs; optional client helpers | app authors | http only |
| I5 docs | API_COVERAGE, assessment pointer | all consumers | docs |
| I6 tests | test_http_client / h2_client / contract | CI | tests |
| I7 errors | client / h2 RoundTrip | ops | http only |
| I8 residual | net tcp | all cancel users | document only |

---

## 4. Fix strategy summary (by disposition)

| ID | Disposition | Strategy | Est. blast radius |
|----|-------------|----------|-------------------|
| I1 | **Implement P1** | Plumb ConnectTimeout H2 end-to-end | H2 options + dial |
| I2 | **Implement P1** | SetCancelToken per RoundTrip; clear on pool return | H2 connection lifecycle |
| I3 | **Implement P2** | Fluent WithConnectTimeout | iface + client + tests |
| I4 | **Implement P2** | Docs + optional ensure helpers | docs / thin API |
| I5 | **Implement P0** | API_COVERAGE truth | docs |
| I6 | **Implement P1** | Source + selective e2e | tests |
| I7 | **Implement P2** | Hot-path Op/context | small |
| I8 | **Residual** | Document only | none |
| D1–D5 | **Deferred** | Separate milestones | large |
| N1 | **Non-goal** | QUIC dep | n/a |

---

## 5. Risk assessment for the fix program

| Risk | Mitigation |
|------|------------|
| H2 pool + cancel token leak across requests | Clear SetCancelToken(nil) before pool put; test |
| ConnectTimeout=0 semantics drift H1/H2 | Shared helper or copy H1 EffectiveConnectTimeout logic |
| Flaky dial e2e | Local backlog-full; skip if environment blocks; net gate remains primary |
| API expansion (WithConnectTimeout) | Additive only; no renames |
| Scope creep into CONNECT/PSL | Explicit Deferred freeze in plan |

**Program risk**: **Medium** — concentrated in H2 client path; H1 already green.

---

## 6. Peer comparison detail

### Go `net/http`

| Concern | Go | nextpas after land | Action |
|---------|----|--------------------|--------|
| Dial timeout | `net.Dialer.Timeout` | H1 yes; H2 partial | I1 |
| Request cancel | `Request.Context()` | Token + H1 slices; H2 incomplete | I2 |
| Client timeout | `Client.Timeout` full request | Timeout 30s default | OK |
| Error type | `*url.Error` / status | `EHttpError.Kind` | OK |
| CONNECT | Transport Proxy | Deferred | D1 |

### Rust `reqwest`

| Concern | reqwest | nextpas | Action |
|---------|---------|---------|--------|
| connect_timeout | builder method | options only (+H1 real) | I1+I3 |
| timeout | builder | WithTimeout | OK |
| error_for_status | explicit | *String ensure | OK / I4 |
| json() | decode | missing | D5 deferred |
| cancel | Drop / AbortHandle | token | I2 |

---

## 7. Disposition freeze (for plan)

```
P0  I5 docs truth
P1  I1 H2 ConnectTimeout
P1  I2 H2 cancel wire
P1  I6 verification
P2  I3 WithConnectTimeout
P2  I4 JSON honesty (+ optional helpers)
P2  I7 Op/context hot paths
RES I8 slice latency
DEF D1 CONNECT | D2 Retry-After | D3 PSL | D4 Response metadata | D5 GetJson decode
NON N1 H3
```

**Do not** fake OS interrupt in http.
**Do not** change Default server RW=0 without explicit product decision (compat).
**Do not** raw-merge long lane history; path-limited land after implement.
