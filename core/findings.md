# Findings: http H1 poll-driven mid-request IdleTimeout proof

## Scope

- 本轮继续留在 `nextpas.core.http` 的 poll-driven request-side timeout 主线。
- 目标不是继续写生产修复，而是先确认 mid-request stall 的 current truth 到底是不是
  还缺契约。

## Confirmed truths

### 1. 现有实现已经覆盖 partial mid-request stall，不需要再补生产代码

- 新增 focused tests 后：
  - partial `Content-Length` body stall
  - partial chunked trailer stall
- 两条都直接通过，说明上轮补进去的 `FPollReadDeadline` 生命周期已经自然覆盖到这些
  mid-request parse 场景。

### 2. request-side timeout 语义现在更像“request parse 周期 deadline”，而不是 per-chunk idle timer

- session 创建时会 arm 一次 read deadline。
- 进入下一次 request parse reset 时才会重新 arm。
- partial request progress 本身不会 re-arm deadline。
- 这和 blocking `Run` 路径更接近：它也是在 request parse 周期开始时设一次
  `SetReadDeadline(now + IdleTimeout)`，而不是每读到一点数据就续期。

### 3. 这条 current truth 同时也是更好的性能路径

- 如果每次 partial body/trailer progress 都重置 deadline，会引入额外 deadline churn。
- 当前实现与新增测试一起锁定了：
  - partial progress 不会偷改 read deadline
  - timeout close 只在真正超时后发生
  - timeout close 后 `WakeDeadline` 会清回 infinite

### 4. reactor/readiness 调度顺序没有暴露额外生产缺口

- readiness runtime 在 poll loop 每轮末尾仍会处理 expired targets。
- 本轮 focused 测试也已经直接证明：在 synthetic deadline wake 下，
  mid-request stall 会稳定 timeout close。
- 当前没有额外证据表明还需要为这条 synthetic path 再扩一次生产状态机。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `176/176 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是 synthetic poll-driven focused truth，不是 live socket close-time characterization。
- raw-wire malformed chunked request security proof 仍然是更应该回去推进的 correctness 主线。
- 如果后续出现 threaded / epoll live slowloris parity 问题，再回头扩 request-side
  timeout coverage会更值；现在继续在 synthetic timeout 上空转收益不高。
