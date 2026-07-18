# Implementation plan: post-residual usability (post-`feec31b45`)

**Status**: frozen before bulk code edits
**Research**: `2026-07-17-usability-post-residual-research.md`
**Baseline**: `feec31b45`

---

## Milestones

| M | Scope | Priority | Depends |
|---|--------|----------|---------|
| **M0** | Research + this plan on disk | P0 | — |
| **M1** | SSE public preconditions → `EHttpError(hekArgument)` + tests | P1 | M0 |
| **M2** | `THttpServerOptions.Production` + example RW discipline + tests | P1 | M0 |
| **M3** | Docs current-truth: README / CONTRACT / API_COVERAGE; ConnectTimeout + Blocked/Deferred | P1 | M1, M2 (wording) |
| **M4** | Focused gates + hygiene + `{SCRATCH}` evidence | P0 | M1–M3 |

---

## M1 — SSE hekArgument

**Files**

- `core/src/nextpas.core.http.sse.pas` — replace all public precondition `EArgumentError` with `EHttpError.Create(hekArgument, …)`
- `core/tests/nextpas.core.http/test_http_middlewares/test_http_middlewares.lpr` — assert `EHttpError` + `Kind = hekArgument` for field injection; add nil writer + negative retry cases

**Acceptance**

- No `raise EArgumentError` remains in `http.sse`
- Tests drive real `StartSSE` / `WriteEvent` / `WriteRetry`

---

## M2 — Server production RW discipline

**Files**

- `core/src/nextpas.core.http.base.pas` — `class function Production: THttpServerOptions`
  - Base = `Default`
  - `ReadTimeout := 30000`, `WriteTimeout := 30000`
  - Leave `Default` RW = 0 for tests/compat
- Examples:
  - `http_hello_server` → `Production` (or Production.WithRequestArena)
  - `http_websocket_echo_demo` → Production
  - `http_server_options_demo` → set ReadTimeout finite (already has WriteTimeout)
- `test_http_server` — Production values; Default still RW=0

**Acceptance**

- Production is enforceable in code (not docs-only)
- Default remains non-breaking
- Docs state production must use Production or explicit WithRead/WriteTimeout

---

## M3 — Docs

**Files**: `README.md`, `CONTRACT.md`, `API_COVERAGE.md`

**Rules**

- Public construction / Send(nil) / body helpers / auth helpers / negative options → `EHttpError(hekArgument)` where code does so
- Production server section: Production helper + Default RW=0 meaning
- ConnectTimeout = post-dial first-write; OS dial Blocked §2.2.0a
- Deferred list: CONNECT, Retry-After, PSL, Response metadata, JSON ensure-decode, full Op/URL, H3 Non-goal
- Historical archive may keep old EArgumentError only if clearly not live

---

## M4 — Verification

```bash
make focused FOCUS=core/tests/nextpas.core.http/test_http_middlewares
make focused FOCUS=core/tests/nextpas.core.http/test_http_server
make focused FOCUS=core/tests/nextpas.core.http/test_http_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_contract
make hygiene
```

Capture full logs under implementer scratch; write `evidence-summary.md` disposition table.

---

## Out of scope (frozen)

- OS dial timeout / mid-read cancel implementation
- CONNECT, Retry-After, PSL, Response expand, JSON ensure-decode, Op everywhere, H3
- Raw merge / push
