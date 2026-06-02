# Progress Log: nextpas.core.http

## Session: 2026-06-03 chunk-specific security policy tightening

### Phase 2/3: security / parser / server exact policy proof tightening

- **Status:** complete
- **Scope:** tighten broad chunk-specific security assertions into explicit policy proof, without changing production code.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Used two `gpt-5.5 xhigh` 子代理做并行只读审查：一个审 `CL+TE` conflict，一个审 chunk extension / trailer 风险。
  - [x] Tightened `test_http_security` so `CL+TE` conflict now requires explicit `400`.
  - [x] Added `test_http_security` malformed chunk extension -> `400` proof.
  - [x] Added `test_http_h1parser` proof for `CL -> TE` and `TE -> CL` conflict parser errors.
  - [x] Added `test_http_server` proof for `CL -> TE` and `TE -> CL` conflict `400` + no handler dispatch.
  - [x] Verified the new tests passed on current implementation; no production fix was required.
  - [x] Re-ran focused security/parser/server suites with heaptrc proof.
  - [x] Re-ran the full HTTP suite after the coverage tightening.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-03 Chunk Policy

| Check                  | Command                                                          | Result                                             |
| ---------------------- | ---------------------------------------------------------------- | -------------------------------------------------- |
| Git safety state       | `git status --short --branch`                                    | Shared checkout is dirty outside HTTP target files |
| Focused security GREEN | `make -C tests/nextpas.core.http/test_http_security clean test`  | 13/13 passed, 0 unfreed memory blocks              |
| Focused parser GREEN   | `make -C tests/nextpas.core.http/test_http_h1parser clean test`  | 25/25 passed, 0 unfreed memory blocks              |
| Focused server GREEN   | `make -C tests/nextpas.core.http/test_http_server clean test`    | 26/26 passed, 0 unfreed memory blocks              |
| Full HTTP suite        | `make TESTS_DIR=tests/nextpas.core.http test`                    | All tests passed; heaptrc zero leaks per test      |

## Notes 2026-06-03 Chunk Policy

- 这一轮仍然是 coverage-tightening 批次，不是 bugfix 批次：新增/收紧后的 chunk-specific security tests 直接通过，说明现有实现已经具备这组更精确的策略语义。
- `CL+TE` conflict 不再是“200/400/close 都算安全”的模糊断言，而是被收紧为 parser error + server `400` + no handler dispatch。
- malformed chunk extension 现在也有明确的 raw-wire `400` proof，而不再只是被笼统归到 safe-handling。
- 两个 `gpt-5.5 xhigh` 子代理都支持本轮方向：一个确认 strict llhttp 默认下 `CL+TE` 冲突应锁成 explicit `400`；另一个指出更高风险的后续点是 trailer pollution，而不是继续堆 extension 兼容用例。
- `test_http_smoke` 仍打印 `True free heap : 260960 / Should be : 262144`，但 heaptrc 仍报告 `0 unfreed memory blocks`；继续视为非阻塞观察项。

## Review 2026-06-03 Chunk Policy

- `/codex`-style review 结论：这轮应如实记录为 chunk-specific security policy tightening，不是生产修复。
- 现在 parser、server、security 三层对 `CL+TE` conflict 已经形成了闭环证据，而不是只在单个 broad smoke 里宽松兜底。
- 下一步最值得开的 RED 不是再补普通 chunk extension 兼容，而是定义 trailer 契约边界，确认 trailer 是否污染普通 `Headers`。

## Session: 2026-06-03 malformed chunked request security proof

### Phase 2/3: parser and server raw-wire malformed chunked proof expansion

- **Status:** complete
- **Scope:** expand focused malformed chunked request proof in parser/server suites, without changing production code.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, architecture, task plan, findings, progress, and design conventions.
  - [x] Audited malformed chunked request/body gaps across `test_http_h1parser`, `test_http_server`, and `test_http_security`.
  - [x] Added focused parser proof for missing chunk-data CRLF.
  - [x] Added focused server proof for invalid chunk-size -> `400`.
  - [x] Added focused server proof for truncated chunked EOF -> `400` or safe close, and no handler dispatch.
  - [x] Verified the new tests passed on current implementation; no production fix was required.
  - [x] Re-ran focused parser/server/security suites with heaptrc proof.
  - [x] Re-ran the full HTTP suite after the coverage expansion.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-03 Malformed Chunked

| Check                  | Command                                                          | Result                                             |
| ---------------------- | ---------------------------------------------------------------- | -------------------------------------------------- |
| Git safety state       | `git status --short --branch`                                    | Shared checkout is dirty outside HTTP target files |
| Focused parser GREEN   | `make -C tests/nextpas.core.http/test_http_h1parser clean test`  | 23/23 passed, 0 unfreed memory blocks              |
| Focused server GREEN   | `make -C tests/nextpas.core.http/test_http_server clean test`    | 24/24 passed, 0 unfreed memory blocks              |
| Focused security GREEN | `make -C tests/nextpas.core.http/test_http_security clean test`  | 12/12 passed, 0 unfreed memory blocks              |
| Full HTTP suite        | `make TESTS_DIR=tests/nextpas.core.http test`                    | All tests passed; heaptrc zero leaks per test      |

## Notes 2026-06-03 Malformed Chunked

- 这一轮仍是 coverage-expansion 批次，不是 bugfix 批次：新增 malformed chunked focused tests 直接通过，说明 parser/server 现有实现已经具备这组 raw-wire 安全语义。
- parser 现在不仅锁定 invalid chunk-size 和 EOF truncation，也直接锁定 chunk data 后缺少 CRLF 的 framing error。
- server 现在直接证明 invalid chunk-size 会返回 `400`，而 truncated chunked EOF 会走 `400` 或安全关闭，并且两类异常请求都不会进入 handler。
- `test_http_security` 继续全绿，但它仍以 broad safe-handling smoke 为主；更精确的 chunk-specific 语义现在由 parser/server focused suites 承担。
- `test_http_smoke` 仍打印 `True free heap : 260960 / Should be : 262144`，但 heaptrc 仍报告 `0 unfreed memory blocks`；继续视为非阻塞观察项。

## Review 2026-06-03 Malformed Chunked

- `/codex`-style review 结论：这轮要如实记录为 malformed chunked security proof expansion，而不是虚构生产修复。
- 新增 proof 把 parser framing error、server `400`、server safe close、以及“异常 chunk 不进 handler”串成了一条完整证据链。
- Shared-checkout 风险没有变化：提交时必须继续保持 path-limited staging，只提交本轮 HTTP 文件。
- 下一步应考虑把 `test_http_security` 里与 chunk 相关的 broad safe-handling case 收紧成更精确的 policy proof。

## Session: 2026-06-03 inbound chunked request coverage

### Phase 2/3: parser and server inbound chunked request proof expansion

- **Status:** complete
- **Scope:** expand focused proof for inbound chunked request parsing and server handling, without changing production code.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, architecture, task plan, findings, progress, and design conventions.
  - [x] Added focused parser tests for valid chunked request body decode.
  - [x] Added focused parser tests for invalid chunk-size and truncated chunked EOF failure.
  - [x] Added focused server tests for decoded chunked request body readability.
  - [x] Added focused server tests for chunked inbound `MaxBodySize` enforcement.
  - [x] Verified the new tests passed on current implementation; no production fix was required.
  - [x] Re-ran focused parser/server suites with heaptrc proof.
  - [x] Re-ran the full HTTP suite after the coverage expansion.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-03 Chunked Inbound

| Check                | Command                                                         | Result                                             |
| -------------------- | --------------------------------------------------------------- | -------------------------------------------------- |
| Git safety state     | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files |
| Focused parser GREEN | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | 22/22 passed, 0 unfreed memory blocks              |
| Focused server GREEN | `make -C tests/nextpas.core.http/test_http_server clean test`   | 22/22 passed, 0 unfreed memory blocks              |
| Full HTTP suite      | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test      |

## Notes 2026-06-03 Chunked Inbound

- 这一轮是 coverage-expansion 批次，不是 bugfix 批次：新增 focused tests 直接通过，说明 parser/server 现有实现已经具备这组 chunked inbound 语义。
- parser 现在不仅锁定 response-side framing 语义，也直接锁定 request-side chunked decode / invalid chunk-size / truncation at EOF。
- server 现在直接证明 handler 读取的是 decoded request body，并且 chunked ingress 在跨 chunk 累加后同样受 `MaxBodySize` 约束。
- `test_http_smoke` 仍打印 `True free heap : 260960 / Should be : 262144`，但 heaptrc 仍报告 `0 unfreed memory blocks`；继续视为非阻塞观察项。

## Review 2026-06-03 Chunked Inbound

- `/codex`-style review 结论：这一轮应该如实记录为 coverage expansion，而不是虚构一个不存在的生产修复。
- parser-focused proof 和 server-focused proof 现在已经补到同一条 inbound chunked request 路线上，后续应把缺口收窄到 raw-wire malformed chunk rejection semantics。
- Shared-checkout 风险没有变化：提交时必须继续保持 path-limited staging，只提交本轮 HTTP 文件。

## Session: 2026-06-02 truncated fixed-length EOF rejection

### Phase 2/3: parser and public client truncation hardening

- **Status:** complete
- **Scope:** reject truncated `Content-Length` responses at EOF in the H1 response parser, and lock the public client behavior with focused tests.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, architecture, task plan, findings, progress, and design conventions.
  - [x] Audited parser/client response EOF behavior and chose the highest-value body-truncation gap.
  - [x] Added RED parser and client tests for truncated fixed-length responses.
  - [x] Verified RED: parser `Finish` and `IHttpClient` both accepted truncated fixed-length responses.
  - [x] Tightened `TH1Parser.Finish` so only true close-delimited responses may complete at EOF.
  - [x] Re-ran focused parser/client GREEN with heaptrc proof.
  - [x] Re-ran the full HTTP suite after the parser fix.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Truncation

| Check                | Command                                                         | Result                                             |
| -------------------- | --------------------------------------------------------------- | -------------------------------------------------- |
| Git safety state     | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files |
| RED parser           | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | 19 total, 18 passed, 1 failed                      |
| RED client           | `make -C tests/nextpas.core.http/test_http_client clean test`   | 16 total, 15 passed, 1 failed                      |
| Focused parser GREEN | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | 19/19 passed, 0 unfreed memory blocks              |
| Focused client GREEN | `make -C tests/nextpas.core.http/test_http_client clean test`   | 16/16 passed, 0 unfreed memory blocks              |
| Full HTTP suite      | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test      |

## Notes 2026-06-02 Truncation

- The real bug was in EOF handling, not routing or transport ownership: `TH1Parser.Finish` treated any parsed response as complete once the status line existed.
- That behavior was only valid for close-delimited responses. It was wrong for `Content-Length` responses, because EOF before the declared byte count means the message is truncated.
- The public impact was larger than the internal parser bug alone: `IHttpClient` would return a partial body and could infer keep-alive semantics from a corrupted response.
- `test_http_smoke` still prints `True free heap : 260960 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`; this remains a non-blocking observation.

## Review 2026-06-02 Truncation

- `/codex`-style review found no blocking issue in the fix shape: the change is narrow, test-driven, and keeps EOF completion semantics explicit.
- The important design correction is semantic, not incidental: framing truth now owns completion truth.
- Shared-checkout risk remains unchanged: commit must stay path-limited to owned HTTP files only.
- Next route: add focused malformed chunked request/body coverage on the inbound path.

## Session: 2026-06-02 internal registry landing

### Phase 3: centralized default transport registry

- **Status:** complete
- **Scope:** move public options into `http.base`, land `impl.registry`, route default client/server constructors through centralized resolution, and sync the HTTP control docs.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, architecture, task plan, findings, progress, and design conventions.
  - [x] Moved `THttpClientOptions` / `THttpServerOptions` into `src/nextpas.core.http.base.pas`.
  - [x] Added `src/nextpas.core.http.impl.registry.pas` with built-in H1 registration for `hvHttp10` / `hvHttp11`.
  - [x] Routed `THttpClient` / `THttpServer` default constructors through registry resolution.
  - [x] Added focused registry tests for missing-version errors and constructor default resolution.
  - [x] Added focused base tests for `THttpClientOptions.Default` / `THttpServerOptions.Default`.
  - [x] Ran focused registry/base/contract/client/server GREEN with heaptrc proof.
  - [x] Ran the full HTTP suite after the registry refactor.
  - [x] Updated inbox, coverage matrix, README/architecture, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Registry

| Check                  | Command                                                         | Result                                             |
| ---------------------- | --------------------------------------------------------------- | -------------------------------------------------- |
| Git safety state       | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files |
| Focused registry GREEN | `make -C tests/nextpas.core.http/test_http_registry clean test` | 4/4 passed, 0 unfreed memory blocks                |
| Focused base GREEN     | `make -C tests/nextpas.core.http/test_http_base clean test`     | 14/14 passed, 0 unfreed memory blocks              |
| Focused contract GREEN | `make -C tests/nextpas.core.http/test_http_contract clean test` | 21/21 passed, 0 unfreed memory blocks              |
| Focused client GREEN   | `make -C tests/nextpas.core.http/test_http_client clean test`   | 15/15 passed, 0 unfreed memory blocks              |
| Focused server GREEN   | `make -C tests/nextpas.core.http/test_http_server clean test`   | 20/20 passed, 0 unfreed memory blocks              |
| Full HTTP suite        | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test      |

## Notes 2026-06-02 Registry

- This batch finishes the transport-owner follow-up: default protocol selection is now centralized instead of being hardcoded inside `http.client` and `http.server`.
- The registry remains an internal implementation layer; the public extensibility seam is still explicit `IHttpTransport` / `IHttpServerTransport` injection.
- Built-in registry mapping is currently `hvHttp10` / `hvHttp11` -> H1, with `hvHttp11` as the default client/server version.
- Moving the public option records into `http.base` fixed the dependency direction problem: registry can now depend downward on base/intf/H1 without reaching upward into client/server.
- `test_http_smoke` still prints `True free heap : 260960 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`; this remains a non-blocking observation.

## Review 2026-06-02 Registry

- `/codex`-style review found no blocking issue in the landed registry design.
- The architectural gain in this batch is real centralization: constructor defaults now go through one internal owner, which is the right base for future H2/H3 registration.
- Shared-checkout risk remains unchanged: commit must stay path-limited to owned HTTP files only.
- Next route: return to malformed chunk/body parser/security focused tests before benchmark work.

## Session: 2026-06-01

### Phase 1: public contract audit and HTTP test baseline

- **Status:** complete
- **Scope:** inbox/plan/findings/progress plus stale H1 writer expectations.
- **Checklist:**
  - [x] Read active skill rules for planning, docs, and completion verification.
  - [x] Read `docs/design-conventions.md`.
  - [x] Checked Git state before edits.
  - [x] Confirmed current checkout is `main`, not a linked worktree.
  - [x] Re-read `docs/nextpas.core.http.inbox.md` and `task_plan.md`.
  - [x] Confirmed current HTTP baseline work and the remaining public API matrix gap.
  - [x] Updated the compact inbox/control map.
  - [x] Updated planning/findings/progress files for the current batch.
  - [x] Rerun the modified HTTP tests and capture fresh verification evidence.

## Verification Evidence

| Check                    | Command                                                                                    | Result                                         |
| ------------------------ | ------------------------------------------------------------------------------------------ | ---------------------------------------------- |
| Design conventions read  | `sed -n '1,620p' docs/design-conventions.md`                                               | Completed                                      |
| Git safety state         | `git status --short --branch`                                                              | Shared checkout is dirty outside this batch    |
| Worktree detection       | `git rev-parse --git-dir`, `git rev-parse --git-common-dir`                                | Normal checkout on `main`, not linked worktree |
| HTTP source inventory    | `find src -maxdepth 1 -name 'nextpas.core.http*.pas'`                                      | 22 source units                                |
| HTTP test inventory      | `find tests/nextpas.core.http -mindepth 1 -maxdepth 1 -type d`                             | 19 test projects                               |
| HTTP benchmark inventory | `find benchmarks/nextpas.core.http* -mindepth 1 -maxdepth 1 -type d`                       | 7 benchmark projects                           |
| Markdown formatting      | `prettier --write docs/nextpas.core.http.inbox.md task_plan.md findings.md progress.md`    | Completed                                      |
| Whitespace check         | `git diff --check -- docs/nextpas.core.http.inbox.md task_plan.md findings.md progress.md` | No errors                                      |
| Focused H1 writer test   | `make -C tests/nextpas.core.http/test_http_h1writer clean test`                            | 10/10 passed, 0 unfreed memory blocks          |
| Focused integration test | `make -C tests/nextpas.core.http/test_http_integration clean test`                         | 18/18 passed, 0 unfreed memory blocks          |
| Full HTTP suite          | `make TESTS_DIR=tests/nextpas.core.http test`                                              | All tests passed; heaptrc zero leaks per test  |

## Notes

- The root planning files now describe the active HTTP module ownership work and the current API audit phase.
- The H1 writer contract is treated as chunked-by-default only when neither `Content-Length` nor `Transfer-Encoding` is preset.
- `test_http_smoke` still prints `True free heap : 261232 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`.

## Error Log

| Timestamp  | Error                                               | Attempt | Resolution                                                                                 |
| ---------- | --------------------------------------------------- | ------- | ------------------------------------------------------------------------------------------ |
| 2026-06-01 | Stale root planning files from prior task           | 1       | Replaced with active HTTP plan/findings/progress                                           |
| 2026-06-01 | Shared checkout has unrelated dirty/untracked files | 1       | Kept this batch scoped to planning/control-map files                                       |
| 2026-06-01 | Stale H1 writer test expectations                   | 1       | Aligned the tests to current chunked framing                                               |
| 2026-06-02 | Tried to reuse `StrToBytes` in client tests         | 1       | Reverted to local test conversion; `StrToBytes` is private to `http.client` implementation |

## Session: 2026-06-02

### Phase 1: public API coverage matrix and client verb coverage

- **Status:** complete
- **Scope:** `IHttpClient` extra verb tests plus API coverage tracking docs.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, task plan, findings, and progress.
  - [x] Audited public HTTP source surfaces and current test registration points.
  - [x] Added `docs/http/API_COVERAGE.md`.
  - [x] Added focused tests for `IHttpClient.Put/Delete/Patch/Head`.
  - [x] Fixed test-only heaptrc leak caused by temporary response wrappers.
  - [x] Ran full HTTP suite after this batch.

## Verification Evidence 2026-06-02

| Check                   | Command                                                       | Result                                        |
| ----------------------- | ------------------------------------------------------------- | --------------------------------------------- |
| Git safety state        | `git status --short --branch`                                 | Shared checkout is dirty outside this batch   |
| Focused client test     | `make -C tests/nextpas.core.http/test_http_client clean test` | 13/13 passed, 0 unfreed memory blocks         |
| Full HTTP suite         | `make TESTS_DIR=tests/nextpas.core.http test`                 | All tests passed; heaptrc zero leaks per test |
| Design conventions read | `sed -n '1,1220p' docs/design-conventions.md`                 | Completed                                     |

## Notes 2026-06-02

- `IHttpClient` extra verbs were already implemented; this batch adds direct proof.
- The first client test run exposed a test helper leak: 13/13 passed but heaptrc reported 8 unfreed blocks. Root cause was temporary `THttpResponse` wrappers inside request handlers. Direct `IReader` reads fixed it.
- `test_http_smoke` still prints `True free heap : 261232 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`; this remains an observation rather than a failing leak signal.

## Review 2026-06-02

- `/codex` read-only review found no blocking issue.
- Review confirmed the new client verb tests use real local HTTP server/client paths rather than mocks.
- Review suggested avoiding an implementation-detail assertion for DELETE `Body=nil`; the test now asserts empty body behavior instead.
- Review reiterated the staging risk: do not use `git add .` in the dirty shared checkout.

## Session: 2026-06-02 transport contract shape

### Phase 1: transport public contract coverage

- **Status:** complete
- **Scope:** `IHttpTransport.RoundTrip` and `IHttpServerTransport.ServeConn` shape tests plus coverage docs.
- **Checklist:**
  - [x] Checked Git status before edits; HTTP files were clean, unrelated dirty/untracked files remain outside this batch.
  - [x] Re-read HTTP inbox, task plan, findings, progress, and API coverage matrix.
  - [x] Audited `http.intf`, facade re-exports, architecture docs, and source usage points.
  - [x] Confirmed transport interfaces are public shape seams only; no registry or injection owner exists yet.
  - [x] Added focused shape tests to `test_http_contract`.
  - [x] Ran full HTTP suite after this batch.

## Verification Evidence 2026-06-02 Transport

| Check                 | Command                                                         | Result                                        |
| --------------------- | --------------------------------------------------------------- | --------------------------------------------- |
| Git safety state      | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP         |
| Focused contract test | `make -C tests/nextpas.core.http/test_http_contract clean test` | 14/14 passed, 0 unfreed memory blocks         |
| Full HTTP suite       | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test |

## Notes 2026-06-02 Transport

- Transport tests deliberately avoid claiming production registry coverage.
- The current contract evidence is external implementability: mock classes can implement facade-exported `IHttpTransport` / `IHttpServerTransport`, receive request/handler parameters, and return or dispatch through the public HTTP types.

## Review 2026-06-02 Transport

- `/codex` read-only review found no blocking code issue.
- Review confirmed this batch proves public shape contract only, not facade-only smoke, registry, injection, protocol dispatch, or real TCP connection lifecycle.
- Review noted the full-suite evidence was still missing in its snapshot; mainline completed `make TESTS_DIR=tests/nextpas.core.http test` afterward and recorded the result above.
- Review reiterated the staging risk: the shared checkout has unrelated dirty/untracked files, so stage only the six owned HTTP files.

## Session: 2026-06-02 hijack lifecycle

### Phase 1: `IHttpHijacker` lifecycle and connection ownership

- **Status:** review
- **Scope:** facade alias, H1 writer hijack behavior, server ownership transfer after hijack.
- **Checklist:**
  - [x] Checked Git status before edits; HTTP target files were clean, unrelated dirty/untracked files remain outside this batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Added facade-only `IHttpHijacker` alias coverage to `test_http_contract`.
  - [x] Added `TH1ResponseWriter.Hijack` focused tests to `test_http_h1writer`.
  - [x] Added server integration test proving hijack keeps the connection open for handler ownership.
  - [x] Verified RED: facade alias missing and server closed hijacked connections after handler return.
  - [x] Re-exported `IHttpHijacker` from `nextpas.core.http`.
  - [x] Made `HandleConnection` return server connection ownership and guarded thread cleanup.
  - [x] Ran focused GREEN tests with heaptrc proof.
  - [x] Run full HTTP suite.
  - [x] Complete local `/codex`-style review and final diff check.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Hijack

| Check                   | Command                                                         | Result                                                          |
| ----------------------- | --------------------------------------------------------------- | --------------------------------------------------------------- |
| Git safety state        | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files              |
| RED facade alias        | `make -C tests/nextpas.core.http/test_http_contract clean test` | Failed to compile: `Identifier not found "IHttpHijacker"`       |
| RED server ownership    | `make -C tests/nextpas.core.http/test_http_server clean test`   | Failed new hijack ownership assertion; heaptrc 0 unfreed blocks |
| Focused contract GREEN  | `make -C tests/nextpas.core.http/test_http_contract clean test` | 15/15 passed, 0 unfreed memory blocks                           |
| Focused H1 writer GREEN | `make -C tests/nextpas.core.http/test_http_h1writer clean test` | 12/12 passed, 0 unfreed memory blocks                           |
| Focused server GREEN    | `make -C tests/nextpas.core.http/test_http_server clean test`   | 20/20 passed, 0 unfreed memory blocks                           |
| Full HTTP suite         | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test                   |

## Notes 2026-06-02 Hijack

- `TH1ResponseWriter` already had the correct direct hijack behavior; this batch made that contract explicit.
- The production fix is in server connection lifecycle, not in websocket code.
- `HandleConnection` now reports whether the server still owns the connection. After hijack, cleanup does not `Shutdown` or `Close` the stream.
- `/codex`-style read-only review found no blocking issue.
- Review noted that the first server hijack test treated any read exception as open-connection evidence; the test now proves ownership directly by reading a client probe byte from the handler-held `ITcpStream` after handler return.

## Session: 2026-06-02 facade callback and overload smoke

### Phase 1: facade helper/public forwarding completion

- **Status:** complete
- **Scope:** `HandlerFunc` callback aliases and facade `NewHttpServer` / `NewHttpClient` overload smoke.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Added failing contract tests for facade callback aliases and server/client overloads in `test_http_contract`.
  - [x] Verified RED: `nextpas.core.http.NewHttpServer(IHttpHandler)` was missing from the facade.
  - [x] Added `HandlerFunc` overloads for `THttpHandlerMethod` and `THttpHandlerProc` in middleware and facade.
  - [x] Added facade forwarding for `NewHttpServer(const AHandler: IHttpHandler)`.
  - [x] Ran focused GREEN contract tests with heaptrc proof.
  - [x] Ran full HTTP suite after the facade overload changes.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Facade

| Check                  | Command                                                         | Result                                                              |
| ---------------------- | --------------------------------------------------------------- | ------------------------------------------------------------------- |
| Git safety state       | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files                  |
| RED contract compile   | `make -C tests/nextpas.core.http/test_http_contract clean test` | Failed to compile: wrong parameter count for facade `NewHttpServer` |
| Focused contract GREEN | `make -C tests/nextpas.core.http/test_http_contract clean test` | 19/19 passed, 0 unfreed memory blocks                               |
| Full HTTP suite        | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test                       |

## Notes 2026-06-02 Facade

- This batch tightened public helper ergonomics rather than changing runtime HTTP semantics.
- `nextpas.core.http.HandlerFunc` now has explicit overloads for closure, plain procedure, and object method entry points.
- `test_http_contract` now locks the callback alias path and both server/client facade overload families through direct `nextpas.core.http.*` calls.

## Review 2026-06-02 Facade

- `/codex`-style read-only review found no blocking issue.
- Review risk remains unchanged: do not use `git add .` in the shared checkout, because unrelated files are dirty or untracked outside this batch.
- Review follow-up: the next correctness slice should move to H1 writer boundary behavior before any benchmark work.

## Session: 2026-06-02 H1 writer boundaries

### Phase 1: H1 response writer flush/finalization contract

- **Status:** complete
- **Scope:** `TH1ResponseWriter` boundary behavior for pre-set `Transfer-Encoding`, explicit `Content-Length`, and chunked flush finalization.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Added failing boundary tests in `test_http_h1writer`.
  - [x] Verified RED: writer still allowed `Write` after chunked `Flush`.
  - [x] Added focused coverage for pre-set `Transfer-Encoding` and explicit `Content-Length` flush path.
  - [x] Guarded `TH1ResponseWriter` against writes after chunked finalization.
  - [x] Ran focused GREEN writer tests with heaptrc proof.
  - [x] Ran full HTTP suite after the writer change.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 H1 Writer

| Check                | Command                                                         | Result                                                                                                          |
| -------------------- | --------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Git safety state     | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files                                                              |
| RED writer test      | `make -C tests/nextpas.core.http/test_http_h1writer clean test` | 14/15 passed; `Write after chunked flush raises` failed; heaptrc non-0 because the failing test aborted cleanup |
| Focused writer GREEN | `make -C tests/nextpas.core.http/test_http_h1writer clean test` | 15/15 passed, 0 unfreed memory blocks                                                                           |
| Full HTTP suite      | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test                                                                   |

## Notes 2026-06-02 H1 Writer

- This batch tightened the H1 response writer state machine without changing server/client public API shape.
- Chunked responses now become finalized after the terminal chunk is flushed, and later body writes raise `EHttpError`.
- Pre-set `Transfer-Encoding` remains caller-owned, and explicit `Content-Length` responses do not emit a chunk terminator on `Flush`.

## Review 2026-06-02 H1 Writer

- `/codex`-style read-only review found no blocking issue.
- Review risk remains unchanged: do not use `git add .` in the shared checkout, because unrelated files are dirty or untracked outside this batch.
- Review follow-up: the next correctness slice should move to client chunked-response and close-delimited response coverage.

## Session: 2026-06-02 client response framing coverage

### Phase 1: client chunked and close-delimited body proof

- **Status:** complete
- **Scope:** focused `IHttpClient` response-body coverage for chunked transfer and EOF-delimited framing.
- **Checklist:**
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Added focused chunked-response and close-delimited-response tests in `test_http_client`.
  - [x] Verified the existing implementation already satisfies both contracts; no production code change was required in this batch.
  - [x] Ran focused GREEN client tests with heaptrc proof.
  - [x] Ran full HTTP suite after the coverage change.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Client Framing

| Check               | Command                                                       | Result                                             |
| ------------------- | ------------------------------------------------------------- | -------------------------------------------------- |
| Git safety state    | `git status --short --branch`                                 | Shared checkout is dirty outside HTTP target files |
| Focused client test | `make -C tests/nextpas.core.http/test_http_client clean test` | 15/15 passed, 0 unfreed memory blocks              |
| Full HTTP suite     | `make TESTS_DIR=tests/nextpas.core.http test`                 | All tests passed; heaptrc zero leaks per test      |

## Notes 2026-06-02 Client Framing

- This batch is coverage-only by design: the new tests passed on the first run, so no production bugfix was needed.
- The chunked-response proof uses the normal `THttpServer` path to validate dechunked client body reads through real server/client I/O.
- The close-delimited proof uses a raw socket response without `Content-Length`, which exercises the parser EOF completion path used by `THttpClient.ReadResponse`.

## Review 2026-06-02 Client Framing

- `/codex`-style read-only review found no blocking issue.
- Review risk remains unchanged: do not use `git add .` in the shared checkout, because unrelated files are dirty or untracked outside this batch.
- Review follow-up: the next local HTTP slice should either add direct `TChunkedWriter` focused tests or audit close-delimited response reuse semantics in the client pooling path.

## Session: 2026-06-02 mixed commit cleanup

### Phase 1: git hygiene and traceability recovery

- **Status:** complete
- **Scope:** remove unrelated compiler/root-doc changes from the prior HTTP coverage commit without rewriting shared history.
- **Checklist:**
  - [x] Re-checked `git status`, `git show HEAD`, and repo prefix/root to isolate the mixed commit scope.
  - [x] Confirmed the accidentally committed compiler/root-doc paths had no further local edits in this worktree.
  - [x] Restored only the unrelated paths to `HEAD~1` and staged the cleanup diff.
  - [x] Re-ran focused client framing tests with heaptrc proof.
  - [x] Re-ran the full HTTP suite after the cleanup.
  - [x] Updated inbox, task plan, findings, and progress to record the cleanup honestly.
  - [x] Commit this cleanup as a follow-up hygiene batch.

## Verification Evidence 2026-06-02 Cleanup

| Check                     | Command                                                                                                                                                                                                                                                                    | Result                                            |
| ------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------- |
| Git mixed-commit audit    | `git show --format= --name-only HEAD`, `git diff --name-status HEAD~1..HEAD`, `git rev-parse --show-prefix`, `git rev-parse --show-toplevel`                                                                                                                               | Confirmed mixed commit scope and repo-root prefix |
| Worktree safety check     | `git status --short -- compiler/... docs/inbox.md`                                                                                                                                                                                                                         | No additional local edits on the cleanup targets  |
| Focused client test       | `make -C tests/nextpas.core.http/test_http_client clean test`                                                                                                                                                                                                              | Passed with heaptrc 0 unfreed memory blocks       |
| Full HTTP suite           | `make TESTS_DIR=tests/nextpas.core.http test`                                                                                                                                                                                                                              | All tests passed; heaptrc zero leaks per test     |
| Cleanup diff verification | `git diff --cached --name-status -- compiler/docs/compiler-goal-tree.md compiler/docs/plans/2026-06-02-c4d-sema-promotion-casts.md compiler/ir/np_hir_builder.pas compiler/sema/np_semantic_analyzer.pas compiler/tests/test_semantic_hir_expr_producer.pas docs/inbox.md` | Only unrelated paths staged for cleanup           |

## Notes 2026-06-02 Cleanup

- The HTTP client framing batch itself was already complete and verified; this session exists solely to recover clean history and scope discipline.
- The safe fix in this shared checkout is a follow-up cleanup commit, not any history rewrite, because unrelated dirty work still exists elsewhere in the repo.
- The next functional HTTP direction is unchanged: audit close-delimited pooling reuse semantics first, then decide whether `TChunkedWriter` deserves its own focused test surface.

## Review 2026-06-02 Cleanup

- `/codex`-style review conclusion: prioritize narrow follow-up cleanup over risky history edits in this shared tree.
- Root cause was index hygiene, not HTTP runtime logic.
- Batch discipline tightened: commit from repo root only after verifying both path scope and staged set.

## Session: 2026-06-02 client pooling semantics

### Phase 3: close-delimited and HTTP/1.0 reuse decisions

- **Status:** complete
- **Scope:** stop `http.client` from reusing connections when response framing/version semantics say the connection is not reusable.
- **Checklist:**
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Audited `THttpClient.ReadResponse` and pooling logic for framing-aware reuse decisions.
  - [x] Added RED parser tests for close-delimited, `Content-Length`, and HTTP/1.0 reuse semantics.
  - [x] Verified RED: `ShouldKeepAlive` seam was missing from `IH1Parser`.
  - [x] Added parser-level keep-alive inference and routed client pooling through it.
  - [x] Ran focused parser GREEN with heaptrc proof.
  - [x] Ran focused client GREEN with heaptrc proof.
  - [x] Ran the full HTTP suite after the fix.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Pooling

| Check                | Command                                                         | Result                                                  |
| -------------------- | --------------------------------------------------------------- | ------------------------------------------------------- |
| Git safety state     | `git status --short --branch`                                   | Shared checkout is dirty outside HTTP target files      |
| RED parser test      | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | Failed to compile: `IH1Parser` lacked `ShouldKeepAlive` |
| Focused parser GREEN | `make -C tests/nextpas.core.http/test_http_h1parser clean test` | 18/18 passed, 0 unfreed memory blocks                   |
| Focused client GREEN | `make -C tests/nextpas.core.http/test_http_client clean test`   | 15/15 passed, 0 unfreed memory blocks                   |
| Full HTTP suite      | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test           |

## Notes 2026-06-02 Pooling

- This batch is a real production fix, not coverage-only: the old client pooling rule only checked `Connection: close`, which did not encode all HTTP reuse semantics.
- The parser now owns response reuse inference for the client path, using parsed status code, framing headers, HTTP version, and `Connection` header together.
- The client now treats close-delimited responses and HTTP/1.0 responses without `Connection: keep-alive` as non-reusable connections.
- `test_http_smoke` still prints `True free heap : 261232 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`; this remains a non-blocking observation.

## Review 2026-06-02 Pooling

- `/codex`-style review found no blocking issue after the parser/client seam change.
- The important design correction is that pooling now depends on parsed framing semantics, not on a header-only shortcut in `http.client`.
- Follow-up route: move to direct `TChunkedWriter` focused tests before reopening larger transport-registry design work.

## Session: 2026-06-02 chunked writer focused tests

### Phase 2: helper-level chunk framing and finalization

- **Status:** complete
- **Scope:** direct `TChunkedWriter` focused coverage plus helper-level finalization guard.
- **Checklist:**
  - [x] Re-read HTTP inbox, API coverage, task plan, findings, progress, and design conventions.
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Audited `TChunkedWriter` and existing indirect H1 writer/server coverage.
  - [x] Added new focused project `test_http_h1chunked`.
  - [x] Verified RED: write after `Flush` failed the new test because helper allowed post-terminal writes.
  - [x] Added minimal `EHttpError` guard in `TChunkedWriter.Write` after terminal chunk finalization.
  - [x] Ran focused chunked GREEN with heaptrc proof.
  - [x] Ran focused H1 writer GREEN with heaptrc proof.
  - [x] Ran the full HTTP suite after the new test project and helper guard.
  - [x] Updated inbox, coverage matrix, findings, and progress.
  - [x] Commit this batch.

## Verification Evidence 2026-06-02 Chunked

| Check                 | Command                                                          | Result                                                                                    |
| --------------------- | ---------------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Git safety state      | `git status --short --branch`                                    | Shared checkout is dirty outside HTTP target files                                        |
| RED chunked helper    | `make -C tests/nextpas.core.http/test_http_h1chunked clean test` | 5/6 passed; `Write after Flush raises` failed; failing run showed heaptrc residual blocks |
| Focused chunked GREEN | `make -C tests/nextpas.core.http/test_http_h1chunked clean test` | 6/6 passed, 0 unfreed memory blocks                                                       |
| Focused writer GREEN  | `make -C tests/nextpas.core.http/test_http_h1writer clean test`  | 15/15 passed, 0 unfreed memory blocks                                                     |
| Full HTTP suite       | `make TESTS_DIR=tests/nextpas.core.http test`                    | All tests passed; heaptrc zero leaks per test                                             |

## Notes 2026-06-02 Chunked

- This batch is a real helper-level hardening fix: `TH1ResponseWriter` already guarded finalized writes, but `TChunkedWriter` itself still accepted them.
- The new focused test project proves chunk framing directly instead of relying on response-writer/server integration tests.
- `test_http_smoke` still prints `True free heap : 261232 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`; this remains a non-blocking observation.

## Review 2026-06-02 Chunked

- `/codex`-style review found no blocking issue in the helper hardening batch.
- The invariant now lives at both levels: `TH1ResponseWriter` rejects finalized response writes, and `TChunkedWriter` rejects post-terminal chunk writes.
- Follow-up route: return to transport registry / client-server injection ownership design, or add malformed inbound chunk/body parser/security tests before that if H1 correctness remains the priority.

## Session: 2026-06-02 transport injection seam

### Phase 2/3: default H1 transport ownership and explicit injection

- **Status:** complete
- **Scope:** extract default H1 client/server protocol ownership into `impl.h1`, and make `IHttpTransport` / `IHttpServerTransport` usable through public client/server factory overloads.
- **Checklist:**
  - [x] Re-read HTTP inbox, API coverage, architecture, task plan, findings, progress, and design conventions.
  - [x] Checked Git status before edits; unrelated dirty/untracked files remain outside this HTTP batch.
  - [x] Added RED contract tests for explicit `NewHttpClient` / `NewHttpServer` transport injection overloads.
  - [x] Verified RED: contract build failed because overloads and constructor seams did not exist.
  - [x] Added `nextpas.core.http.impl.h1.pas` as the default H1 transport owner.
  - [x] Refactored `http.client` to orchestrate redirect/helper behavior over `IHttpTransport`.
  - [x] Refactored `http.server` to own listener/accept/thread orchestration over `IHttpServerTransport`.
  - [x] Added facade forwarding overloads for explicit transport injection.
  - [x] Ran focused contract/client/server GREEN with heaptrc proof.
  - [x] Ran the full HTTP suite after the transport-owner refactor.
  - [x] Updated inbox, coverage matrix, README/architecture, findings, and progress.
  - [ ] Commit this batch.

## Verification Evidence 2026-06-02 Transport Seam

| Check                  | Command                                                         | Result                                                                       |
| ---------------------- | --------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Git safety state       | `git status --short --branch`                                   | Shared checkout is dirty outside owned HTTP target files                     |
| RED contract compile   | `make -C tests/nextpas.core.http/test_http_contract clean test` | Failed to compile: transport injection overloads / constructor seams missing |
| Focused contract GREEN | `make -C tests/nextpas.core.http/test_http_contract clean test` | 21/21 passed, 0 unfreed memory blocks                                        |
| Focused client GREEN   | `make -C tests/nextpas.core.http/test_http_client clean test`   | 15/15 passed, 0 unfreed memory blocks                                        |
| Focused server GREEN   | `make -C tests/nextpas.core.http/test_http_server clean test`   | 20/20 passed, 0 unfreed memory blocks                                        |
| Full HTTP suite        | `make TESTS_DIR=tests/nextpas.core.http test`                   | All tests passed; heaptrc zero leaks per test                                |

## Notes 2026-06-02 Transport Seam

- This batch changed architecture, not just contract sugar: the default H1 client/server protocol owner is now a real implementation unit instead of logic split across two skeletons.
- Public client/server factories now have an explicit transport injection seam, which makes mock transports, alternate protocol implementations, and future registry work practical.
- `impl.registry` still does not exist; default protocol selection is therefore not centralized yet.
- `test_http_smoke` still prints `True free heap : 260960 / Should be : 262144`, but heaptrc reports `0 unfreed memory blocks`; this remains a non-blocking observation.

## Review 2026-06-02 Transport Seam

- `/codex`-style review found no blocking issue after the transport-owner refactor.
- The important architectural correction is that `IHttpTransport` / `IHttpServerTransport` now have a production owner and a public injection seam; they are no longer shape-only abstractions.
- Next route: implement a real `impl.registry` default-resolution layer before H2/H3 work, or return to malformed chunk/body parser hardening if staying strictly in H1 correctness mode.
