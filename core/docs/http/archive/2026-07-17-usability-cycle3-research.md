# Research: HTTP usability cycle-3 findings (post-`82ecf1f3e`)

**Status**: complete (research before code)
**Baseline**: `http` @ `82ecf1f3e`
**Assessment**: `2026-07-17-usability-assessment-cycle3.md` (score 93/100)
**Constraint**: dual-compiler; no FPC RTL in http; net Blocked stays honest

---

## 1. Inventory vs tree

| ID | Finding | Tree fact | Root cause | Impact | Go/Rust | Disposition |
|----|---------|-----------|------------|--------|---------|-------------|
| **I1** | Transport preconditions use bare `EArgumentError` | ~29 `raise EArgumentError` in `impl.h1` / `impl.h2*` / `impl.tls.stream` | Prior waves migrated **public** construction only; left impl “internal” | Advanced transport callers dual-catch; tests encode bare type | Single error type | **Implement** |
| **I2** | `NewHttpServerWithRequestArena` uses Default RW=0 | `http.pas` lines ~1409–1425 | Convenience factory composed from Default | Production footgun | Production templates | **Implement** |
| **I3** | Redirect resolve messages lack METHOD url | `ParseRedirectAuthorityUrl` / `ResolveRedirectUrl` bare hekRedirect | Context only at DoRequest high-level branches | Ops debug | url.Error | **Implement** |
| **I4** | Download mkdir/publish lack METHOD url | `CreateOp(hekBody,'download', bare)` | Incomplete FormatHttpClientError rollout | Inconsistent | Same | **Implement** |
| **I5** | README Quick Start says Default for hello | Code uses Production.WithRequestArena | Doc lag | Trust | N/A | **Implement** |
| **I6** | Tests expect EArgumentError on transport/h1fast | `test_http_client`, `test_http_server` helper, `test_http_h1fast` | Lag after hekArgument / before I1 | Gate noise / wrong contract | — | **Implement** |
| **I7** | OS dial hang | net | net | High hang | DialContext | **Blocked** |
| **I8** | Mid-read cancel | cooperative only | net+http | Hang without Timeout | context | **Blocked** |
| **I9–I14** | CONNECT / Retry-After / PSL / Response meta / JSON ensure-decode / Op-all | surface freeze | scope | Ergonomics | various | **Deferred** |
| **I15** | H3 | seam only | QUIC | Product | h3 stacks | **Non-goal** |

---

## 2. Root-cause detail (Implement)

### I1 Transport dual exception

**Scope of raises** (precondition / capability only; not protocol IO):

- `impl.h1.pas`: client RoundTrip nil request/headers; server ServeConn nil conn/handler
- `impl.h2.client.pas`: connection/transport nil request/headers
- `impl.h2.server.pas`, `impl.h2.session.pas`, `impl.h2.tls.pas`: nil conn/handler/context/transport
- `impl.tls.stream.pas`: nil connection/context/transport; non-seekable stream ops

**Chosen strategy**: replace with `EHttpError.Create(hekArgument, same message)`.
Seek-not-supported on TLS stream is still argument/capability → hekArgument (not Protocol).

**Not in scope**: lower-layer foreign exceptions re-raise; parser protocol faults.

**Tests**: change `on E: EArgumentError` → `EHttpError` + `Kind = hekArgument`; rename/repurpose
`CheckRaisesEArgumentError` in server tests to hekArgument helper.

### I2 RequestArena factory Production base

```pascal
// before
THttpServerOptions.Default.WithRequestArena
// after
THttpServerOptions.Production.WithRequestArena
```

Overloads that take explicit `AOptions` still honor caller options + WithRequestArena.
`NewHttpServer` no-options remains Default (tests/compat) — document only.

Risk: low; mem test only checks non-nil. Optionally assert Production RW on no-arg factory.

### I3 Redirect context wrap

In `DoRequest`, when resolving Location fails, re-raise with
`FormatHttpClientError(method, url, originalDetail)` preserving `hekRedirect`.
Also wrap `RewindRedirectBody` failure message at call site the same way
(or leave body message if already clear — prefer wrap for consistency).

Do **not** change `ResolveRedirectUrl` signature (keeps pure); wrap at boundary.

### I4 Download context

```pascal
FormatHttpClientError('GET', AUrl, 'HTTP download could not create directory: ' + ...)
FormatHttpClientError('GET', AUrl, 'HTTP download could not publish file: ' + ...)
```

Keep `CreateOp(hekBody, 'download', ...)`.

### I5–I6 Docs + tests

- README Quick Start: Production.WithRequestArena
- GOAL_TREE: remove stale bare EArgumentError as live claim
- API_COVERAGE: reinforce current-truth; historical EArgumentError already marked
- Fix test expectations with I1

---

## 3. Risk assessment

| Change | Risk | Mitigation |
|--------|------|------------|
| I1 hekArgument transport | Low–Medium type change | Update focused tests; HttpErrorIsUserError already covers EArgumentError legacy |
| I2 Production factory | Low | Explicit options overloads unchanged |
| I3/I4 message text | Low | Substring tests for redirect mostly check presence of keywords |
| Docs | None | |

**Do not** fake dial timeout or mid-read cancel in http.
**Do not** implement Deferred I9–I14 as stubs.

---

## 4. Fix strategy summary

| Disposition | Items | Action |
|-------------|-------|--------|
| **Implement** | I1–I6 | Code + tests + docs one pass |
| **Blocked** | I7–I8 | CONTRACT already honest |
| **Deferred** | I9–I14 | Research table only |
| **Non-goal** | I15 | Unchanged |

---

## 5. Dependencies

```
I1 (transport hekArgument) ── updates tests I6
I2 (RequestArena Production) ── independent; optional mem test assert
I3 (redirect wrap) ── independent; client tests may assert prefix
I4 (download wrap) ── independent
I5 (docs) ── after I1/I2 wording matches
```

No net code required.
