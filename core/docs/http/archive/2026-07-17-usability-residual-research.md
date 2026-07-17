# Research: HTTP residual usability findings (post-wave-6)

**Status**: complete (research before residual fix code)
**Baseline**: `http` @ wave-6 land (`66b6daf2a` family)
**Assessment source**: post-wave-6 high-standard usability report (89/100; F1–F7 / R1–R9 / P0–P3)
**Constraint**: no FPC RTL in production http paths; dual-compiler isolation

---

## 0. Re-baseline: already closed (wave-6)

Do **not** re-open these as residual work unless regression appears:

| Wave-6 item | Status |
|-------------|--------|
| message/form/headers/stream public preconditions → `hekArgument` | **Closed** |
| CookieJar SameSite store/send (approx SiteKey, no full PSL) | **Closed** |
| `IHttpClient.GetString` / `GetBytes` + free-fn parity for GET | **Closed** |
| Default `User-Agent: nextpas-http/1.0` | **Closed** |
| ConnectTimeout / cancel honesty + CONTRACT §2.2.0a Blocked table | **Closed (docs)** |
| API_COVERAGE wave-6 current-truth header | **Partial** — historical multi-arg narrative still pollutes mid-file |

---

## 1. Problem inventory (residual assessment IDs)

### 1.1 Findings F1–F7

| ID | Topic | Root cause | Impact surface | Fix strategy | Risk if unfixed | Go / Rust analogue |
|----|--------|------------|----------------|--------------|-----------------|--------------------|
| F1 | Interface design strong | N/A (positive) | Facade / intf | Preserve; no expand-by-default | Low | Go Handler/Client; reqwest builder |
| F2 | API usability friction | Examples omit Timeout; ConnectTimeout name residual; free-fn ensure-2xx incomplete on methods | examples, client surface | P0 docs/examples; P2 method symmetry | Medium misconfig | Client.Timeout; `.text()` helpers |
| F3 | Call consistency | server/ws/middleware still bare `EArgumentError` | server, websocket, middleware* | P1 migrate construction preconditions to `hekArgument` | Medium dual catch | Single error type |
| F4 | Error message quality | Client failure paths often omit method/URL | client.pas ensure/redirect/status | P1 helper prefix method+url | Medium-low | errors with URL context |
| F5 | Boundary residual | OS dial + mid-read cancel still Blocked | net + H1 | Honest Blocked (no fake); reinforce docs | High hang | DialContext / cancel |
| F6 | Tests thick | Expect `EArgumentError` on server/mw paths | tests | Update expectations with Kind checks | Medium | — |
| F7 | Perf/memory ok | No new residual from assessment for this run | — | No expand | Low | — |

### 1.2 Risks R1–R9

| ID | Risk | Root cause | Impact | Fix strategy | Residual after fix | Go / Rust |
|----|------|------------|--------|--------------|--------------------|-----------|
| **R1** | OS `connect()` hang | `NetTcpConnect` → blocking connect, no deadline | Client dial | **Blocked** net owner; docs reinforce | Hang until net lands | Dialer.Timeout |
| **R2** | Cancel alone unbounded | Cooperative checkpoints only | Send/read | **Blocked** + **P0** Timeout discipline in examples/docs | Must pair Timeout | context cancel |
| **R3** | Dual exceptions | server/ws/mw still `EArgumentError` | Callers | **P1** hekArgument migration | Internal impl may remain | Unified type |
| **R4** | No HTTPS CONNECT | Scope | Enterprise proxy | **Deferred** (large TLS tunnel) | Medium niche | CONNECT |
| **R5** | SiteKey ≠ PSL | Approx last-two-label | Cookie jar | **Deferred** (non-goal full PSL) | Low for API clients | publicsuffix |
| **R6** | Errors lack URL/method | Message strings minimal | Ops/debug | **P1** context helper on client status/ensure/redirect | Low | typed Error fields |
| **R7** | free-fn vs method asymmetry | Only GetString on interface; Post/Put/Patch/DeleteString free only | IHttpClient | **P2 keep**: add method mirrors | Low | client methods |
| **R8** | H3 | Non-goal | registry | **Non-goal** | Low | QUIC stacks |
| **R9** | API_COVERAGE historical multi-arg as readable “live” | Append-only history without archive fold | Docs | **P1** archive/collapse historical multi-arg as non-live | Low | — |

### 1.3 Priorities P0–P3

| ID | Item | Classification | In-http? | Disposition |
|----|------|----------------|----------|-------------|
| P0-1 | Timeout/cancel production discipline (docs + examples) | Doc + examples | Yes | **Implement** |
| P0-2 | (implicit) no claim cancel alone bounds wait | Doc | Yes | **Implement** with P0-1 |
| P1-1 | OS dial timeout | Capability | Seam | **Blocked** (net) |
| P1-2 | Mid-read cancel | Capability | Seam | **Blocked** (net+http) |
| P1-3 | server/websocket/middleware → hekArgument | Code | Yes | **Implement** |
| P1-4 | Client error method/URL context | Code | Yes | **Implement** |
| P1-5 | API_COVERAGE current-truth cleanup | Doc | Yes | **Implement** |
| P2-1 | ensure-2xx method symmetry (Post/Put/Patch/DeleteString) | API | Yes | **Implement** |
| P2-2 | HTTPS CONNECT | Feature | Yes | **Deferred** |
| P2-3 | Retry-After | Feature | Yes | **Deferred** |
| P2-4 | Full PSL / Response metadata expand | Feature | Yes | **Deferred** / Non-goal expand |
| P3 | H3 / async | Strategy | — | **Non-goal** |

---

## 2. Root-cause deep dives

### 2.1 R1 / P1-1 — Dial timeout (unchanged Blocked)

```
Http client → H1 RoundTrip → TcpConnect → platform_socket_connect (blocking)
  → only then ApplyClientDeadline(ConnectTimeout) for first write
```

**Counterpart**: Go `net.Dialer{Timeout}`; Rust `reqwest` `connect_timeout`.

**Chosen**: **Blocked** — no fake dial field in http. CONTRACT §2.2.0a remains authoritative. Unblock: net timed connect + H1 wire.

### 2.2 R2 / P0 — Cancel vs Timeout discipline

Checkpoints exist; blocked `Read` does not poll cancel. Assessment residual: **examples use bare `NewHttpClient` without Timeout**, so production templates teach unbounded wait.

**Chosen**:
1. README / CONTRACT production note: always set `Timeout` / `WithTimeout`; cancel is not sufficient alone.
2. `http_get_client` example: default client options with a finite Timeout (e.g. 30s) so the golden path models production.

### 2.3 R3 / P1-3 — Dual exceptions residual

Wave-6 migrated message/form/headers/stream/client construction. Residual raise sites:

| Unit | Approx count | Notes |
|------|--------------|-------|
| `http.server` | 9 | options + nil handler |
| `http.websocket` | 6 | options + upgrade/client args |
| `middleware.*` | ~14 | bodylimit, metrics, ratelimit, cachecontrol, deadline, decompress, hsts, requestarena |

**Chosen**: Migrate **public construction / public API argument** preconditions to `EHttpError.Create(hekArgument, ...)`. Leave third-party/lower-layer `EArgumentError` re-raise paths only where they catch foreign exceptions (decompress body path may still see lower-layer EArgumentError — keep catch, also treat `EHttpError` hekArgument as re-raise).

### 2.4 R6 / P1-4 — Error context

**Chosen**: Small helpers in `client.pas`:
- `HttpClientErrorMsg(const AOp, AMethod, AUrl, ADetail: string)` style prefix: `GET http://...: detail`
- Apply to: `HttpEnsureSuccess`, download status failures, key redirect failures that have URL in hand, transport nil response when request available.

Avoid expanding public error type fields this run (no API expand beyond messages).

### 2.5 R7 / P2-1 — ensure-2xx symmetry

**Chosen**: Add to `IHttpClient` + implementations + forwarder:
- `PostString(Url, ContentType, Body): string`
- `PutString` / `PatchString` / `DeleteString` (DeleteString with optional body overload matching free-fn)

Forward to existing free functions to avoid logic drift. Free functions remain supported.

### 2.6 R9 / P1-5 — API_COVERAGE

**Chosen**: Keep short **Current truth** section; move/replace long multi-arg “本轮补齐” live-tense paragraphs with a single **Historical archive (not live API)** note pointing that multi-arg `NewRequest` / `NewStreamingRequest` are deleted. Do not delete all history if useful for timeline — mark non-live clearly at top of archive block.

### 2.7 Deferred / Non-goals

| Item | State | Rationale |
|------|-------|-----------|
| HTTPS CONNECT + proxy auth | Deferred | Separate TLS tunnel milestone |
| Retry-After driven retry | Deferred | Needs policy API design |
| Full PSL | Deferred / Non-goal this run | SiteKey approx remains documented |
| Response Version/Request metadata | Deferred | API expand; not required for 89→fix residual |
| H3 | Non-goal | QUIC |

---

## 3. Impact matrix

| Change cluster | Files (expected) | Tests |
|----------------|------------------|-------|
| Research + plan | residual research + fix plan | — |
| P0 Timeout discipline | README, CONTRACT, http_get_client example | examples smoke if run |
| hekArgument migration | server, websocket, middleware* | server, middlewares, websocket, contract |
| Error context | client.pas | client |
| ensure-2xx methods | intf, client, facade re-export if needed | client |
| API_COVERAGE | API_COVERAGE.md | contract if surface listed |
| Blocked reinforce | CONTRACT (if needed) | — |

---

## 4. Fix strategy summary

1. Research + plan docs (this file + implementation plan) before code.
2. P0 docs/examples Timeout pairing.
3. P1 hekArgument residual + error context + API_COVERAGE archive.
4. Net dial/cancel remain **Blocked** with explicit owner.
5. P2 ensure-2xx method symmetry; CONNECT/Retry-After/PSL deferred.
6. Focused gates + hygiene + scratch evidence.

---

## 5. Risk of the fix program

| Risk | Mitigation |
|------|------------|
| Tests still expect `EArgumentError` | Update to `EHttpError` + Kind check |
| Decompress except path | Re-raise hekArgument; keep foreign EArgumentError re-raise |
| Default example timeout breaks slow CI | 30s is generous for loopback smoke |
| Method surface expansion | Only mirror existing free-fns; no new semantics |

---

## 6. Blocked / Deferred table (authoritative for residual run)

| Item | State | Owner | Unblock condition |
|------|-------|-------|-------------------|
| OS dial timeout | **Blocked** | net + platform | Timed/nonblocking connect + H1 wire |
| Mid-read cancel interrupt | **Blocked** | net + http | Read polls cancel or waitable IO |
| HTTPS CONNECT / proxy auth | **Deferred** | http | Proxy tunnel slice |
| Retry-After | **Deferred** | http | Policy design + tests |
| Full PSL | **Deferred** | http | Embed PSL or platform API |
| Response metadata expand | **Deferred** | http | Explicit API design |
| H3 / async public API | **Non-goal** | — | Product strategy |

---

## 7. Research conclusion

Residual assessment IDs are classified. **http-owned default fixes**: P0 Timeout discipline, P1 hekArgument residual, P1 error context, P1 API_COVERAGE, P2 ensure-2xx method symmetry. **Net-owned** dial/cancel stay **Blocked**. CONNECT/Retry-After/PSL/Response metadata **Deferred**. Proceed to implementation plan then continuous implement.
