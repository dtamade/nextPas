# Research: HTTP post-residual usability findings (post-`feec31b45`)

**Status**: complete (research before code)
**Baseline**: `http` / `main` @ `feec31b45`
**Assessment source**: high-standard usability report (score 92/100; F1–F8 / R1–R9 / P0–P3)
**Constraint**: dual-compiler; no FPC RTL in http; net Blocked stays honest

---

## 1. Inventory vs tree

| ID | Assessment finding | Tree fact @ feec31b45 | Root cause | Impact | Go/Rust analogue | Disposition |
|----|-------------------|----------------------|------------|--------|------------------|-------------|
| **I1** | SSE public preconditions use bare `EArgumentError` | 5× `raise EArgumentError` in `http.sse` (nil writer, field injection, negative retry) | Residual hekArgument migration covered message/client/server/ws/middleware but **missed SSE** | Callers using only `except on E: EHttpError` miss SSE arg faults; dual catch required | Go: typed errors / status; Rust: single `Error` chain | **Implement** |
| **I2** | Server default Read/Write timeout = 0 (unbounded) | `THttpServerOptions.Default`: Read=0, Write=0, Idle=30000 | Backward-compat Default; production discipline only on client (Default Timeout=30s) | Slowloris / hung writers if app copies Default blindly | Go `Server.ReadTimeout`/`WriteTimeout` often app-set (default 0); production templates set finite | **Implement** (non-breaking: `Production` helper + docs/examples; keep `Default` RW=0) |
| **I3** | Docs still claim bare `EArgumentError` for migrated public paths | README lines for Send(nil), body helpers, options; API_COVERAGE historical/live mix | Docs lag residual code (`hekArgument` already live) | Wrong mental model; trust erosion | N/A | **Implement** (docs current-truth) |
| **I4** | `ConnectTimeout` name ≠ OS dial | Named post-dial first-write; CONTRACT §2.2.0a honest | Historical option name | Misconfig risk | Go DialContext / reqwest `connect_timeout` | **Implement** (reinforce honesty only; no rename this cycle) |
| **I5** | OS dial hang | No timed connect in net | net/platform | High severity hang | Go/Rust true dial timeout | **Blocked** (net) |
| **I6** | Mid-read cancel | Cooperative checkpoints only | net+http transport | Cancel alone unbounded without Timeout | context cancel / Drop | **Blocked** (net+http) |
| **I7** | HTTPS CONNECT | Plain HTTP proxy only | Scope | Niche proxy HTTPS | CONNECT common | **Deferred** |
| **I8** | Full PSL / SiteKey approx | Two-label SiteKey | Scope/cost | Cookie edge | publicsuffix lists | **Deferred** |
| **I9** | Retry-After policy on client retry | Not implemented as 429-aware policy | Scope | Ops retry quality | custom middleware | **Deferred** |
| **I10** | Response metadata thin | StatusCode/Headers/Body only | Surface freeze | Ergonomics | Go Response fields | **Deferred** |
| **I11** | ensure-2xx JSON decode | PostJson returns response | Surface freeze | Ergonomics | reqwest `.json()` | **Deferred** |
| **I12** | Structured Op/URL on every error | Partial CreateOp + message prefix | Incremental | Machine parse | url.Error / reqwest url() | **Deferred** |
| **I13** | H3 | Seam only | QUIC missing | Product | h3 stacks | **Non-goal** |

---

## 2. Root-cause detail (Implement items)

### I1 SSE dual exception

- Public SSE API is part of facade (`StartSSE`, `ISSEEventWriter`).
- Wave residual migrated construction preconditions to `EHttpError(hekArgument)` for server/ws/middleware; SSE unit still raises framework `EArgumentError` from `nextpas.core.errors` / exception hierarchy.
- Tests (`TestSSEEventWriterRejectsFieldInjection`) **encode** the old type (`on E: EArgumentError`).
- Fix: raise `EHttpError.Create(hekArgument, …)`; update tests to assert `E.Kind = hekArgument`. Protocol/IO paths stay `hekProtocol` / `EIOError`.

### I2 Server RW timeout discipline

- Changing `Default.ReadTimeout/WriteTimeout` from 0 → finite is **behavior-breaking** for tests and long-poll/SSE demos that rely on unbounded read/write under IdleTimeout.
- Client already has production-friendly `Default.Timeout=30000`.
- Strategy (chosen):
  1. Add `THttpServerOptions.Production` = Default + finite Read/Write (30000 ms), same MaxHeader/MaxBody/Idle.
  2. Document: production must use `Production` or explicit `WithReadTimeout`/`WithWriteTimeout`; `Default` RW=0 is for tests/special tools.
  3. Examples (`http_hello_server`, `http_websocket_echo_demo`) switch to Production or explicit finite RW; `http_server_options_demo` already sets WriteTimeout — add ReadTimeout.
  4. Focused test locks Production values and that Default remains RW=0 (compat).

### I3 Doc drift

- Correct README / CONTRACT current-truth / API_COVERAGE current-conclusion + matrix cells that still say bare `EArgumentError` for Send(nil), body helpers, client/server negative options, SetBasicAuth, HttpWriteResponseString when code uses `hekArgument`.
- Historical archive may retain past wording only if clearly non-live.

### I4 ConnectTimeout honesty

- No API rename (breaking). Reinforce README/CONTRACT production section; keep §2.2.0a Blocked table.

---

## 3. Risk assessment

| Change | Risk | Mitigation |
|--------|------|------------|
| SSE hekArgument | Low — type change for failure path | Update middleware SSE tests; HttpErrorIsUserError still true for old EArgumentError if any |
| Production helper | Low — additive | Default unchanged |
| Example timeouts | Low | Demos still complete under 30s RW |
| Doc-only | None | Source-contract optional |

**Do not implement** I5–I6 in http (fake dial/cancel). **Do not implement** I7–I13 as stubs.

---

## 4. Fix strategy summary

| Disposition | Items | Action |
|-------------|-------|--------|
| **Implement** | I1, I2, I3, I4 | Code + tests + docs in one pass |
| **Blocked** | I5, I6 | CONTRACT table only |
| **Deferred** | I7–I12 | Research table + residual plan |
| **Non-goal** | I13 | Unchanged |

---

## 5. Dependencies

```
I1 (SSE) ── independent
I2 (Production + examples) ── independent of I1
I3 (docs) ── after I1/I2 so wording matches code
I4 (ConnectTimeout docs) ── with I3
I5/I6 Blocked docs ── with I3
```

No net code required for this cycle.
