# Progress Log: nextpas.core.http response-side write-timeout safety proof

## Session

- **Scope:** 在不重开 server/runtime 架构的前提下，补齐 `WriteTimeout` /
  partial-write timeout / backpressure 风险点的 focused server proof，并把 proof
  从 fake-stream 推进到 initial real-socket stalled-peer 场景。
- **Status:** completed

## Current state

- server/runtime 设计文件已经固定，当前权威链路是：
  - `docs/net/ARCHITECTURE.md`
  - `docs/http/ARCHITECTURE.md`
  - `docs/plans/2026-06-03-http-server-runtime-foundation.md`
- 共享 worktree 仍是脏的；本轮继续只碰 `nextpas.core.http` 相关测试与控制面文件。
- 本轮没有改生产代码，因为 timeout/backpressure 语义在现有实现中已被证明成立。
- 额外的 `src/nextpas.core.net.tcp.pas` patch 已通过隔离 worktree 对比判定为“不必要生产改动”，最终未保留。

## Completed work

- `test_http_server` 新增 timeout/backpressure focused proof：
  - `Write timeout before any wire bytes does not append 500`
  - `Write timeout after partial wire bytes stops pipeline without 500`
- `test_http_server` 新增 real-socket stalled-peer proof：
  - `Real socket write timeout backpressure stops pipeline`
- 新增 `TTimeoutWriteTcpStream` fake transport，用来脚本化模拟：
  - pre-wire timeout
  - partial-write timeout
- 新增 real-socket helper：
  - `TSocketTuningServerTransport`
  - `StartServerWithTransportAndOptions(...)`
  - recv/send buffer tuning + `ReadUntilClosedOrDeadline(...)`
- 顺手提取了 `DefaultH1ServerTransportOptions(...)`，避免 test 内重复映射 HTTP -> H1 transport options。
- 更新 `docs/http/API_COVERAGE.md`，把 write-timeout safety proof 纳入 `IHttpServer` 覆盖结论。
- 更新 `task_plan.md`、`findings.md`、`progress.md`，同步这轮真相与下一步方向。
- 用 detached worktree 做了“带/不带 `net.tcp` patch”对比，证明这批不需要生产修复。

## Verification

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `110/110 passed`
  - heaptrc：`0 unfreed memory blocks`
- `make -C core/tests/nextpas.core.http/test_http_server clean test`
  - detached worktree / 无 `net.tcp` patch：`110/110 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 若继续沿 response-side correctness 推进，下一步应从“已有 initial real-socket proof”进入 backend-differential characterization：
  - threaded / epoll 对 stalled-peer close-observation 的差异
  - backpressure timing 是否需要更底层 transport/runtime seam 才能稳定分类
- 在没有新的 RED 之前，不建议为了“看起来更完整”去改生产代码。
