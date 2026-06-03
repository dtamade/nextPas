# Progress Log: http h1 poll-driven phase2 step5

## Session

- **Scope:** 把 `nextpas.core.http` 的 stalled-peer / write-timeout contract 再推进一格：
  补 live backpressure close-observation characterization，
  证明 malformed follow-up 在 timed stalled drain 下也不会漏出 follow-up `400`。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- H1 / backpressure 主线现在的真实状态是：
  - untimed poll path 已有 active+1 queued ordered response queue
  - timed stalled drain 仍禁止 later pipelined request consumption
  - 当前 live proof 进一步确认 malformed follow-up 也不会被漏成 follow-up `400`

## Completed work

- 审阅现有 real-socket backpressure proof 与 H1 timed drain state。
- 在 `tests/nextpas.core.http/test_http_server` 落地：
  - `CountSubstring` helper
  - threaded / epoll 两条 live proof：
    - `Real socket write timeout backpressure does not emit follow-up 400`
  - 新增断言同时锁定：
    - no follow-up `400`
    - only one status line on wire
- 本轮没有改生产代码：
  - 新 characterization 直接证明当前实现已经满足这条更细的 live truth
- 在文档与控制文件同步真实状态：
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `119/119 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- HTTP correctness 主线如果继续往前走，建议切到 benchmark：
  - 建 H1 server/client 基线
  - 对照 FPC RTL / Go / Rust
  - 再回头找 hot path 是否需要 SIMD / scan 优化
