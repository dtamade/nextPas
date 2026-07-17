# Fix plan: HTTP usability cycle-3

**Status**: ready to execute
**Research**: `2026-07-17-usability-cycle3-research.md`
**Assessment**: `2026-07-17-usability-assessment-cycle3.md` (93/100)
**Baseline**: `82ecf1f3e`

---

## Milestones

### M1 — Transport hekArgument (I1 + I6)

1. Replace `raise EArgumentError.Create(...)` with `EHttpError.Create(hekArgument, ...)` in:
   - `nextpas.core.http.impl.h1.pas`
   - `nextpas.core.http.impl.h2.client.pas`
   - `nextpas.core.http.impl.h2.server.pas`
   - `nextpas.core.http.impl.h2.session.pas`
   - `nextpas.core.http.impl.h2.tls.pas`
   - `nextpas.core.http.impl.tls.stream.pas`
2. Ensure units can see `EHttpError` / `hekArgument` (already via http.base / errors).
3. Tests:
   - `test_http_client`: H1 transport nil inputs → hekArgument
   - `test_http_server`: `CheckRaisesEArgumentError` → hekArgument helper
   - `test_http_h1fast`: nil ForEach → hekArgument (or EHttpError Kind)

### M2 — Production RequestArena factory (I2)

1. `NewHttpServerWithRequestArena` no-options overloads:
   `THttpServerOptions.Production.WithRequestArena[...]`
2. Optional: `test_http_mem` asserts Production RW when using no-arg factory

### M3 — Error context (I3 + I4)

1. `DoRequest`: wrap redirect resolve / rewind failures with `FormatHttpClientError`
2. Download mkdir/publish messages use `FormatHttpClientError('GET', AUrl, ...)`

### M4 — Docs (I5)

1. README Quick Start Production
2. GOAL_TREE / CONTRACT / API_COVERAGE cycle-3 current-truth note
3. Assessment/research/plan already in docs/http/

### M5 — Verify

```bash
make focused FOCUS=core/tests/nextpas.core.http/test_http_client
make focused FOCUS=core/tests/nextpas.core.http/test_http_server
make focused FOCUS=core/tests/nextpas.core.http/test_http_h1fast
make focused FOCUS=core/tests/nextpas.core.http/test_http_mem
make focused FOCUS=core/tests/nextpas.core.http/test_http_contract
make hygiene
git diff --check
```

---

## Priority / dependency

```
M1 ──┐
M2 ──┼── M4 ── M5
M3 ──┘
```

M1–M3 independent; M4 after code matches; M5 last.

## Out of scope

- net dial timeout / mid-read cancel (Blocked)
- CONNECT / Retry-After / PSL / Response metadata / JSON ensure-decode / Op-all (Deferred)
- H3 (Non-goal)
- Changing `NewHttpServer` no-options Default (compat)
