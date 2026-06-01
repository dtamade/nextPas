# Findings: nextpas.core.http module ownership

## Project Rules Read

- `docs/design-conventions.md` is the binding style and architecture guide for `nextpas.core`.
- `http` is an L3 framework module and may depend only on L0-L2 modules.
- Module shape is responsibility-driven: facade/base/intf/ffi/implementation files exist only when their responsibilities are real.
- Facades must explicitly re-export public types and forward functions because FPC does not auto re-export.
- Public APIs should use small interfaces, COM reference counting for builders/handlers where appropriate, default exception propagation, and `TryXxx` only when branch-friendly failure handling is useful.
- Tests are independent `.lpr` projects under `tests/nextpas.core.<module>/...`; benchmarks are independent projects under `benchmarks/nextpas.core.<module>/...`.

## HTTP Architecture Findings

- `docs/http/ARCHITECTURE.md` positions HTTP as a unified facade plus shared application layer plus isolated protocol implementations.
- Current long-term architecture expects H1 first, then H2 after TLS/ALPN readiness, then H3 after QUIC readiness.
- Current source tree has implemented H1 parser/writer/scan/fast units, middleware presets, static serving, websocket upgrade, server/client skeletons, and public facade forwarding.
- Existing HTTP source inventory contains 22 `src/nextpas.core.http*.pas` units:
  - facade/contracts: `http`, `http.base`, `http.intf`
  - shared application layer: headers, URL, message, router, middleware, server, client, static, websocket
  - H1 protocol layer: llhttp, parser, writer, chunked, scan, fast
  - preset middleware: CORS, logger, recovery, timeout
- Existing HTTP tests contain 19 focused test projects covering base, client, contract, H1 parser/scan/writer/fast, headers, integration, message, middleware(s), router, security, server, smoke, static, URL, websocket.
- Existing benchmark projects cover H1 parser, headers, router, server, full chain, generic HTTP, and protocol comparison.

## Baseline Verification Findings

- `TH1ResponseWriter` currently defaults to chunked transfer when neither `Content-Length` nor `Transfer-Encoding` is preset.
- `nextpas.core.http.server` only adds `Connection: close` when the server itself plans to close the connection.
- The stale expectations in `test_http_h1writer` and `test_http_integration` were test-only drift, not a production regression.
- The updated tests now assert chunked framing and explicit flush behavior.

## Git and Collaboration Findings

- Current directory is `/home/dtamade/projects/nextPas/core`.
- `git_dir` equals `git_common`; this is the normal `main` checkout, not a linked worktree.
- The shared checkout has unrelated modified and untracked files outside this batch.
- Safe rule for this batch: touch only HTTP takeover planning/control-map files and do not stage unrelated work.

## Gaps to Audit Next

- `docs/http/ARCHITECTURE.md` mentions planned units such as `impl.registry`, `impl.h1.conn`, and H2/H3 units that are not present in the current source inventory.
- The public API coverage matrix has not yet been built; existing tests are numerous but not proven to cover every public function/method.
- `IHttpClient` extra verbs (`Put`, `Delete`, `Patch`, `Head`) need explicit coverage mapping.
- `IHttpTransport` and `IHttpServerTransport` need focused contract mapping.
- `THttpHandlerMethod` / `THttpHandlerProc` aliases and some `static` helpers are still only indirectly exercised.
- Benchmark baselines exist but should not drive changes until contract coverage and correctness gates are green.

## Communication Cadence Adopted

- Start every HTTP batch by showing an explicit task checklist.
- Keep `docs/nextpas.core.http.inbox.md` short and user-facing; keep `task_plan.md`, `findings.md`, and `progress.md` detailed enough for execution recovery.
- End every batch with what changed, verification evidence, retrospective, next plan, and git status/commit state.
