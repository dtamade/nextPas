# Findings: http request-side idle-timeout live proofs

## Scope

- 本轮继续留在 H1 correctness 主线，但从 malformed parity 收口切回更高价值的 runtime contract。
- 目标不是扩大生产逻辑，而是确认 request-side `IdleTimeout` 在 real-socket live 路径上的语义：部分请求不会误进成功 handler，会在超时后安全关闭。

## Confirmed truths

### 1. request-side `IdleTimeout` 的 live-socket truth 现在补到了 security

- 新增的 security proof 直接覆盖：
  - slowloris partial request eventually closes
  - partial fixed-length body stall eventually closes
  - partial chunked trailer stall eventually closes
- 并且这三条 live proof 现在都已有 Linux `epoll` backend 对应证据。

### 2. 这轮把 server 层已有的 poll-driven timeout truth 向外部 real-socket 视角补了一层证据

- `test_http_server` 早就锁定了 request-side `WakeDeadline` / timeout-close 语义，但那是 transport/session seam 视角。
- 这轮之后，security 也能直接证明外部 peer 在 live socket 上看到的是：
  - 连接最终被关闭
  - partial request 不会误拿到 `200`
  - partial body / partial trailer 也不会误进入 echo handler

### 3. 本轮没有暴露生产缺口，不需要修 transport / parser

- 新增用例直接 GREEN，说明当前 parser + H1 transport 的现有拒绝路径已经自然延伸到 epoll live backend。
- 因此这一批保持为 coverage-expansion；没有新增生产代码，也没有引入新的行为分叉。

### 4. 下一步应重新筛查还缺的真实 runtime truth gap，而不是继续机械扩 malformed parity

- 既然 request-tail、chunk/trailer truncation、request-side timeout 这几块都已经补到比较实了，再继续复制同型 malformed case 的收益已经很低。
- 更值的下一刀有两个方向：
  - 重新筛查 security / contract 是否还有真正未对齐的 runtime truth
  - 如果 security 只剩机械 parity，就转去更高价值的 correctness / public API 边界

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `111/111 passed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮补的是 request-side timeout 的 live-socket truth，不是新的生产行为变更。
- 本轮没有形成行为级 RED；暴露出来的是 coverage gap，而不是生产缺陷。
- benchmark 继续后置；当前阶段仍以 correctness 和接口契约收口优先。
