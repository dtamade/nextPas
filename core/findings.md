# Findings: http security oversize-trailer backpressure proof

## Scope

- 本轮回到 malformed chunked raw-wire security 主线，不扩新生产语义，
  只把 `chunked oversize trailer -> 431` 接到 live direct-error
  backpressure 证据链上。

## Confirmed truths

### 1. `431` 先前已有普通 live / poll seam proof，但还缺 live direct-error backpressure proof

- `oversize trailer` 先前已有：
  - 普通 raw-wire live proof：`431 or safe-close`
  - poll-driven standalone writable-drain proof
  - write-timeout / partial-timeout `431` proof
- 但 live direct-error backpressure 侧先前只锁住了：
  - malformed `400`
  - unsupported `Expect` `417`
  - unsupported transfer-coding `501`
- 缺的正是 trailer-limit 这条独立 `431` 状态分支。

### 2. 现有 generic direct-error path 已经天然支持这条 `431`，本轮不需要生产修复

- 在 [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增两个 focused tests 后，直接 GREEN：
  - threaded `chunked oversize trailer` direct-error backpressure
  - epoll `chunked oversize trailer` direct-error backpressure
- 这直接证明 trailer-limit `431` 不需要额外特殊分支；现有 direct-error
  live close / preserve-status 逻辑已经能正确兜住它。

因此这轮是 coverage-expansion，不是生产修复。

### 3. focused gate 顺手暴露了一个既有旧测试 truth 偏差，并已按当前实现校正

- `Request line too long` 旧断言原先只接受 `414/400/404/200/empty`。
- 但当前实现里 request-line bytes 同样受 `MaxHeaderSize` 预算约束：
  - [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
    会在 headers-stage 以 `HTTP_STATUS_HEADER_TOO_LARGE` 直接裁决。
- 这意味着超长 URL 在当前 truth 下完全可能走 `431`，而旧测试没有接受
  该结果，导致 focused suite 首轮出现一处既有 RED。
- 本轮只校正测试 truth，不改生产代码。

### 4. 现在 malformed chunked live direct-error 代表性状态更完整

- standalone direct-error 在 backpressure 尝试下现在至少已经有：
  - malformed `400`
  - oversize trailer `431`
  - unsupported `Expect` `417`
  - unsupported transfer-coding `501`
- threaded / epoll 两条 live 路径都证明：
  - 不进入成功 handler
  - 不追加 synthetic `500`
  - wire 上至多暴露一条原始 status line 前缀
  - 连接会在观测窗口内安全关闭

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security test`
    - `122/122 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- malformed chunked 这条线上，低价值 parity 已经很多，下一刀不能再机械复制。
- 更值得做的两个方向是：
  - 继续只挑仍未分类完的 runtime / malformed 边角
  - 或转回 `Expect` 组合/优先级 characterization
