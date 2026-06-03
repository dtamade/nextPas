# Findings: http h1 poll-driven phase2 step4

## Scope

- 这轮继续停留在 H1 poll-driven phase 2 主线。
- 目标不是继续补 malformed grammar 碎片，而是把 bounded outbound queue / ordering 这条 runtime contract 真正落下去。

## Confirmed truths

### 1. 最小 queue 语义不是“多加一个 buffer”那么简单

- 直接把第二个 response 塞进队列还不够。
- 如果 worker 仍直接改 `FPollOutbound` / `FPollResponsePending` / close 语义，
  poll state 会继续跨线程散落，设计不稳。
- 这轮先把 worker result 改成 completion-applied handoff：
  worker 只生成本次 request 的 outbound/result，
  reactor completion 再统一应用到 poll state machine。

### 2. 有界 queue 的最小可行形状已经成立

- 当前落地的是：
  - `active drain`
  - `+ 1 queued response`
- 在 untimed poll path 下：
  - 首个 response 未开始 socket drain 前
  - 一个 buffered follow-up request 可以继续完成
  - 第三个 request 必须等 slot 释放后才能继续

### 3. 只有 queue 还不够，follow-up parse error 也必须按 wire 顺序排队

- 新一轮实现里实际踩到的关键坑是：
  若首个合法 response 还 pending，就把 follow-up malformed request 的 `400`
  直接写回 socket，会打乱 wire 顺序。
- 现在这条已收口：
  - response pending 时的 follow-up `400` / `413` / `431`
    也会排到前一个 response 后面
  - partial follow-up parser state 也能跨 response drain 保留

### 4. timed/backpressure safety boundary 仍然守住

- `WriteTimeout > 0` 时，completion wake 仍先尝试第一次 nonblocking drain。
- 一旦进入 stalled timed drain，就不会继续消费 later pipelined request。
- 这条保持了前几轮已经锁住的 real-socket backpressure contract。

## Verification evidence

- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `117/117 passed`
  - 新增 proof：
    - `H1 poll-driven session queues bounded responses while draining`
  - 既有 proof 未回归：
    - epoll keep-alive / pipelining
    - follow-up malformed `400` ordering
    - timed drain / write-timeout / backpressure safety
  - heaptrc：`0 unfreed memory blocks`

## Remaining gaps / risks

- 当前 queue 仍是 correctness-first 的最小形状，不是最终吞吐/公平性终版。
- 还没有细化 stalled-peer timing / close-observation characterization。
- 还没有做 benchmark / Go-Rust 对标。
