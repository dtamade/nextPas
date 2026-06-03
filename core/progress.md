# Progress Log: http HEAD explicit Content-Length no-body contract batch

## Session

- **Scope:** 收紧 `nextpas.core.http` 的 `HEAD + explicit Content-Length + no body` 契约。
- **Status:** complete

## Baseline audit

- 读过 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、`docs/http/ARCHITECTURE.md`、
  `docs/net/ARCHITECTURE.md` 与 `docs/plans/2026-06-03-http-server-runtime-foundation.md`，
  确认 server runtime 方向已固定到 `nextpas.core.net.server`，本轮不再讨论选型。
- 核对 `git status --short`：
  仓库存在多处非 HTTP 脏改动，包括 `../.claude/*`、`../.worktrees/*`、
  `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr` 等；本轮严格 path-limited。
- 接续时 HTTP 未提交改动主要在 4 个 test 文件：
  `test_http_h1parser`、`test_http_h1writer`、`test_http_server`、`test_http_client`。

## RED proof

- `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - 编译失败
  - 直接原因：`NewH1ResponseParser(True)` overload 尚不存在
  - 这条 RED 证明当前 parser/client 还拿不到 `HEAD` skip-body hint

## Completed work

- `src/nextpas.core.http.impl.h1.parser.pas`
  - 新增 `NewH1ResponseParser(const ASkipBody: Boolean)` internal overload
  - 给 `TH1Parser` 增加 `FSkipBody`
  - 在 init/reset 后重施 `HTTP_HEAD` / `F_SKIPBODY` hint
  - 让 `ResponseEndsAtEof` / `ShouldKeepAlive` 与 skip-body 语义保持一致
- `src/nextpas.core.http.impl.h1.pas`
  - `TH1ClientTransport.ReadResponse` 现在接收原始 request method
  - `RoundTrip` 在 `HEAD` 时把 skip-body hint 传给 response parser
- `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
  - 新增 `HEAD`-style response parser proof：显式 `Content-Length` 下无 body bytes 也能完成并保持 keep-alive
- `tests/nextpas.core.http/test_http_h1writer/test_http_h1writer.lpr`
  - 新增 suppress-body 保留显式 `Content-Length` 的 focused proof
- `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - 新增 raw-wire `HEAD` response 保留显式 `Content-Length` 且不写 body 的 proof
- `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - 把 `HEAD` client contract 收紧到“保留 `Content-Length` header、body 仍为空”
- `docs/http/API_COVERAGE.md`
  - 记录本轮 parser/client/server/writer 的新 proof，并移除该项最高优先 gap

## Verification

- `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `82 total, 82 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_client clean test`
  - `16 total, 16 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  - `21 total, 21 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `87 total, 87 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Outcome

- `HEAD` response 的 server-side no-body wire contract 现在不仅不写 body，也能保留显式 `Content-Length`。
- client-side H1 parser 现在能正确理解这类 response，不再把 `Content-Length` 当成必须读取的 body。
- public HTTP surface 未变化；收口的是 H1 internal seam 与 focused proof。
