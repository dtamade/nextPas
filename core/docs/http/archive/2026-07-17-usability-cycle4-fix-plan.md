# Fix plan: nextpas.core.http usability cycle-4

**Status**: **Implemented** — M0–M6 code + focused gates green (see SCRATCH ready.md)
**Baseline**: `a12f8dd9b`
**Assessment**: `2026-07-17-usability-assessment-cycle4.md` (score **91 / 100**)
**Research**: `2026-07-17-usability-cycle4-research.md`
**Goal**: Close H2 dial/cancel parity, docs truth, verification, and P2 ergonomics without Deferred product expand

---

## 0. Principles

1. **Confirm first** — single implementation wave after approval; no drive-by refactors.
2. **H1 is reference** — H2 must match H1 ConnectTimeout + cancel semantics, not invent new ones.
3. **Honesty** — residual ~50 ms cancel slice stays documented; no fake OS interrupt.
4. **Additive API** — fluent `WithConnectTimeout` only; no breaking renames.
5. **Path-limited land** — cherry-pick to `landing/http-usability-cycle4-YYYYMMDD`; no raw lane merge.
6. **Out of scope**: CONNECT, Retry-After, full PSL, response metadata expand, GetJson decode product, H3, Default server RW change.

---

## 1. Milestone overview

```text
M0  Docs truth (P0)                    ── no code deps
M1  H2 ConnectTimeout parity (P1)      ── independent of M0
M2  H2 cancel wire (P1)                ── after or with M1 (shared dial sites)
M3  Verification (P1)                  ── after M1+M2
M4  Fluent WithConnectTimeout (P2)     ── after M1 semantics stable
M5  JSON/docs + optional Op polish (P2)── parallel with M4 after M0
M6  Focused gates + Ready + land       ── after M0–M5
```

| Milestone | Pri | Depends | Outcome |
|-----------|-----|---------|---------|
| **M0** | P0 | — | API_COVERAGE / matrix current-truth matches CONTRACT; cycle-4 pointers |
| **M1** | P1 | — | H2 options + registry + dial use ConnectTimeout like H1 |
| **M2** | P1 | M1 preferred | H2 SetCancelToken per RoundTrip; pool clears token; hekCanceled |
| **M3** | P1 | M1, M2 | Source-contracts + selective e2e; gates green |
| **M4** | P2 | M1 | `IHttpClient.WithConnectTimeout` + tests |
| **M5** | P2 | M0 | JSON dual-layer honesty; optional hot-path Op |
| **M6** | — | M0–M5 | hygiene, landing-check, ff-only main |

---

## 2. Detailed work items

### M0 — Docs truth (P0)

**Files** (expected):
- `core/docs/http/API_COVERAGE.md` — rewrite top “当前结论”: dial/cancel **Landed** (H1); H2 residual listed as cycle-4 open until M1/M2 close; remove stale “Blocked net” for those two.
- Cross-link assessment/research/plan cycle-4.
- Optional one-line note in `GOAL_TREE.md` if it still says Blocked dial/cancel.

**Done when**: No live doc claims OS dial / mid-read cancel are fully Blocked without H1 Landed qualification.

---

### M1 — H2 ConnectTimeout parity (P1)

**Files** (expected):
- `core/src/nextpas.core.http.impl.h2.client.pas` — options record field; dial uses effective connect ms; post-dial first-write budget parity with H1.
- `core/src/nextpas.core.http.impl.registry.pas` — copy `ConnectTimeout` into H2 options (mirror H1 lines).
- Tests: h2_client and/or client source-contract for plumbing.

**Semantics (must match H1 / CONTRACT)**:
- `ConnectTimeout > 0` → dial ms = ConnectTimeout; post-dial first write deadline = ConnectTimeout.
- `ConnectTimeout = 0` → dial ms = Timeout if Timeout>0 else unbounded; first write uses Timeout.
- Negative rejected at client construction (already).

**Done when**: H2 path cannot ignore a positive ConnectTimeout; focused H2 + client tests pass.

---

### M2 — H2 cancel wire (P1)

**Files** (expected):
- `impl.h2.client.pas` — apply cancel adapter after dial / on checkout; clear before pool return; wrap `ECancelledError`.
- Prefer reuse of H1 `THttpNetCancelAdapter` pattern (extract shared unit only if duplication is painful; **min scope** may copy small adapter to avoid large extract).

**Rules**:
- Cancel token lifetime = single RoundTrip on that stream.
- Pooled connection must not retain previous request’s token.
- Facade checkpoints remain; this adds mid-read/write interruptibility.

**Done when**: Source-contract or unit test proves SetCancelToken used; cancel → `hekCanceled`; pool reuse test still green.

---

### M3 — Verification (P1)

| Gate | What to add |
|------|-------------|
| `test_http_client` | Source-contract H1ClientDial timed + cancel wire (extend existing window); optional live dial if local hang stable |
| `test_http_h2_client` | ConnectTimeout field plumbing; cancel SetCancelToken on fake stream; dial ms argument if injectable |
| `test_net` | Unchanged primary proof for OS dial + read cancel (already green) |
| `test_http_contract` | Facade visibility for WithConnectTimeout after M4 |

**Avoid**: 192.0.2.1 blackhole (proxies may fake-connect). Prefer local backlog-full listen (net suite technique).

**Done when**: Documented focused list all green with heaptrc 0 leak on those suites.

---

### M4 — Fluent WithConnectTimeout (P2)

**Files**:
- `nextpas.core.http.intf.pas` — method on `IHttpClient`
- `nextpas.core.http.client.pas` — `THttpClient` + forwarder rebind (same pattern as `WithProxyUrl`)
- Facade re-export if needed (interface already via facade uses)
- Tests: client option apply + decorator stack

**Done when**: `NewHttpClient.WithConnectTimeout(1500)` sets options and rebuilds transport like proxy.

---

### M5 — JSON honesty + optional Op (P2)

1. README / API table: raw `PostJson` vs free `HttpPostJson` ensure-2xx.
2. Optional thin aliases only if zero ambiguity (e.g. document free-fns as preferred ensure path).
3. Optional: cancel wrap at H2 RoundTrip includes METHOD url when request known — **skip if messy**.

**Out of scope**: full GetJson decode product (Deferred D5).

---

### M6 — Verify + land

```bash
# Focused (run one-by-one; do not multi-FOCUS single make)
make focused FOCUS=core/tests/nextpas.core.net/test_net
make focused FOCUS=core/tests/nextpas.core.http/test_http_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_h2_facade
make focused FOCUS=core/tests/nextpas.core.http/test_http_contract
make focused FOCUS=core/tests/nextpas.core.http/test_http_smoke
# plus any suite touched by edits

make hygiene
git diff --check

# Landing (after commit on http lane)
# worktree landing/http-usability-cycle4-YYYYMMDD from origin/main
# cherry-pick → make landing-check ALLOW_PATHS=<exact files> FOCUS=...
# ff-only main → push → archive tags → resync http
```

**Expected ALLOW_PATHS prefixes/files**:
- `core/src/nextpas.core.http.impl.h2.client.pas`
- `core/src/nextpas.core.http.impl.registry.pas`
- `core/src/nextpas.core.http.intf.pas` / `client.pas` (if M4)
- `core/docs/http/*` (M0/M5)
- touched `core/tests/nextpas.core.http/**`

---

## 3. Dependency graph

```text
        ┌──── M0 (docs) ──────────────┐
        │                             ▼
M1 (H2 ConnectTimeout) ──► M2 (H2 cancel) ──► M3 (tests) ──► M6 land
        │                      │
        └──────► M4 fluent ────┤
                               │
M0 ──────────────────► M5 JSON/docs ──┘
```

- M1 and M0 parallel.
- M2 should land with M1 in one commit or sequential commits same PR/slice (shared H2 files).
- M4 after M1 to avoid fluent pointing at non-plumbed H2 field.

---

## 4. Priority / effort / risk

| Item | Pri | Effort | Risk | Score impact (est.) |
|------|-----|--------|------|---------------------|
| M0 docs | P0 | S | None | +1 truth |
| M1 H2 ConnectTimeout | P1 | M | Low–Med | +2 consistency |
| M2 H2 cancel | P1 | M | Med | +2 boundary |
| M3 tests | P1 | M | Low (flake if e2e bad) | +1 coverage |
| M4 fluent | P2 | S | Low | +1 usability |
| M5 JSON/Op | P2 | S | Low | +0.5 |

**Target post-fix score**: **94–96 / 100**
**Target risk**: **Low–Medium** (Deferred product gaps remain)

---

## 5. Explicit non-goals (this cycle)

| Item | Why |
|------|-----|
| HTTPS CONNECT / proxy auth | Separate design (TLS tunnel) |
| Retry-After | Policy product |
| Full publicsuffix | Cookie jar epic |
| IHttpResponse metadata expand | API surface growth |
| ensure + JSON decode helpers product | Can follow as thin slice later |
| Op-everywhere mass rewrite | Noise |
| Change `NewHttpServer` Default → Production | Compat break |
| OS-level cancel interrupt | Net residual I8 |
| H3 | QUIC blocked |

---

## 6. Confirmation checklist (user)

Approved via goal mode (full implement + test + evidence):

- [x] Scope M0–M6 accepted (no CONNECT/PSL/etc. in this wave)
- [x] H2 parity + docs + tests prioritized over JSON product expand
- [x] Residual ~50 ms cancel slice accepted as documented
- [x] Landing will be path-limited cherry-pick (not raw `http` merge)

---

## 7. Post-implement Ready template (for later)

```
Status: Ready
Branch: http
HEAD: <sha>
Files: <list>
Cross-module: none (or net only if unavoidable)
Verification:
  - test_net: ...
  - test_http_client: ...
  - test_http_h2_client: ...
  - landing-check: pass
Merge: path-limited cherry-pick to landing/http-usability-cycle4-YYYYMMDD
```
