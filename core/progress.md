# Progress Log: http h1 initial poll-driven bridge

## Session

- **Scope:** 让 `TH1ServerConnectionState` 真正实现 `ITcpServerPollDrivenSession`，
  先把 H1 接到 poll-driven foundation / `WorkerHandoff` 主干上，
  但本轮不直接做完整 reactor-owned H1 state machine。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- H1 现在已经暴露 poll-driven session seam，不再只是 blocking `Run` 黑盒。
- 但当前还是 bridge 形态：
  首次 readability 后把整连接 `Run` 提交给 worker，
  还没有把 parser / drain 拆到 reactor-owned state machine。

## Completed work

- 审阅并确认当前缺口：
  - foundation 已有 poll-driven wake / deadline wake
  - H1 仍缺真正的 poll-driven session shape
  - 这批先做 H1 bridge，不先强上完整 state machine
- 先承接 RED：
  - `test_http_server` 锁 context-aware H1 session 现在必须暴露 `ITcpServerPollDrivenSession`
- 在 `src/nextpas.core.http.impl.h1.pas` 落地：
  - `TH1ServerConnectionState` 实现 `ITcpServerPollDrivenSession`
  - 初始 `PollEvents = [peReadable]`
  - 首次 readability 后通过 `WorkerHandoff` 提交整连接 `Run`
  - completion synthetic re-entry 后返回最终 ownership
  - `WakeDeadline` 先保守返回 `Infinite`
- 在 focused tests 落地：
  - `tests/nextpas.core.http/test_http_server`
    - context-aware H1 session 现在暴露 poll-driven seam
- 在文档落地：
  - `docs/http/ARCHITECTURE.md`
  - `docs/http/API_COVERAGE.md`

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `112/112 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 直接进入真正的 H1 poll-driven phase 2：
  - 把整连接 `Run` bridge 拆成 reactor-owned request parse / handler handoff / outbound drain
  - 把 `IH1OutboundBuffer.TryDrainTo` 接进生产路径
  - 把 `WakeDeadline` 接进 H1 的 read/write timeout 语义
  - 再收敛 bounded outbound queue / backpressure 策略
