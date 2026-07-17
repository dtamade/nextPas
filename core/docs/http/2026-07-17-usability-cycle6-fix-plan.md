# Fix plan: nextpas.core.http usability cycle-6

**Status**: **Implementing Wave A** — M0 land cycle-5 + archive truth + M4 gates
**Baseline**: committed `fb0bbeae0` + uncommitted cycle-5 worktree
**Assessment**: `2026-07-17-usability-assessment-cycle6.md` (score **96 / 100**)
**Research**: `2026-07-17-usability-cycle6-research.md`
**Goal**: Land cycle-5, close residual polish (optional P2), keep Deferred product out of scope

---

## 0. Principles

1. **Confirm first** — no drive-by refactors; single wave after approval.
2. **Land before expand** — cycle-5 must commit/land before optional P2 features.
3. **Honesty** — residual ~50 ms cancel slice stays; no fake OS interrupt.
4. **No Deferred product** — CONNECT / PSL / Retry-After / GetJson decode / H3 / Default RW change.
5. **Path-limited land** — no raw long-lived `http` → `main` merge.
6. **FPC RTL isolation** — no new direct FPC RTL `uses` in http src/tests/examples.

---

## 1. Milestone overview

```text
M0  Land cycle-5 + archive truth (P0)     ── first, mandatory
M1  WS cancel or honest-doc (P2)          ── optional after M0
M2  H2 live dial e2e (P2)                 ── optional after M0
M3  CreateOp hot-path polish (P2)         ── optional after M0
M4  Focused gates + Ready                 ── after selected M*
```

| Milestone | Pri | Depends | Outcome |
|-----------|-----|---------|---------|
| **M0** | P0 | — | cycle-5 committed + landing path ready; cycle-5 assessment notes fixed |
| **M1** | P2 | M0 | WS CancelToken wire **or** CONTRACT honesty that WS cancel is app-owned |
| **M2** | P2 | M0 | Optional H2 live ConnectTimeout e2e |
| **M3** | P2 | M0 | Optional remaining client CreateOp sites |
| **M4** | — | M0 (+ any P2) | hygiene + focused gates + Ready report |

**Recommended default wave**: **M0 + M4 only** (ship cycle-5).
**Full polish wave**: M0 + M1(A) + M2 + M3 + M4.

---

## 2. Detailed work items

### M0 — Land cycle-5 + archive truth (P0)

**Already in worktree (do not re-implement)**:
- `nextpas.core.http.websocket.pas` — timed dial / handshake
- `nextpas.core.http.client.pas` — redirect CreateOp
- `test_http_client` / `test_http_websocket_client` live e2e
- CONTRACT / API_COVERAGE / GOAL_TREE / README + cycle-5 docs

**Still to do after confirm**:
1. Fix `2026-07-17-usability-assessment-cycle5.md` dimension Notes to post-fix truth
   (or supersede banner pointing to cycle-6).
2. `git add` path-limited files; meaningful commit on `http`.
3. Landing worktree `landing/http-usability-cycle5-YYYYMMDD` path-limited cherry-pick /
   replay; `make hygiene`; focused gates; FF main **only if authorized**.
4. Re-sync `http` to main after land.

**Done when**: clean worktree (or only cycle-6 P2 files), HEAD contains cycle-5, main
updated if authorized, assessment archives not self-contradictory.

---

### M1 — WS cancel (P2, optional)

**Option A — Implement**:
- `TWebSocketOptions.CancelToken: IHttpCancelToken` (or setter fluent).
- Apply net cancel adapter on active stream after dial; clear on Close.
- Tests: cancel during blocked ReadFrame → `hekCanceled`.
- Docs: CONTRACT §2.2.3b.

**Option B — Honest-doc only**:
- CONTRACT/README: post-upgrade I/O has no framework cancel; app must Close peer or
  use process-level shutdown; dial/handshake remain bounded.

**Default recommendation if user wants minimal blast**: **B** in same land as M0.
**If user wants feature parity**: **A**.

---

### M2 — H2 live dial e2e (P2, optional)

- `test_http_h2_client` or `test_http_client` with `WithVersion(hvHttp2)` + backlog-full.
- Expect `hekTimeout`/`hekConnect` within short ConnectTimeout.
- Skip or soft-check if H2 preface behavior makes test unstable.

---

### M3 — CreateOp polish (P2, optional)

- Remaining client Send/ensure sites that still use bare Create with METHOD url context.
- **Not** parser/HPACK/fuzz.

---

### M4 — Gates + Ready

```bash
make hygiene
make focused FOCUS=core/tests/nextpas.core.http/test_http_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_websocket_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_websocket
make focused FOCUS=core/tests/nextpas.core.http/test_http_contract
git diff --check
```

Ready report: branch, HEAD, file list, gates, residual honesty, Deferred list.

---

## 3. Dependency graph

```text
M0 (land cycle-5) ──┬──► M1 (optional)
                    ├──► M2 (optional) ──► M4
                    └──► M3 (optional)
```

---

## 4. Priority map

| Assessment ID | Milestone |
|---------------|-----------|
| P0-1 uncommitted cycle-5 | M0 |
| P0-2 assessment archive | M0 |
| P2-1 WS cancel | M1 |
| P2-2 H2 live e2e | M2 |
| P2-3 CreateOp | M3 |
| Deferred / Residual | Document only |

---

## 5. Explicit non-goals

- HTTPS CONNECT / proxy auth
- Full PSL / Retry-After / Response metadata expand
- ensure-2xx JSON **decode** product
- Changing `THttpServerOptions.Default` RW from 0
- H3/QUIC
- OS-level cancel interrupt
- Op-everywhere

---

## 6. Confirmation checklist (user)

Please confirm before implementation:

- [ ] **Wave A (recommended)**: M0 land cycle-5 + archive fix + M4 only
- [ ] **Wave B**: Wave A + M1 Option A (WS CancelToken)
- [ ] **Wave C**: Wave A + M1 Option B (docs only) + M2 + M3
- [ ] **Wave D**: Full M0–M3 (A for cancel) + M4
- [ ] Authorize **commit** on `http` and/or **path-limited land to main**

**Reply with wave letter (A/B/C/D) + land authorization to start.**
