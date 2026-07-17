# Usability Assessment: nextpas.core.http (cycle-3)

**Kind**: review / inventory (read-only assessment; drives research + fix plan)
**Module**: `nextpas.core.http` (L3)
**Baseline**: `http` / `main` @ `82ecf1f3e`
  (`fix(http): post-residual usability — SSE hekArgument, Production timeouts`)
**Comparator**: Go `net/http` + common client patterns; Rust `reqwest` / hyper-shaped stacks
**Constraint**: dual-compiler isolation; only `nextpas.core.system` may `uses` FPC RTL;
  http production sources/tests/examples must not direct-`uses` FPC RTL

---

## Summary

| Metric | Value |
|--------|-------|
| **Usability score** | **93 / 100** (pre-fix) → **96 / 100** (post cycle-3 implement) |
| **Overall risk** | **Low–Medium** (high-severity items are net-Blocked, honest) |
| **HTTP-owned open findings** | **Closed in cycle-3** (I1–I6); Blocked/Deferred remain honest |
| **Blocked (net)** | OS dial timeout; true mid-read cancel |
| **Deferred / Non-goal** | CONNECT / Retry-After / full PSL / Response metadata / JSON ensure-decode / Op-everywhere / H3 |

**One-line judgment**: After wave-6 + residual + post-residual, the public facade is production-usable
and close to Go/Rust happy-path ergonomics. Remaining http-owned gaps are **consistency residuals**
(transport-level dual exceptions, redirect/download message context holes, convenience factory
timeout template, doc drift / outdated test expectations)—not architectural redesign.

### Dimension scores

| Dimension | Score | Notes |
|-----------|------:|-------|
| Interface design | 95 | Small interfaces; builder + Send; version registry; freeze-by-default |
| API usability | 92 | Production helpers exist; RequestArena factory still on Default RW=0 |
| Call consistency | 88 | Public construction → hekArgument; **impl transport seams still EArgumentError** |
| Error message quality | 90 | METHOD url on main client paths; redirect-resolve / download publish holes |
| Boundary conditions | 82 | Honesty good; OS dial + mid-read cancel Blocked on net |
| Test coverage | 90 | Thick gates; some expect bare `EArgumentError` on migrated/impl paths |
| Perf / memory safety | 90 | Body ownership solid; no new leak class found |

---

## Findings

### F1 — Interface design (strong)

- `IHttpHandler` / `IHttpClient` / transport seams; router + middleware; `THttpRequestBuilder`.
- H1/H2 registry; H3 seam honest (no fake factory).
- **Gap**: none material this cycle.

### F2 — API usability

| Item | Observation | Impact |
|------|-------------|--------|
| **F2a** | `NewHttpServerWithRequestArena` no-options overloads use `THttpServerOptions.Default.WithRequestArena` (RW=0) while examples promote `Production` | Convenience path invites unbounded RW in “arena-ready” servers |
| **F2b** | README Quick Start still lists hello server as `Default`; code uses `Production.WithRequestArena` | Doc→code drift |
| **F2c** | `IHttpClient.PostJson` returns raw response; free `HttpPostJson` ensure-2xx | Intentional dual layer; not a bug if docs honest |

### F3 — Call consistency

| Item | Observation | Impact |
|------|-------------|--------|
| **F3a** | Public message/client/server/ws/middleware/SSE preconditions: `EHttpError(hekArgument)` | Good |
| **F3b** | `impl.h1` / `impl.h2` / TLS stream still `raise EArgumentError` on nil conn/req/handler | Advanced transport callers need dual `except`; tests encode bare type |
| **F3c** | `test_http_h1fast` expects `EArgumentError` for nil ForEach callback; public headers path uses hekArgument | Expectation drift |

### F4 — Error message quality

| Item | Observation | Impact |
|------|-------------|--------|
| **F4a** | Status / too-many-redirects / missing Location use `FormatHttpClientError` | Good |
| **F4b** | `ResolveRedirectUrl` / `ParseRedirectAuthorityUrl` raise bare hekRedirect strings (no METHOD url) | Ops harder to correlate |
| **F4c** | Download mkdir/publish `CreateOp` messages omit `GET url` prefix | Inconsistent with download status path |

### F5 — Boundary conditions

| Item | Disposition |
|------|-------------|
| OS `connect()` dial timeout | **Blocked** (net) — `ConnectTimeout` honest = post-dial first-write |
| Mid-read cancel interrupt | **Blocked** (net+http) — cooperative checkpoints; pair with Timeout |
| Default server RW=0 | Documented; Production template exists |
| ShutdownTimeout Default=0 | Compat; document-only this cycle |

### F6 — Test coverage

- Strong client/server/contract/middleware gates.
- Residual: update transport nil-input tests and helpers that still assert bare `EArgumentError`.
- Production timeout values locked in `test_http_server`.

### F7 — Perf / memory safety

- Request body close, redirect body release, download temp rename: sound.
- No new http-owned memory-safety finding this cycle.

### F8 — FPC RTL isolation (compiler independence)

| Scope | Result |
|-------|--------|
| `core/src/nextpas.core.http*.pas` | No direct `uses SysUtils/Classes/...` |
| `core/tests/nextpas.core.http` | No SysUtils uses in http test sources (framework error types only) |
| `core/examples/nextpas.core.http` | Clean of FPC RTL uses |
| Note | `nextpas.core.exception` may route `Exception` via SysUtils under FPC; http does not own that boundary |

---

## Risk

| ID | Risk | Severity | Likelihood | Notes |
|----|------|----------|------------|-------|
| **R1** | OS dial hang | High | Medium | Blocked net |
| **R2** | Cancel without Timeout hangs | High | Medium if misconfigured | Mitigated by docs/examples; Blocked mid-read |
| **R3** | Transport dual exception | Medium | Low–Medium (advanced APIs) | Implement F3b |
| **R4** | RequestArena factory unbounded RW | Medium | Medium if copy-paste | Implement F2a |
| **R5** | Redirect/download context holes | Low–Medium | Debug paths | Implement F4b/F4c |
| **R6** | Doc drift | Low | Medium | Implement F2b + archive wording |
| **R7** | Deferred product gaps (CONNECT/PSL/…) | Medium niche | Low | Deferred |

**Overall risk**: **Low–Medium**.

---

## Priority

| ID | Item | Pri | Disposition |
|----|------|-----|-------------|
| P1-1 | Transport public preconditions → hekArgument | P1 | **Implement** |
| P1-2 | `NewHttpServerWithRequestArena` → Production base | P1 | **Implement** |
| P1-3 | Redirect resolve + download publish error context | P1 | **Implement** |
| P2-1 | README / GOAL_TREE / API_COVERAGE truth | P2 | **Implement** |
| P2-2 | Test expectations (EArgumentError → hekArgument) | P2 | **Implement** (with P1-1) |
| P1-net | OS dial / mid-read cancel | P1 | **Blocked** |
| P2-d | CONNECT / Retry-After / PSL / metadata / JSON decode / Op-all | P2 | **Deferred** |
| P3 | H3 | P3 | **Non-goal** |

---

## Go / Rust gap matrix

| Area | nextpas.core.http @ 82ecf1f3e | Go / Rust bar | Gap |
|------|-------------------------------|---------------|-----|
| Happy-path client | Get/Post + *String ensure-2xx | `Get` / `.text()` | Small (JSON decode ensure deferred) |
| Timeout template | Client Default 30s; Server Production | `Client.Timeout`; server often app-set | Close if Production used |
| Dial timeout | Blocked | `DialContext` / connect timeout | Real gap (net) |
| Cancel | Cooperative + Timeout | context cancel | Real gap mid-read |
| Error type | EHttpError Kind | typed status / error chain | Close after transport hekArgument |
| Cookie PSL | SiteKey approx | publicsuffix | Deferred |
| HTTPS proxy | plain HTTP only | CONNECT common | Deferred |

---

## Next Steps

1. Research report freezes dispositions (Implement / Blocked / Deferred).
2. Fix plan milestones + verification gates.
3. Single implementation pass (no half-fixes).
4. Focused gates + Ready report.
