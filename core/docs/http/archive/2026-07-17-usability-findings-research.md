# Research: HTTP usability-assessment findings (2026-07-17)

**Status**: complete (research before fix code)
**Baseline**: `http` @ wave-5 land (`2ee25370d` family)
**Assessment source**: post-wave-5 usability report (93/100; R1–R7 / P0–P3 / F1–F7)
**Constraint**: no FPC RTL in production http paths; dual-compiler isolation

---

## 1. Problem inventory (all assessment IDs)

### 1.1 Findings F1–F7 (quality dimensions)

| ID | Topic | Root cause | Impact surface | Fix strategy | Risk if unfixed | Go / Rust analogue |
|----|--------|------------|----------------|--------------|-----------------|--------------------|
| F1 | Interface design strong | N/A (positive) | Public facade | Preserve; no expand-by-default | Low | Go `Handler` / `Client`; `reqwest` builder |
| F2 | API usability friction | ConnectTimeout naming, cancel lag, proxy/cookie gaps | Client options, docs, jar, proxy | P0 honesty docs; P1 SameSite; P2 GetString; defer CONNECT | High misconfig | Go `Timeout`+`DialContext`; `reqwest` timeouts |
| F3 | Call consistency | Dual exception types; free-fn vs methods; doc history | message/form/headers + API_COVERAGE | Unify public preconditions to `EHttpError(hekArgument)`; doc archive | Medium | Single `error` / `Result` |
| F4 | Error message quality | Short strings; dual catch | Callers classifying errors | hekArgument migration enables `HttpErrorIsUserError` | Medium-low | `errors.As` / `reqwest::Error` |
| F5 | Boundary residual | OS dial blocking; cancel not on blocked read; SameSite store incomplete | net.tcp + h1 RoundTrip + cookie | Honest Blocked for net; SameSite in jar | High (R1/R2) | DialContext / connect timeout |
| F6 | Tests thick, some gaps | SameSite/client policy untested; dial untested | cookie + client gates | Add jar SameSite tests | Medium | — |
| F7 | Perf/memory ok | URL path slower; cancel may buffer | Known, out of this fix set for perf | No API expand; keep ownership | Low | — |

### 1.2 Risks R1–R7

| ID | Risk | Root cause | Impact surface | Fix strategy | Residual risk after fix | Go / Rust |
|----|------|------------|----------------|--------------|-------------------------|-----------|
| **R1** | `ConnectTimeout` name > semantics; OS `connect()` hangs | `NetTcpConnect` → blocking `platform_socket_connect` with **no** timeout; HTTP `ConnectTimeout` only budgets **post-dial first write** | `THttpClientOptions.ConnectTimeout`, H1 dial path, docs | **P0**: docs/comments honesty. **Net P1**: either implement timed dial in net + wire, or **Blocked** table (no fake OS timeout in http alone) | If Blocked: hang still possible until net lands | Go `DialContext`; `reqwest` connect timeout |
| **R2** | Cancel does not interrupt blocked socket read | Cancel is cooperative checkpoints; `TTcpStream.Read` blocks until SO_RCVTIMEO/deadline | H1 RoundTrip read, client Send | **P0** document checkpoints. **Net P1**: interruptible read or **Blocked** (require `Timeout` as contract) | Blocked: must pair cancel with Timeout | `context` cancel / async cancel |
| **R3** | No HTTPS CONNECT / proxy auth | Wave-4/5 scope: plain HTTP absolute-form only | `WithProxyUrl`, H1 absolute-form | **Defer P2** with rationale (enterprise niche; large TLS tunnel slice) | Medium for enterprise egress | Go CONNECT; `reqwest` proxy |
| **R4** | Cookie SameSite/PSL incomplete | Jar stores Domain/Path/Secure/Expires; **no SameSite parse/enforce** | `cookie.pas` jar | **P1**: parse SameSite; store rules; send policy without full PSL (see §3) | No PSL: approximate site | Browser / cookie_store |
| **R5** | Dual exceptions `EArgumentError` vs `EHttpError` | Historical preconditions used RTL-style `EArgumentError` | message, form, headers, stream, … | **P1**: public message/form/headers (+ stream helpers used from facade) → `EHttpError(hekArgument)` | Internal impl may still use EArgumentError | Unified error type |
| **R6** | H3 / h2c Upgrade missing | Honest non-goal | registry | **No fix** (Non-goals) | Low | QUIC stacks |
| **R7** | API_COVERAGE historical multi-arg `NewRequest` contradicts “physically deleted” | Doc append without archival | `API_COVERAGE.md` | **P0**: current-truth only; archive/strike history | Low | — |

### 1.3 Priorities P0–P3

| ID | Item | Classification | In-http? | Net dep? | Disposition |
|----|------|----------------|----------|----------|-------------|
| P0-1 | ConnectTimeout honesty | Doc + comment contract | Yes | No | **Implement** |
| P0-2 | Cancel checkpoint docs | Doc | Yes | No | **Implement** |
| P0-3 | API_COVERAGE drift | Doc | Yes | No | **Implement** |
| P1-1 | OS dial timeout | Capability | Seam only unless net change | **Yes** | **Blocked** unless net timed-connect lands this run |
| P1-2 | Cancel on blocked read | Capability | Checkpoints only | **Yes** | **Blocked** (document Timeout coupling) |
| P1-3 | hekArgument unify | Code | Yes | No | **Implement** (message/form/headers/stream public) |
| P1-4 | Cookie SameSite | Code | Yes | No | **Implement** (no full PSL) |
| P2-1 | HTTPS CONNECT + proxy auth | Feature | Yes | TLS/net | **Deferred** (Non-goals of this run) |
| P2-2 | GetString on client surface | API consistency | Yes | No | **Implement** |
| P2-3 | Retry-After | Feature | Yes | No | **Deferred** (policy design not in assessment defaults) |
| P2-4 | Default User-Agent | Small default | Yes | No | **Implement** |
| P3-* | H3 / async / h2c | Strategy | — | — | **Non-goals** |

---

## 2. Root-cause deep dives

### 2.1 R1 / P1-1 — Dial timeout

```
Http client → TH1ClientTransport.RoundTrip
  → TcpConnect(host, port)   // nextpas.core.net
    → NetTcpConnect
      → platform_socket_connect  // blocking, no deadline
  → ApplyClientDeadline(ConnectTimeout)  // only after socket exists
  → WriteRequest ...
```

**Counterpart**: Go `net.Dialer{Timeout}` / `DialContext`; Rust `reqwest` `connect_timeout`.

**Strategies**:
1. **Full fix**: `TcpConnectWithTimeout(addr, port, ms)` via nonblocking connect + poll/select in net/platform; H1 uses EffectiveConnectTimeout for dial **and** first-write. Large cross-module blast radius.
2. **Honest Blocked**: Document that OS dial is unbounded except OS defaults; `ConnectTimeout` remains first-write budget; future `DialTimeout` owned by net.

**Chosen for this run**: **(2) Blocked** with explicit CONTRACT table + source comments. No silent claim that ConnectTimeout dials.

### 2.2 R2 / P1-2 — Cancel vs blocked read

Checkpoints already: Send entry, redirect, retry, H1 entry/pre-dial/post-write/pool-reconnect.
`TTcpStream.Read` applies read deadline from `IDeadline` but does not poll `IHttpCancelToken`.

**Counterpart**: Go context canceled → read returns; Tokio cancel drops future.

**Chosen**: **Blocked** on true mid-read cancel; **P0** docs require pairing cancel with `Timeout`/`WithTimeout` for bounded wait; cancel remains cooperative.

### 2.3 R4 / P1-4 — SameSite without PSL

**Server path** already serializes SameSite on `BuildSetCookie`.
**Client jar** ignores attribute on store/send.

**Policy (chosen)**:
1. Parse `SameSite=Strict|Lax|None` (case-insensitive); missing → treat as **Lax** (modern browser default).
2. `SameSite=None` without `Secure` → **do not store**.
3. **Site approximation** (no PSL): `SiteKey(host)` = lowercase host if ≤1 dot label suffix else last two labels joined (e.g. `a.b.example.com` → `example.com`). Cross-site if `SiteKey(request host) <> SiteKey(cookie host/domain)`.
4. **Send**:
   - same-site: send all non-expired matching cookies (existing Domain/Path/Secure rules);
   - cross-site: send only `SameSite=None` (+ Secure already required at store); suppress Strict/Lax.

**Risk**: approximate site ≠ eTLD+1 (e.g. `co.uk`). Acceptable for API clients; documented. Full PSL = Non-goal.

### 2.4 R5 / P1-3 — Dual exceptions

Public helpers still raise `EArgumentError` in `message.pas`, `form.pas`, `headers.pas`, `stream.pas`, etc. Client-facing validation already prefers `EHttpError(hekArgument)`.

**Chosen**: Migrate **public** preconditions in:
- `nextpas.core.http.message`
- `nextpas.core.http.form`
- `nextpas.core.http.headers`
- `nextpas.core.http.stream` (facade-exported body helpers)

Leave internal `impl.*` raises as-is unless tests demand (minimize blast radius). Tests that expect `EArgumentError` update to `EHttpError` + `hekArgument`.

### 2.5 P2 surface

| Item | Decision | Rationale |
|------|----------|-----------|
| GetString/GetBytes methods on `IHttpClient` | **Do** | Forward to existing `HttpGetString`/`HttpGetBytes`; dual free-fn retained |
| Default User-Agent | **Do** | If request lacks `User-Agent`, H1 outbound sets `nextpas-http/1.0` (Go/reqwest-style default identity) |
| CONNECT / proxy auth | **Defer** | Separate TLS tunnel milestone |
| Retry-After | **Defer** | Needs policy API; not in wave-5 recommended defaults |

---

## 3. Impact matrix

| Change cluster | Files (expected) | Tests |
|----------------|------------------|-------|
| Docs honesty + coverage truth | CONTRACT, README, API_COVERAGE, research, plan | source-contract if any |
| hekArgument migration | message, form, headers, stream | message, form, client if broken |
| SameSite jar | cookie.pas | cookie + client jar tests |
| GetString methods | intf, client, facade, forwarder | client |
| Default UA | impl.h1 outbound / client WriteRequest path | client |
| Blocked dial/cancel | CONTRACT only (+ comments on options) | none (doc contract) |

---

## 4. Fix strategy summary

1. **Research + plan docs** (this file + implementation plan) before code.
2. **P0 docs** honesty + API_COVERAGE cleanup.
3. **P1 in-http**: hekArgument + SameSite + tests.
4. **P1 net**: Blocked table (no fake OS ConnectTimeout).
5. **P2**: GetString methods + default UA; defer CONNECT/Retry-After.
6. Focused gates + hygiene + scratch evidence.

---

## 5. Risk assessment of the fix program itself

| Risk | Mitigation |
|------|------------|
| Tests assert `EArgumentError` | Grep/fix test expectations with Kind checks |
| SameSite breaks existing jar tests | Default Lax same-site still sends to matching hosts |
| Default UA breaks fingerprint tests | Only inject if header absent |
| Net Blocked seen as incomplete | Explicit table in CONTRACT; acceptance criterion 4 |

---

## 6. Blocked / Deferred table (authoritative)

| Item | State | Owner | Unblock condition |
|------|-------|-------|-------------------|
| OS dial timeout (`connect()`) | **Blocked** | net + platform | `TcpConnect` timed/nonblocking + http H1 wiring |
| Mid-read cancel interrupt | **Blocked** | net + http | Read loop polls cancel or uses waitable IO |
| HTTPS CONNECT / proxy auth | **Deferred** | http | Dedicated proxy tunnel slice |
| Retry-After driven retry | **Deferred** | http | Policy design + tests |
| Full Public Suffix List | **Deferred** | http | Embed PSL or platform API |
| H3 / async public API | **Non-goal** | — | QUIC / product strategy |

---

## 7. Research conclusion

All assessment IDs are classified. Default-recommended fixes that are **http-owned** (P0, P1-3, P1-4, P2-2, P2-4) proceed to implementation. Net-owned dial/cancel remain **Blocked** with honest contract. CONNECT/Retry-After/PSL/H3 remain deferred/non-goal per scope.
