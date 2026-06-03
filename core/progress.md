# Progress Log: http h1 poll-driven phase2 step3

## Session

- **Scope:** 把 `nextpas.core.http` 的 H1 poll-driven runtime 再推进一格：
  把 `WriteTimeout` / `WakeDeadline` 真正接进 poll-driven response drain，
  让 timed drain 也脱离旧的 worker-owned blocking path。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- H1 poll-driven 路径的 successful response drain 现在已经统一脱离 worker 内同步 drain。
- 当前真实状态是：
  - request-side socket read / parser drive 已回到 reactor
  - 每个已完成 request 会独立 handoff
  - buffered follow-up request 不必等新的 readability
  - successful response drain 已进入 reactor-owned 调度
  - `WriteTimeout > 0` 时也已经暴露 `WakeDeadline` 并在到期时关闭 stalled drain

## Completed work

- 审阅 H1 timed drain seam、epoll deadline wake 与既有 write-timeout contract。
- 先承接 RED：
  - `tests/nextpas.core.http/test_http_server`
    直接证明 `WriteTimeout > 0` 的 poll path 也不能再在 worker 内同步 `Write`，
    并锁定 deadline wake 以 `Advance([], ...)` 收口。
- 在 `src/nextpas.core.http.impl.h1.pas` 落地：
  - 新增 timed poll state：`FPollWriteDeadline`
  - 所有 poll-path response drain 都改走 reactor-owned outbound state
  - completion wake 会立即尝试一次 `TryDrainTo`
  - `would-block` 时切换到 `peWritable`
  - `WriteTimeout > 0` 时会暴露有限 `WakeDeadline`
  - deadline 到期时 session 会安全关闭，不做额外写重试
  - keep-alive follow-up request 仍可在 drain 完成后继续推进
- 在 `tests/nextpas.core.http/test_http_server` 落地：
  - context-aware H1 poll-driven timed-drain deadline-wake focused proof
- 在文档与控制文件同步真实状态：
  - `docs/http/ARCHITECTURE.md`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `116/116 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 继续 H1 poll-driven phase 2 的下一格：
  - 设计 bounded outbound queue / multi-response ordering contract
  - 细化 stalled-peer timing / close-observation characterization
  - 再进入 benchmark / Go-Rust 对标
