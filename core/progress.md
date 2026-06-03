# Progress Log: http h1 poll-driven phase2 step4

## Session

- **Scope:** 把 `nextpas.core.http` 的 H1 poll-driven runtime 再推进一格：
  落地 bounded outbound queue / ordered completion 的最小语义，
  同时守住 timed/backpressure safety contract。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- H1 poll-driven 路径现在的真实状态是：
  - request-side read / parse 已 reactor-owned
  - per-request handoff 已 reactor-owned
  - successful response drain 已 reactor-owned
  - timed drain / `WakeDeadline` 已进入同一条 response state machine
  - untimed path 现在新增 active+1 queued 的有界 ordered response queue

## Completed work

- 审阅 H1 poll state、worker completion 生命周期与既有 timed/backpressure contract。
- 先承接 RED：
  - `tests/nextpas.core.http/test_http_server`
    新增 `H1 poll-driven session queues bounded responses while draining`
    focused proof。
- 在 `src/nextpas.core.http.impl.h1.pas` 落地：
  - `TH1PollRequestWork` 现在只生成本次 request 的 outbound/result
  - completion 持有 work 引用并在 reactor 侧应用 result
  - poll path 新增 active response + 1 queued response
  - follow-up parse error 的 `400` / `413` / `431` 也会按 wire 顺序排队
  - partial follow-up parser state 可以跨 response drain 保留
  - `WriteTimeout > 0` 的 timed drain 继续优先首轮 nonblocking drain，
    stalled 时不再消费 later pipelined request
- 在 `tests/nextpas.core.http/test_http_server` 同步：
  - bounded queue proof
  - 去掉对 inline completion next-event 形状的过度冻结
- 在文档与控制文件同步真实状态：
  - `docs/http/ARCHITECTURE.md`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `117/117 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 继续 H1 poll-driven phase 2 的下一格：
  - 细化 stalled-peer timing / close-observation characterization
  - 再决定 queue fairness 是否还要继续扩到 2+ queued response
  - benchmark 后置，最后再做 Go / Rust 对标
