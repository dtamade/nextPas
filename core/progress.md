# Progress Log: http h1 poll-driven phase2 step2

## Session

- **Scope:** 把 `nextpas.core.http` 的 H1 poll-driven runtime 再推进一格：
  让 successful response 在 `WriteTimeout = 0` 的 poll path 下
  从 worker 内同步 socket write 改成 reactor-owned nonblocking drain，
  但本轮不先把 deadline / timed backpressure 一起并入状态机。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- H1 poll-driven 路径已经不再依赖 worker 内同步 drain 才能完成成功响应，至少在 `WriteTimeout = 0` 的路径上已经不是。
- 当前真实状态是：
  - request-side socket read / parser drive 已回到 reactor
  - 每个已完成 request 会独立 handoff
  - buffered follow-up request 不必等新的 readability
  - `WriteTimeout = 0` 的 successful response drain 已进入 reactor-owned 调度
  - timed drain / `WakeDeadline` 还没有进入 reactor-owned 调度

## Completed work

- 审阅 H1 poll-driven state、`IH1OutboundBuffer.TryDrainTo`、epoll completion wake 与既有 HTTP contract。
- 先承接 RED：
  - `tests/nextpas.core.http/test_http_server`
    直接证明 poll path 不能再在 worker 内同步 `Write` successful response。
- 在 `src/nextpas.core.http.impl.h1.pas` 落地：
  - 新增 poll response state：`FPollOutbound` / `FPollResponsePending`
  - `WriteTimeout = 0` 时，worker 只生产 response，不再同步 drain socket
  - completion wake 会立即尝试一次 `TryDrainTo`
  - `would-block` 时切换到 `peWritable`
  - drain 完成后 keep-alive follow-up request 仍可继续推进
  - `WriteTimeout > 0` 暂时保留旧的 worker-owned blocking drain
- 在 `tests/nextpas.core.http/test_http_server` 落地：
  - context-aware H1 poll-driven response writable-drain focused proof
- 在文档与控制文件同步真实状态：
  - `docs/http/ARCHITECTURE.md`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `115/115 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 继续 H1 poll-driven phase 2 的下一格：
  - 把 `WakeDeadline` / `WriteTimeout` 真正接进 poll-driven drain
  - 固定 timed backpressure close semantics
  - 再决定 bounded outbound queue / multi-response ordering contract
