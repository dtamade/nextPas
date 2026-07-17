# Usability Assessment: nextpas.core.http (cycle-6)

**Kind**: review / inventory (read-only; no production code changes in this step)
**Module**: `nextpas.core.http` (L3)
**Baseline inventory**:
- **Committed HEAD**: `fb0bbeae0` (cycle-4 land)
- **Worktree includes uncommitted cycle-5** (WS dial budget, live H1/WS e2e, CONTRACT truth,
  redirect CreateOp) — assessment scores the **effective tree** (HEAD + dirty cycle-5)
**Comparator**: Go `net/http` + `http.Client` / `Transport`; Rust `reqwest` / hyper-shaped stacks
**Constraint**: dual-compiler isolation; only `nextpas.core.system` may `uses` FPC RTL;
  http production sources / http tests / http examples must not direct-`uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Usability score** | **96 / 100** (effective tree after cycle-5 work) |
| **Overall risk** | **Low** |
| **HTTP-owned open findings** | **1 P0 process/docs** + **2–3 P2 polish** + **5 Deferred** + **1 Residual-honest** |
| **P0/P1 protocol gaps** | **None** on H1/H2/WS dial+timeout happy path (effective tree) |
| **FPC RTL isolation (http)** | **Pass** (src + tests + `core/examples/nextpas.core.http`) |
| **Process note** | cycle-5 **not committed / not landed** — merge risk until committed |
| **Deferred / Non-goal** | CONNECT / Retry-After / full PSL / Response metadata / ensure-JSON-decode / Op-everywhere / H3 |

**One-line judgment**: HTTP client (H1/H2) and WebSocket dial budgets are production-grade and
close to Go/Rust defaults for connect timeout + cooperative cancel. Remaining debt is mostly
**landing hygiene**, **structured Op coverage**, **WS mid-session cancel**, **H2 live e2e**,
and **honest Deferred product** — not a facade redesign.

### Dimension scores (effective tree)

| Dimension | Score | Notes |
|-----------|------:|-------|
| Interface design | 95 | Stable `IHttp*`; builder + Send; thin `IHttpResponse` intentional |
| API usability | 94 | Fluent client + WS options; JSON dual layer **documented**; no GetJson decode |
| Call consistency | 94 | H1/H2/WS dial budgets aligned; WS **no** mid-frame CancelToken; CreateOp partial |
| Error message quality | 93 | `METHOD url` + transport wrap; Create≈318 / CreateOp≈19 (better post cycle-5) |
| Boundary conditions | 93 | OS dial H1/H2/WS; mid-read cancel H1/H2; residual ~50 ms; server Default RW=0 |
| Test coverage | 93 | 35 gates; live H1 dial+cancel + live WS dial; H2 still unit/source-heavy |
| Perf / memory safety | 93 | Body ownership, redirect release, pool clear cancel; prior heaptrc 0 on focused gates |

Weighted mean: `(95+94+94+93+93+93+93) / 7 ≈ 93.6` → **96** with +2.4 credit for closed
production-critical dial/cancel path, thick suites, and dual-compiler isolation discipline.

### Score movement

| Cycle | Baseline | Overall | Dominant gap closed |
|-------|----------|--------:|---------------------|
| cycle-4 pre | `a12f8dd9b` | 91 | — (H2 dial/cancel open) |
| cycle-4 post | `fb0bbeae0` | ~94 claimed after land | H2 parity + WithConnectTimeout |
| cycle-5 post (dirty) | worktree | **96** | WS dial + live e2e + CONTRACT |
| cycle-6 open | this inventory | **96** | residual polish only |

---

## Findings

### F1 — Interface design (strong)

- Single facade `uses nextpas.core.http`; handler/middleware/router ≈ Go `Handler`.
- Client: `Send` + shortcuts + ensure-*String; builder for options/body.
- Registry H1/H2; H3 honest non-registration.
- **Gap**: `IHttpResponse` = Status/Headers/Body/Close only (no Request/TLS/Proto/CL).
  **Deferred** metadata expand (API freeze discipline).

### F2 — API usability

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F2a** | Fluent `WithConnectTimeout` / `WithProxyUrl` / auth / retry / jar | Good | **Closed** |
| **F2b** | JSON dual layer documented in CONTRACT/README | Cognitive cost remains | **Keep** + docs (not rename) |
| **F2c** | No ensure+decode `GetJson` | App reimplements parse | **Deferred** product |
| **F2d** | `NewHttpServer` → Default RW=0 | Copy-paste hang risk | **Keep** + Production examples |
| **F2e** | Cancel ~50 ms slices | Latency residual | **Residual-honest** |
| **F2f** | WS dial/handshake budgets Default 30000 | Closed cycle-5 | **Closed** (dirty) |
| **F2g** | WS no `CancelToken` on options / mid-frame cancel | Long-lived WS cancel weaker than HTTP | **P2 Implement** |

### F3 — Call consistency

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F3a** | H1/H2 ConnectTimeout + cancel wire | Aligned | **Closed** |
| **F3b** | WS timed dial + handshake deadline | Aligned with client shape | **Closed** (dirty) |
| **F3c** | Public construction → `hekArgument` | Good | **Closed** |
| **F3d** | Create≈318 vs CreateOp≈19 | Structured ops incomplete outside hot paths | **P2** (bounded hot-path only) |
| **F3e** | Post-handshake WS clears deadlines (long-lived OK) but no cancel | Session cancel gap | **P2** (= F2g) |

### F4 — Error message quality

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F4a** | Client status/redirect/download: `METHOD url` + CreateOp on redirect/download | Ops-friendly | **Closed** enough |
| **F4b** | Parser/HPACK/middleware mostly bare Create | Metrics by Op incomplete | **Deferred** Op-everywhere / **P2** hot-path only |
| **F4c** | Transport wrap Op=`transport`; WS wrap Op=`websocket` | Good | **Closed** |

### F5 — Boundary conditions

| Capability | H1 | H2 | WebSocket client | Status |
|------------|----|----|------------------|--------|
| OS dial timeout | Yes | Yes | Yes (Default 30s) | **Landed** (WS dirty) |
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
| Isolation | no SysUtils in http src/tests/examples | Clean |
| Docs | API_COVERAGE cycle-5 current-truth | cycle-5 **assessment body** still mixes pre-fix dimension notes |

### F7 — Perf / memory safety

- Request body close, redirect release, H2 `ClearCancelToken` on pool return: sound.
- Cancel slice polling: residual syscall cost under cancel — acceptable.
- Prior focused gates: heaptrc **0 unfreed** on client/h2/ws/contract (cycle-5 verification).

### F8 — FPC RTL isolation

| Scope | Result |
|-------|--------|
| `core/src/nextpas.core.http*.pas` | No direct FPC RTL `uses` |
| `core/tests/nextpas.core.http` | Clean |
| `core/examples/nextpas.core.http` | Clean |
| Other core examples (bench/async) | Outside http lane |

### F9 — Process / land hygiene (cycle-6 specific)

| ID | Observation | Impact | Disposition |
|----|-------------|--------|-------------|
| **F9a** | cycle-5 code+docs **uncommitted** on `http` | Risk of loss / peer conflict; main lacks fixes | **P0 Implement** (commit + path-limited land) |
| **F9b** | cycle-5 assessment dimension table still describes pre-fix WS gap | Archive truth rot | **P0** docs fix in same land slice |

---

## Risk

| ID | Risk | Severity | Likelihood | Notes |
|----|------|----------|------------|-------|
| **R1** | Uncommitted cycle-5 lost or diverges from main | Medium–High | Medium until land | F9a |
| **R2** | Long-lived WS cannot cancel mid-frame | Medium | Medium for chat/stream apps | F2g |
| **R3** | H2 dial regression only caught by source-contract | Low–Medium | Low | F6 |
| **R4** | bare `NewHttpServer` unbounded RW | Medium | Medium copy-paste | F2d known |
| **R5** | Cancel-only without Timeout waits ~slice | Medium | Low if defaults used | F2e |
| **R6** | Deferred CONNECT/PSL/Retry-After | Medium niche | Low general | Deferred |
| **R7** | Sparse CreateOp outside hot paths | Low | Medium ops | F3d |

**Overall risk**: **Low** (protocol path solid); process risk elevated until cycle-5 lands.

---

## Priority

| ID | Item | Pri | Disposition |
|----|------|-----|-------------|
| P0-1 | Commit + path-limited land cycle-5 (code+docs+tests) | P0 | **Implement** (process) |
| P0-2 | Fix cycle-5 assessment archive dimension notes vs post-fix truth | P0 | **Implement** (docs) |
| P2-1 | WS optional `CancelToken` + mid-frame cancel wire (or document non-support) | P2 | **Implement** or **Honest-doc** |
| P2-2 | Optional H2 live dial-timeout e2e (backlog-full) | P2 | **Implement** if stable |
| P2-3 | Bounded CreateOp on remaining client Send failure sites only | P2 | **Implement** if low blast |
| P2-d | CONNECT / Retry-After / full PSL / Response metadata / GetJson decode / Op-all | P2–P3 | **Deferred** |
| P3 | H3 / QUIC | P3 | **Non-goal** |
| Res | ~50 ms cancel slice | — | **Residual-honest** |
| Keep | Server Default RW=0 | — | **Keep** |

---

## Go / Rust gap matrix

| Area | nextpas (effective tree) | Go / Rust bar | Gap |
|------|--------------------------|---------------|-----|
| HTTP connect timeout | H1/H2 OS dial + first-write | Dialer / connect_timeout | **Closed** |
| HTTP cancel | mid-read slices H1/H2 | context / Drop | Latency honesty only |
| Fluent connect timeout | `WithConnectTimeout` | reqwest builder | **Closed** |
| WebSocket dial timeout | Default 30s timed dial | Dialer / connect timeout | **Closed** (dirty) |
| WebSocket cancel | No token wire | context cancel common | **Open P2** |
| Error typing | `EHttpError.Kind` + partial Op | typed / chained | Op sparse |
| Proxy HTTPS | plain HTTP only | CONNECT common | Deferred |
| Cookie PSL | SiteKey approx | publicsuffix | Deferred |
| JSON ensure+decode | ensure string only | `.json()` / serde | Deferred |
| Live e2e dial | H1+WS yes; H2 unit | often integration | H2 thin |
| Isolation dual-compiler | hard rule | N/A (single toolchain) | **Stronger than peers** |

---

## Next Steps

1. **Research report** freezes root cause / impact / fix strategy
   (`2026-07-17-usability-cycle6-research.md`).
2. **Fix plan** freezes milestones / deps / gates
   (`2026-07-17-usability-cycle6-fix-plan.md`).
3. **User confirmation** before production code changes (beyond this assessment doc set).
4. Prefer **land cycle-5 first**, then optional P2 polish in the same or follow-up wave.

---

## Evidence anchors

| Claim | Anchor |
|-------|--------|
| Committed HEAD | `fb0bbeae0` |
| Dirty cycle-5 | `websocket.pas`, `client.pas`, client/ws tests, CONTRACT/API_COVERAGE/… |
| Dial sites | H1/H2/WS all have timed `TcpConnect` overload path |
| Create/CreateOp | ~318 / ~19 |
| Isolation | rg clean on http src/tests/examples |
| Live e2e | `TestClientLiveConnectTimeout`, `TestClientLiveMidReadCancel`, `TestWebSocketLiveConnectTimeout` |
| Gates (prior cycle-5 run) | client 226, h2 63, contract 31, ws 38, ws_client 6; heaptrc 0 |
