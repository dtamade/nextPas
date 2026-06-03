# Findings: http h1 poll-driven phase2 step5

## Scope

- 这轮继续留在 H1 poll-driven / backpressure 主线。
- 目标是把 stalled-peer close-observation 从“eventual safe-close”再收紧到更具体的 wire truth，
  但仍不冻结严格 `WriteTimeout` SLA。

## Confirmed truths

### 1. 现有 live backpressure proof 还缺一条 malformed follow-up truth

- 上一轮已经锁住：
  - 连接最终会关闭
  - 不会继续进入后续合法 handler
  - 不会补写 synthetic `500`
- 但还没有直接证明：
  - 若 follow-up request 本身是 malformed，
    timed stalled drain 下也不会额外漏出 follow-up `400`

### 2. 当前实现已经满足更细的 close-observation truth

- 新增 real-socket characterization 后确认：
  - threaded 与 Linux `epoll` 两条 backend
  - 在 stalled-peer / write-timeout 场景下
  - malformed follow-up 同样不会被继续消费成 follow-up `400`
  - wire 上也只会看到首个 response status line

### 3. 这轮仍然不应误冻两条暂不稳定的东西

- 不应把 `WriteTimeout = 50ms` 固定成严格 close-time SLA。
- 不应把 handler-return timing 当成 public contract。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `119/119 passed`
  - 新增 proof：
    - `Real socket write timeout backpressure does not emit follow-up 400`
    - `Real socket write timeout backpressure does not emit follow-up 400 with epoll backend`
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- 当前 stalled-peer characterization 仍是 correctness-first，不是性能终版。
- benchmark / Go-Rust 对标还没开始。
- 若下一轮继续 runtime 主线，最合理的是：
  - 开始 benchmark 基线与对照，
  - 或者只在发现新的 live timing truth 空档时再回补 correctness proof。
