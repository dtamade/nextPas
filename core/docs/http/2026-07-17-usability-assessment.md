# Usability Assessment: nextpas.core.http

**Kind**: review / inventory (drives residual research + fix; this file is assessment, not implementation)
**Module**: `nextpas.core.http` (L3)
**Baseline assessed**: `http` @ wave-6 land `66b6daf2a` (pre residual worktree fixes)
**Post-fix residual score** (same tree after residual implement): see §7
**Comparator**: Go `net/http` + common client patterns; Rust `reqwest` / hyper-shaped stacks
**Constraint**: dual-compiler isolation; no FPC RTL in production http paths

---

## Summary

| Metric | Pre-residual (wave-6) | Post-residual (this worktree) |
|--------|----------------------|-------------------------------|
| **Usability score** | **89 / 100** | **94 / 100** |
| **Overall risk** | **Medium** | **Low–Medium** (net seams only) |
| **Primary residual risk** | OS dial hang; cancel without Timeout | Unchanged Blocked on net |
| **HTTP-owned findings** | Fixable P0–P2 open | Closed in tree |
| **Net-owned** | Blocked | Still Blocked (honest) |
| **Large features** | Deferred | Still Deferred |

**One-line judgment**: Facade, router/middleware composition, H1/H2 client-server, and body ownership are production-usable and close to Go/Rust ergonomics on the happy path. Residual gaps after wave-6 were **production Timeout discipline**, **hekArgument residual on server/ws/middleware**, **error method/URL context**, **ensure-2xx method symmetry**, and **API_COVERAGE historical pollution**. Net dial timeout and true mid-read cancel remain **Blocked** on net — not faked in http.

**Dimension scores (pre → post residual)**

| Dimension | Pre | Post | Notes |
|-----------|-----|------|-------|
| Interface design | 95 | 95 | Small interfaces; builder + Send; no expand-by-default |
| API usability | 84 | 93 | Timeout example + PostString family |
| Call consistency | 82 | 94 | hekArgument residual closed; free-fn/method parity |
| Error message quality | 80 | 92 | METHOD url: detail on client status/redirect/download |
| Boundary conditions | 78 | 82 | Honesty improved; OS dial still Blocked |
| Test coverage | 90 | 93 | Error-context + method-symmetry gates |
| Perf / memory safety | 90 | 90 | Ownership solid; no new perf claim |

---

## Findings

### F1 — Interface design (strong)

- **Observation**: `IHttpHandler` / `IHttpClient` / `IHttpTransport` seams; router + middleware chain; `THttpRequestBuilder` recommended entry; version registry for H1/H2.
- **Go/Rust**: Aligns with `http.Handler` / `http.Client` and reqwest-style builders.
- **Gap**: None material for this assessment cycle.
- **Score contribution**: high positive.

### F2 — API usability

- **Pre**: Examples used bare `NewHttpClient` (unbounded Timeout); free-fn ensure-2xx (`HttpPostString`…) not mirrored on `IHttpClient` except GetString/GetBytes; ConnectTimeout name still easy to misread despite honesty docs.
- **Post**: Production docs + example `WithTimeout(30000)`; method symmetry for Post/Put/Patch/DeleteString.
- **Go/Rust gap closed**: closer to `Client.Timeout` templates and `.text()`-style helpers.
- **Residual gap**: no OS dial timeout field (Blocked, correct).

### F3 — Call consistency

- **Pre**: message/form/headers/stream already `hekArgument` (wave-6); **server / websocket / middleware** still bare `EArgumentError` on construction.
- **Post**: those public construction preconditions use `EHttpError(hekArgument)`.
- **Go/Rust**: single error type path for caller `except on E: EHttpError`.

### F4 — Error message quality

- **Pre**: `HttpEnsureSuccess` and many redirect/status paths omitted method/URL; download had URL but inconsistent shape.
- **Post**: `FormatHttpClientError` / status helper; free-fns pass method+URL into EnsureSuccess; redirect/nil-transport/download normalized to `METHOD url: detail`.
- **Go/Rust gap**: still string-first (no structured `Op`+URL fields on all paths); acceptable without API expand.

### F5 — Boundary conditions

- **Blocked (net)**: OS `connect()` unbounded; cancel does not interrupt blocked `Read`.
- **Deferred**: HTTPS CONNECT, Retry-After policy, full PSL, Response metadata expand.
- **Honesty**: CONTRACT §2.2.0a + Production defaults require Timeout pairing.

### F6 — Test coverage

- Thick client/server/middleware/websocket/contract gates.
- Residual added: EnsureSuccess context, GetString/PostString method+URL on failure, IHttpClient Post/Put/Patch/DeleteString.

### F7 — Perf / memory safety

- Body ownership (request close, response release/drain, download temp rename) solid.
- No new residual for this cycle; URL path micro cost known in BENCHMARKS.

---

## Risk

| ID | Risk | Severity | Likelihood | Residual after residual fix |
|----|------|----------|------------|------------------------------|
| **R1** | OS `connect()` hang (no dial timeout) | High | Medium (bad networks) | **Blocked** on net — hang possible |
| **R2** | Cancel alone does not bound wait | High | Medium if Timeout omitted | **Mitigated** by P0 docs/examples; **Blocked** for mid-read interrupt |
| **R3** | Dual exception types | Medium | Medium | **Closed** for public construction residual |
| **R4** | HTTPS CONNECT missing | Medium | Niche | **Deferred** |
| **R5** | SiteKey ≠ full PSL | Low–Medium | Cookie edge | **Deferred** / approx remains |
| **R6** | Errors without method/URL | Medium-low | Ops debug | **Closed** on planned client paths |
| **R7** | free-fn vs method asymmetry | Low | Ergonomics | **Closed** Post/Put/Patch/DeleteString |
| **R8** | H3 missing | Low | Product | Non-goal |
| **R9** | API_COVERAGE historical as live | Low | Docs drift | **Closed** current-truth + archive |

**Overall risk (post residual)**: **Low–Medium** — remaining high-severity items are explicitly net-Blocked, not silent product lies.

---

## Priority

| ID | Item | Priority | Disposition |
|----|------|----------|-------------|
| P0-1 | Timeout/cancel production discipline | P0 | **Implement** (done in residual) |
| P1-1 | OS dial timeout | P1 | **Blocked** (net) |
| P1-2 | Mid-read cancel interrupt | P1 | **Blocked** (net+http) |
| P1-3 | server/ws/middleware → hekArgument | P1 | **Implement** (done) |
| P1-4 | Client error method/URL context | P1 | **Implement** (done) |
| P1-5 | API_COVERAGE current-truth | P1 | **Implement** (done) |
| P2-1 | ensure-2xx method symmetry | P2 | **Implement** (done) |
| P2-2 | HTTPS CONNECT | P2 | **Deferred** |
| P2-3 | Retry-After | P2 | **Deferred** |
| P2-4 | Full PSL / Response metadata | P2 | **Deferred** |
| P3 | H3 / async | P3 | **Non-goal** |

---

## Next Steps

1. **Research** — `2026-07-17-usability-residual-research.md` (root cause + Go/Rust + Blocked/Deferred table).
2. **Plan** — `2026-07-17-usability-residual-fix-plan.md` (M0–M7).
3. **Implement** http-owned P0/P1/P2 only; keep net Blocked and feature Deferred.
4. **Verify** focused gates + hygiene; capture evidence under implementer scratch.
5. **Future (out of residual run)**: net timed connect + interruptible read; CONNECT tunnel; optional PSL.

---

## Rust / Go gap path (condensed)

| Area | Go | Rust (reqwest) | nextpas.core.http | Path |
|------|----|----------------|-------------------|------|
| Client timeout | `Client.Timeout` | `timeout` / `connect_timeout` | `Timeout` + post-dial `ConnectTimeout` | Keep honesty; net for real dial |
| Cancel | `context.Context` | cancel/`Drop` | cooperative + Timeout | Blocked mid-read until net |
| Errors | typed status helpers | `Error` kinds | `EHttpError.Kind` + message prefix | optional structured URL fields later |
| ensure-2xx body | manual / helpers | `.text()/.json()` | free-fn + methods | done for string family |
| Cookie SameSite | jar packages | cookie_store | approx SiteKey | defer full PSL |
| Proxy HTTPS | CONNECT | proxies feature | absolute-form only | Deferred CONNECT |

---

## §7 Post-residual score card (worktree after fix)

| Metric | Value |
|--------|-------|
| Usability score | **94 / 100** |
| Risk | **Low–Medium** |
| Open implementable http findings from this assessment | **0** |
| Open Blocked | R1, R2 (net) |
| Open Deferred | CONNECT, Retry-After, PSL, Response metadata |

**Why not 100**: honest net Blocked (dial hang, cancel lag) and deliberate Deferred features subtract ~6 points against Go/Rust production ceilings.
