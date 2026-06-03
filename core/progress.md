# Progress Log: http h1 poll-driven phase2 step1

## Session

- **Scope:** 把 `nextpas.core.http` 的 H1 poll-driven runtime 从
  “整连接一次 worker bridge” 推进到
  “reactor 负责 request-side read/parse，按已完成 request 独立 handoff”，
  但本轮不先做 outbound drain / deadline 的 reactor-owned state machine。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- H1 poll-driven 路径已经不再是首次 readability 后整连接一次 `Run` 提交。
- 当前真实状态是：
  - request-side socket read / parser drive 已回到 reactor
  - 每个已完成 request 会独立 handoff
  - buffered follow-up request 不必等新的 readability
  - outbound drain / `WakeDeadline` 还没有进入 reactor-owned 调度

## Completed work

- 审阅当前 H1 poll-driven bridge、context-aware session seam、completion wake 路径与既有 HTTP contract。
- 先承接 RED：
  - `tests/nextpas.core.http/test_http_server`
    直接证明同连接上两个已完成请求不能再在第一次 handoff 里一起跑完。
- 在 `src/nextpas.core.http.impl.h1.pas` 落地：
  - 新增 poll-path request work item
  - reactor 直接负责 `ITcpStreamRuntime.TryRead` + `IH1Parser.Execute`
  - 每个完整 request 独立提交给 worker
  - completion wake 后若 `FPending` 已有 follow-up request，会立刻继续 parse / submit
  - 无 `ITcpStreamRuntime` 时保留旧的 whole-run fallback
- 在 `tests/nextpas.core.http/test_http_server` 落地：
  - context-aware H1 poll-driven session per-request handoff focused proof
- 在文档与控制文件同步真实状态：
  - `docs/http/ARCHITECTURE.md`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `114/114 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 继续 H1 poll-driven phase 2 的下一格：
  - 把 `IH1OutboundBuffer.TryDrainTo` 接进 poll-driven 生产路径
  - 让 `peWritable` / would-block / write deadline 进入状态机
  - 再决定 bounded outbound queue 与 backpressure contract
