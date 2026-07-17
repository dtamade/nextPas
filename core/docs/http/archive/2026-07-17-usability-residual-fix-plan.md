# Implementation plan: residual HTTP usability fixes (post-wave-6)

**Depends on**: `2026-07-17-usability-residual-research.md`
**Baseline**: `66b6daf2a` family
**Mode**: research+plan = confirmation gate; then continuous implement

---

## Milestones

| ID | Name | Priority | Owner | Depends |
|----|------|----------|-------|---------|
| M0 | Research + plan docs landed in tree | — | http | — |
| M1 | P0 Timeout/cancel discipline (docs + examples) | P0 | http | M0 |
| M2 | P1 hekArgument: server / websocket / middleware constructors | P1 | http | M0 |
| M3 | P1 client error method/URL context | P1 | http | M0 |
| M4 | P1 API_COVERAGE current-truth / archive multi-arg history | P1 | http | M0 |
| M5 | Net dial/cancel: honest Blocked only (no fake) | P1-net | net seam | M0 |
| M6 | P2 ensure-2xx method symmetry; defer CONNECT/Retry-After/PSL | P2 | http | M3 |
| M7 | Focused gates + hygiene + `{SCRATCH}` evidence | — | http | M1–M6 |

---

## M1 — P0 Timeout discipline

**Do**
- README: production client section — always set `Timeout` / `WithTimeout`; cancel requires Timeout for bounded wait; link CONTRACT §2.2 / §2.2.0a.
- CONTRACT: short “Production defaults” note if not already explicit for examples.
- `http_get_client`: `NewHttpClient(THttpClientOptions.Default.WithTimeout(30000))` (or equivalent).

**Tests**: example still compiles under examples gate if present; no behavior change required beyond default timeout.

---

## M2 — hekArgument residual

**Do** (replace `EArgumentError.Create` → `EHttpError.Create(hekArgument, ...)`):
- `nextpas.core.http.server` — all option/handler nil checks
- `nextpas.core.http.websocket` — options + upgrade/client nil/empty
- Middleware construction: bodylimit, metrics, ratelimit, cachecontrol, deadline, decompress (constructor), hsts, requestarena

**Decompress body path**: if raising platform-capacity as hekArgument, ensure except block re-raises `EHttpError` with hekArgument (and still re-raises bare EArgumentError from lower layers if any).

**Tests**: update `test_http_server`, `test_http_middlewares`, `test_http_websocket`, `test_http_contract` expectations from `on E: EArgumentError` to `EHttpError` + `Kind = hekArgument` where probing public construction.

---

## M3 — Client error context

**Do**
- Internal helper(s) to format `Op/Method URL: detail` or `METHOD url: detail`.
- Apply to at least: `HttpEnsureSuccess` (include status), download status failure (already has URL — normalize), redirect failures that have resolved URL, nil transport response when method/url available from request.

**Tests**: client test that EnsureSuccess / status failure message contains URL or method substring for a live or injected path.

---

## M4 — API_COVERAGE

**Do**
- Current-truth section first: live factories, Blocked, GetString/PostString plan outcomes.
- Historical multi-arg `NewRequest` / “本轮补齐” live-tense: wrap under **Historical archive (NOT live API)** with strike/note; remove wording that says “现在都接受” for deleted overloads.

---

## M5 — Net Blocked

**Do not** invent OS dial timeout or mid-read cancel in http.
- Confirm CONTRACT §2.2.0a still accurate; tweak only if residual research needs cross-link.
- Research/plan Blocked table is the evidence artifact.

---

## M6 — P2 ensure-2xx + deferred

**Implement**
- `IHttpClient.PostString` / `PutString` / `PatchString` / `DeleteString` (signatures match free-fns).
- `THttpClient` + `THttpClientForwarder` implement via free-fn forward.
- Facade re-export already via interface uses.

**Deferred (rationale in research §2.7)**
- CONNECT, Retry-After, full PSL, Response metadata expand.

**Tests**: client focused — PostString (or method) ensure-2xx path on live mock/server already used by HttpPostString tests; add method surface test if free-fn exists.

---

## M7 — Verification

```text
make focused FOCUS=core/tests/nextpas.core.http/test_http_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_server   # if touched
make focused FOCUS=core/tests/nextpas.core.http/test_http_middlewares
make focused FOCUS=core/tests/nextpas.core.http/test_http_websocket  # if touched
make focused FOCUS=core/tests/nextpas.core.http/test_http_contract   # if touched
make hygiene
```

Capture logs under implementer scratch.

---

## Dependency graph

```
M0 → M1
M0 → M2 → tests
M0 → M3 → M6
M0 → M4
M0 → M5 (docs only)
M1–M6 → M7
```

No net code dependency for this residual run.

---

## Out of scope (plan)

- H3, async rewrite, h2c Upgrade, full PSL embed, CONNECT tunnel, drive-by API expand, raw-merge to main unless user asks later.


---

## Verification status (M7)

Completed 2026-07-17 on branch `http`:

| Gate | Result |
|------|--------|
| test_http_client | 221 passed |
| test_http_server | 280 passed |
| test_http_middlewares | 132 passed |
| test_http_websocket | 38 passed |
| test_http_contract | 31 passed |
| make hygiene | build-hygiene=pass |

Scratch evidence: `/tmp/grok-goal-fc22405c9bf7/implementer/`
