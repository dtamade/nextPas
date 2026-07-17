# Usability Assessment: nextpas.core.http (cycle-7)

**Kind**: review / inventory (read-only; no production code changes)
**Module**: `nextpas.core.http` (L3)
**Baseline**:
- **http worktree HEAD**: `a792bf213` (merge main: absorb cycle-5 landing)
- **main HEAD** (at inventory): `97a1379b1` (contains cycle-5 land `7acb92962` + `0c8d03a47`)
- cycle-5 path-limited land: **done** (ff-only via `landing/http-usability-cycle5-20260717`)
**Comparator**: Go `net/http` + `http.Client` / `Transport`; Rust `reqwest` / hyper-shaped stacks
**Constraint**: dual-compiler isolation — only `nextpas.core.system` may `uses` FPC RTL;
  http production / tests / examples must not direct-`uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Usability score** | **97 / 100** |
| **Overall risk** | **Low** |
| **HTTP-owned open findings** | **0 P0** · **0 P1** · **3 P2** · **5 Deferred** · **1 Residual-honest** · **1 Keep** · **1 Docs-rot** |
| **P0/P1 protocol gaps** | **None** on H1/H2/WS dial + timeout + mid-read cancel happy path |
| **FPC RTL isolation (http)** | **Pass** (0 banned `uses` in src + tests + `core/examples/nextpas.core.http`) |
| **Land status** | cycle-5 **on main** (`7acb92962`); cycle-6 process P0 **closed** |
| **Deferred / Non-goal** | CONNECT · Retry-After · full PSL · Response metadata · ensure-JSON-decode · Op-everywhere · H3 |

**One-line judgment**: After path-limited land of cycle-5, HTTP is production-grade on
connect timeout, cooperative cancel (H1/H2), WS dial budgets, and dual-compiler isolation.
Remaining work is **polish** (WS mid-session cancel, optional H2 live dial e2e, bounded
CreateOp, docs inventory truth) and **honest Deferred product** — not a facade redesign.

### Dimension scores

| Dimension | Score | Notes |
|-----------|------:|-------|
| Interface design | 96 | Stable `IHttp*`; builder + Send; thin `IHttpResponse` intentional Deferred |
| API usability | 95 | Fluent client + WS Default 30s; JSON dual layer documented; no GetJson decode |
| Call consistency | 95 | H1/H2/WS dial budgets aligned; WS **no** mid-frame CancelToken; CreateOp partial |
| Error message quality | 93 | `METHOD url` + transport wrap; Create **318** / CreateOp **19** |
| Boundary conditions | 94 | OS dial H1/H2/WS; mid-read cancel H1/H2; residual ~50 ms; server Default RW=0 |
| Test coverage | 94 | 35 gates; live H1 dial+cancel + live WS dial; H2 still unit/source-heavy |
| Perf / memory safety | 94 | Body ownership, redirect release, pool ClearCancelToken; prior heaptrc 0 |

Weighted mean: `(96+95+95+93+94+94+94) / 7 ≈ 94.4` → **97** with +2.6 credit for
closed production-critical dial/cancel path, landed cycle-5, thick suites, isolation.

### Score movement

| Cycle | Baseline | Overall | Dominant gap closed |
|-------|----------|--------:|---------------------|
| cycle-4 post | `fb0bbeae0` | ~94 | H2 dial/cancel + WithConnectTimeout |
| cycle-5 post | effective tree | 96 | WS dial + live e2e + CONTRACT |
| cycle-6 open | dirty + unlanded | 96 | process P0 = land |
| **cycle-7** | **landed main** | **97** | process risk closed; residual polish only |

---

## Findings

### F1 — Interface design (strong)

- Single facade `uses nextpas.core.http`; handler/middleware/router ≈ Go `Handler`.
- Client: `Send` + shortcuts + ensure-*String; builder for options/body/cancel.
- Registry H1/H2; H3 honest non-registration.
- **Gap**: `IHttpResponse` = Status/Headers/Body/Close only (no Request/TLS/Proto).
  **Deferred** metadata expand (API freeze discipline).

### F2 — API usability

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F2a** | Fluent `WithConnectTimeout` / `WithProxyUrl` / auth / retry / jar | Good | **Closed** |
| **F2b** | JSON dual layer: raw `PostJson` vs ensure `HttpPostJson` / *String | Cognitive cost | **Keep** + docs |
| **F2c** | No ensure+decode `GetJson` → `TJsonValue` | App reimplements parse | **Deferred** |
| **F2d** | `NewHttpServer` → Default RW=0 | Copy-paste hang risk | **Keep** + Production examples |
| **F2e** | Cancel ~50 ms slices | Latency residual | **Residual-honest** |
| **F2f** | WS dial/handshake budgets Default 30000 | Production discipline | **Closed** (landed) |
| **F2g** | WS no `CancelToken` on options / mid-frame cancel | Long-lived WS cancel weaker | **P2 Implement** |

### F3 — Call consistency

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F3a** | H1/H2 ConnectTimeout + cancel wire | Aligned | **Closed** |
| **F3b** | WS timed dial + handshake deadline | Aligned with client shape | **Closed** |
| **F3c** | Public construction → `hekArgument` (no raise EArgumentError in prod) | Good | **Closed** |
| **F3d** | Create **318** vs CreateOp **19** | Structured ops incomplete | **P2** (hot-path only) |
| **F3e** | Post-handshake WS clears deadlines; no cancel token | Session cancel gap | **P2** (= F2g) |
| **F3f** | Stream/writer progress faults use `EIOError` (23 sites) | Kind taxonomy split | **Keep** (I/O layer) or soft-doc |

### F4 — Error message quality

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F4a** | Client status/redirect/download: `METHOD url` + CreateOp on redirect/download | Ops-friendly | **Closed** enough |
| **F4b** | Parser/HPACK/middleware mostly bare Create | Metrics by Op incomplete | **P2** hot-path / **Deferred** Op-all |
| **F4c** | Transport wrap Op=`transport`; WS wrap Op=`websocket` | Good | **Closed** |

### F5 — Boundary conditions

| Capability | H1 | H2 | WebSocket client | Status |
|------------|----|----|------------------|--------|
| OS dial timeout | Yes | Yes | Yes (Default 30s) | **Landed** |
| Mid-read cancel | Yes | Yes | **No** token wire | **WS P2** |
| Live dial e2e | Yes (client) | Unit/source only | Yes | **H2 live P2 optional** |
| Default client Timeout | 30s | 30s | 30s handshake | OK |
| Default server RW | 0 / Production 30s | same | n/a | Honest Keep |
| HTTPS CONNECT | No | No | n/a | **Deferred** |
| Cookie full PSL | SiteKey approx | n/a | n/a | **Deferred** |
| Retry-After | No | No | n/a | **Deferred** |

### F6 — Test coverage

| Area | Evidence | Gap |
|------|----------|-----|
| Client | ~226 tests incl. live dial + mid-read cancel | Strong |
| H2 | fake dial/cancel + source contracts + TLS re-arm | **No live H2 dial hang e2e** |
| WS client | echo + Default + source + live dial | No mid-frame cancel test |
| Contract / registry | 31 + H3 honesty | Strong |
| Isolation | 0 banned RTL `uses` | Clean |
| Docs inventory | API_COVERAGE still says “cycle-5 uncommitted→land” | **Docs-rot P2** |

### F7 — Perf / memory safety

- Request body close, redirect release, H2 `ClearCancelToken` on pool return: sound.
- Cancel slice polling: residual syscall cost under cancel — acceptable.
- Prior focused gates (landing candidate): heaptrc **0 unfreed** on client/h2/ws/contract.

### F8 — FPC RTL isolation

| Scope | Result |
|-------|--------|
| `core/src/nextpas.core.http*.pas` | **0** banned RTL units in `uses` |
| `core/tests/nextpas.core.http` | Clean (`System.Copy` only; not unit import) |
| `core/examples/nextpas.core.http` | Clean |
| `EArgumentError` | Catch/compat only (`HttpErrorIsUserError`); no prod raise sites |
| Note | `test_http_h2_session` fake stream raises `EArgumentError` (test-local; low) |

### F9 — Process / land hygiene (cycle-7)

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F9a** | cycle-5 path-limited land on main | Process risk closed | **Closed** |
| **F9b** | API_COVERAGE cycle-6 “Open residual: uncommitted→land” stale | Inventory truth rot | **P2 docs** |
| **F9c** | origin/main may lag local main | Remote not part of this assess | Out of scope |

---

## Risk

| ID | Risk | Severity | Likelihood | Notes |
|----|------|----------|------------|-------|
| **R1** | Long-lived WS cannot cancel mid-frame | Medium | Medium for chat/stream | F2g |
| **R2** | H2 dial regression only source-contract | Low–Medium | Low | F6 |
| **R3** | bare `NewHttpServer` unbounded RW | Medium | Medium copy-paste | F2d Keep |
| **R4** | Cancel-only without Timeout waits ~slice | Medium | Low if defaults used | F2e |
| **R5** | Deferred CONNECT/PSL/Retry-After | Medium niche | Low general | Deferred |
| **R6** | Sparse CreateOp outside hot paths | Low | Medium ops | F3d |
| **R7** | Docs inventory lag after land | Low | High until fix | F9b |

**Overall risk**: **Low**.

---

## Priority

| ID | Item | Pri | Disposition |
|----|------|-----|-------------|
| P2-1 | WS optional `CancelToken` + mid-frame cancel wire (or honest non-support doc) | P2 | **Implement** or **Honest-doc** |
| P2-2 | Optional H2 live dial-timeout e2e (backlog-full) | P2 | **Implement** if stable |
| P2-3 | Bounded CreateOp on remaining client Send failure sites only | P2 | **Implement** if low blast |
| P2-4 | Refresh API_COVERAGE / GOAL_TREE cycle-6 residual → landed | P2 | **Docs** |
| P2-d | CONNECT / Retry-After / full PSL / Response metadata / GetJson decode / Op-all | P2–P3 | **Deferred** |
| P3 | H3 / QUIC | P3 | **Non-goal** |
| Res | ~50 ms cancel slice | — | **Residual-honest** |
| Keep | Server Default RW=0; JSON dual layer; EIOError on stream progress | — | **Keep** |

**No P0/P1 open** on current main-absorbed tree.

---

## Go / Rust gap matrix

| Area | nextpas (cycle-7) | Go / Rust bar | Gap |
|------|-------------------|---------------|-----|
| HTTP connect timeout | H1/H2 OS dial + first-write | Dialer / connect_timeout | **Closed** |
| HTTP cancel | mid-read slices H1/H2 | context / Drop | Latency honesty only |
| Fluent connect timeout | `WithConnectTimeout` | reqwest builder | **Closed** |
| WebSocket dial timeout | Default 30s timed dial | Dialer / connect timeout | **Closed** |
| WebSocket cancel | No token wire | context cancel common | **Open P2** |
| Error typing | `EHttpError.Kind` + partial Op | typed / chained | Op sparse |
| Proxy HTTPS | plain HTTP only | CONNECT common | Deferred |
| Cookie PSL | SiteKey approx | publicsuffix | Deferred |
| JSON ensure+decode | ensure string only | `.json()` / serde | Deferred |
| Live e2e dial | H1+WS yes; H2 unit | often integration | H2 thin |
| Isolation dual-compiler | hard rule | N/A (single toolchain) | **Stronger than peers** |

---

## Next Steps

1. **Research report** (root cause + peer fix strategies) — no code.
2. **Fix plan** (milestones, deps, gates) — no code until user confirm.
3. **User confirmation** before production implementation.
4. Prefer **small Wave B**: docs truth (P2-4) + optional P2-1/2/3; leave Deferred product alone.

---

## Evidence anchors

| Claim | Anchor |
|-------|--------|
| http HEAD | `a792bf213` |
| main has cycle-5 | `7acb92962` ancestor of main |
| Create/CreateOp | 318 / 19 across `nextpas.core.http*.pas` |
| Banned RTL uses | 0 (scripted inventory) |
| WS CancelToken | 0 matches in `websocket.pas` |
| Live e2e | `test_http_client` backlog + hold; `test_http_websocket_client` backlog |
| Gates | 35 suites in `core/tests/nextpas.core.http/Makefile` |
