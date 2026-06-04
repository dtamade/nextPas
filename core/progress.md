# Progress Log: http H1 poll-driven IdleTimeout parity

## Session

- **Scope:** 给 `TH1ServerConnectionState` 的 poll-driven request parse 路径补上
  read-side `IdleTimeout` / `WakeDeadline` parity。
- **Status:** verified

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas:1)
  现在为 poll-driven H1 request parse 增加了 read-side deadline 生命周期：
  - 新增 `FPollReadDeadline`
  - 初始 request parse 会 arm read deadline
  - request reset 进入下一次 parse 时会重新 arm
  - request handoff / parse error / timeout close 会 clear
  - `WakeDeadline` 现在返回 read/write deadline 的最小值
- [test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr:1)
  新增了 `h1 poll-driven session times out idle read wait before first request`
  focused test，直接锁定：
  - 第一个 request byte 到来前就会 arm read deadline
  - `WakeDeadline` 不是 infinite
  - 超时后 session 安全关闭
  - timeout close 后 `WakeDeadline` 会清回 infinite
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md:1)
  已同步这条新的 request-side poll-driven `IdleTimeout` focused proof，并把下一步缺口收敛到
  mid-request stall characterization。

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `174/174 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `27/27 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 继续把 request-side timeout proof 从 “pre-first-byte idle wait” 扩到
  partial mid-request body / trailer stalls
- 然后回到 malformed raw-wire chunked request security proof，把 server-side
  `400` / safe-close 语义再压紧一轮
