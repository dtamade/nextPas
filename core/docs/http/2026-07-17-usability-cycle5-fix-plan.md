# Fix plan: nextpas.core.http usability cycle-5

**Status**: **Implemented** — M0–M4 code + focused gates green (see verification evidence below)
**Baseline**: `fb0bbeae0`
**Assessment**: `2026-07-17-usability-assessment-cycle5.md` (score **94 / 100**)
**Research**: `2026-07-17-usability-cycle5-research.md`
**Goal**: Close post-cycle-4 residual usability debt (docs truth, WebSocket dial budget,
  selective live verification, P2 polish) without Deferred product expand

---

## 0. Principles

1. **Confirm first** — single implementation wave after approval; no drive-by refactors.
2. **HTTP client is reference** — WebSocket dial/handshake budgets align to client semantics,
   not invent a third timeout model.
3. **Honesty** — residual ~50 ms cancel slice stays documented; no fake OS interrupt.
4. **Additive API** — WS options fields additive; no breaking renames of `PostJson`.
5. **Path-limited land** — cherry-pick to `landing/http-usability-cycle5-YYYYMMDD`; no raw lane merge.
6. **Out of scope**: CONNECT, Retry-After, full PSL, response metadata expand, GetJson decode
   product, Op-all, H3, changing `THttpServerOptions.Default` RW to non-zero.

---

## 1. Milestone overview

```text
M0  Docs truth (P0)                      ── no code deps
M1  WebSocket timed dial (P1)            ── independent of M0
M2  Live http dial/cancel e2e (P1)       ── after or parallel M1
M3  JSON honesty + optional Op (P2)      ── after M0; parallel M1/M2
M4  Focused gates + Ready + land         ── after M0–M3
```

| Milestone | Pri | Depends | Outcome |
|-----------|-----|---------|---------|
| **M0** | P0 | — | CONTRACT §2.1 matches live `IHttpClient`; cycle-5 pointers |
| **M1** | P1 | — | WS `TcpConnect(..., ms)` + handshake deadline; tests green |
| **M2** | P1 | — | H1 live dial-timeout (± mid-read cancel) in `test_http_client` |
| **M3** | P2 | M0 | Dual-layer JSON table; optional hot-path CreateOp |
| **M4** | — | M0–M3 | hygiene, focused gates, landing-check, Ready report |

---

## 2. Detailed work items

### M0 — Docs truth (P0)

**Files** (expected):
- `core/docs/http/CONTRACT.md`
  - Expand §2.1 `IHttpClient` snippet: `GetString`/`GetBytes`/`*String`,
    `WithConnectTimeout`, `WithProxyUrl`, `WithCookieJar`, `PostMultipart`, …
  - Confirm §2.2.0a still says dial/cancel **Landed** for H1/H2.
  - WebSocket note: dial budget **Implementing in cycle-5** or update after M1.
  - Bump 最后更新 / 版本.
- `core/docs/http/API_COVERAGE.md` — add cycle-5 current-truth bullet under 当前结论.
- `core/docs/http/GOAL_TREE.md` — one-line current position for cycle-5 open → closed after land.
- Optional: README cross-link if WS timeout docs missing.

**Done when**: No live CONTRACT code block omits shipped fluent methods; assessment/research/plan
cross-linked.

---

### M1 — WebSocket timed dial (P1)

**Files** (expected):
- `core/src/nextpas.core.http.websocket.pas`
  - Extend `TWebSocketOptions` with `ConnectTimeout: Int64` (and optionally `Timeout` for
    handshake I/O if not already covered by stream deadlines).
  - Default: **recommend `ConnectTimeout = 30000`** for production discipline
    (document as intentional behavior tightening). If test blast is too high, fall back to
    `0` = unbounded + hard docs — **prefer 30000**.
  - `ConnectWebSocket`: `TcpConnect(Host, Port, dialMs)` when budget > 0.
  - After dial: apply read/write deadline for upgrade exchange; clear or re-arm after success
    as ownership requires.
  - Optional: cancel token bridge if already trivial via net adapter pattern — **only if**
    low blast; else defer cancel to residual honesty for WS.
- Tests: `test_http_websocket_client` / `test_http_websocket`
  - Source-contract: timed `TcpConnect` call present.
  - Default ConnectTimeout value asserted.
  - Optional live backlog-full dial timeout if stable.
- Docs: CONTRACT WebSocket section after code.

**Semantics**:
- Align dial budget with HTTP client EffectiveConnectTimeout mental model where possible.
- Errors: connect failures → `hekConnect` / timeout → `hekTimeout` via existing wrap helpers
  if applicable.

**Done when**: WS client cannot use untimed `TcpConnect` in production Default path without
explicit `ConnectTimeout=0`; focused WS gates green.

---

### M2 — Live verification (P1)

**Files** (expected):
- `core/tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - Live H1: non-accepting or backlog-full listener + short `WithConnectTimeout` /
    options → expect timeout or connect error (not hang).
  - Optional: mid-read cancel through real socket (slow body server + cancel token →
    `hekCanceled` within ~few slices).
- Keep existing source contracts.
- Do **not** remove net suite ownership of OS primitives.

**Technique**: Reuse `test_net` backlog-full pattern; **avoid** 192.0.2.1 blackhole.

**Done when**: At least one live dial-timeout behavioral test green under `test_http_client`;
documented in API_COVERAGE or assessment residual closed note.

---

### M3 — JSON honesty + optional Op (P2)

1. CONTRACT/README: dual-layer table
   - raw: `PostJson` / `PutJson` / … → `IHttpResponse`
   - ensure string: `HttpPostJson` / `GetString` / `PostString` / …
2. Optional: hot-path `CreateOp` on client Send failure sites and H1/H2 transport wrap only.
3. **No** GetJson decode product in this plan.

**Done when**: Dual layer unambiguous in CONTRACT; CreateOp optional item either done or
explicitly deferred in Ready report.

---

### M4 — Gates + Ready + land

**Focused verification** (minimum):

```bash
make hygiene
make focused FOCUS=core/tests/nextpas.core.http/test_http_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_websocket_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_websocket
make focused FOCUS=core/tests/nextpas.core.http/test_http_contract
# if time: full http Makefile gate
make -C core/tests/nextpas.core.http test
git diff --check
```

**Land path**:
1. Worktree clean except intentional cycle-5 files.
2. Commit logical unit(s) on `http` lane.
3. `landing/http-usability-cycle5-YYYYMMDD` path-limited cherry-pick / replay.
4. `make hygiene`; focused gates on landing worktree.
5. FF `main` only if authorized; re-sync `http` to main.
6. Ready report: branch, HEAD, files, gates, residual honesty, Deferred list.

---

## 3. Dependency graph

```text
M0 (docs) ──────────────────────────────┐
                                        ├─► M4 land
M1 (WS dial) ──► M3 optional docs WS ───┤
                                        │
M2 (live e2e) ──────────────────────────┘
M3 (JSON/Op) depends on M0 for docs coherence
```

M1 and M2 are independent and may parallelize after confirmation.

---

## 4. Priority ↔ milestone map

| Assessment ID | Milestone |
|---------------|-----------|
| P0-1 CONTRACT snippet | M0 |
| P1-1 WS dial budget | M1 |
| P1-2 live http e2e | M2 |
| P2-1 JSON dual-layer docs | M3 |
| P2-2 CreateOp hot-path | M3 optional |
| Deferred / Residual | Document only |

---

## 5. Risk register (execution)

| Risk | Severity | Mitigation |
|------|----------|------------|
| WS Default=30000 breaks hang-oriented tests | Medium | Update tests; explicit 0 only where hang is intentional |
| Live e2e flaky on CI | Medium | Localhost backlog; short ms; fail message clear |
| Scope creep to CONNECT/PSL | High process | Checklist reject |
| Multi-FOCUS makefile pitfall | Low | One FOCUS per `make focused` or use module Makefile |

---

## 6. Explicit non-goals (cycle-5)

- Changing `THttpServerOptions.Default` Read/Write from 0.
- HTTPS CONNECT / proxy auth.
- Full PSL cookie.
- Retry-After policy.
- `IHttpResponse` metadata expand.
- ensure-2xx JSON **decode** product.
- H3/QUIC.
- OS-level cancel interrupt (replace SO_RCVTIMEO slices).
- Op-everywhere across parser/HPACK/fuzz.

---

## 7. Confirmation checklist (user)

Please confirm before implementation:

- [ ] Approve M0–M4 scope as written
- [ ] Approve WS Default `ConnectTimeout=30000` (or specify prefer `0` + docs)
- [ ] Approve live e2e addition in `test_http_client`
- [ ] Confirm Deferred list stays Deferred
- [ ] Confirm land via path-limited landing branch (not raw `http` → `main` merge)

## 8. Verification evidence (post-implement)

| Gate | Result | Heaptrc |
|------|--------|---------|
| `test_http_websocket_client` | **6 passed** (incl. Default timeouts, source contract, live dial) | 0 unfreed |
| `test_http_client` | **226 passed** (incl. live ConnectTimeout, mid-read cancel, CreateOp contract) | 0 unfreed |
| `test_http_h2_client` | **63 passed** | 0 unfreed |
| `test_http_contract` | **31 passed** | 0 unfreed |
| `test_http_websocket` | **38 passed** | 0 unfreed |
| `make hygiene` / `git diff --check` | **pass** | — |

WS Default `ConnectTimeout`/`Timeout` = **30000** (as planned).
