# Findings: expect interim-100 body-stall idle-timeout truth

## Scope

- 本轮继续停在 `3/6 H1 正确性加固` 主线，但不再机械复制 malformed
  parity case，而是挑了一个更高价值的 request-side runtime 缺口：
  `Expect: 100-continue` 已发出 interim `100` 之后，如果 body 只到达一部分
  然后 stall，server 是否会按 `IdleTimeout` 安全关闭，而不是误补 synthetic
  `500`。
- 这轮先在 security 层写 live focused proof，先 RED，再决定是否需要生产修复。

## Confirmed truths

### 1. 新增的 `Expect + partial body stall` live proofs 先拿到了有价值的 RED

- 在
  [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增了 4 条 focused tests：
  - threaded `Expect fixed-length partial body idle-timeout closes after interim 100`
  - threaded `Expect chunked partial body idle-timeout closes after interim 100`
  - epoll `Expect fixed-length partial body idle-timeout closes after interim 100`
  - epoll `Expect chunked partial body idle-timeout closes after interim 100`
- focused gate 首次运行结果是：
  - `202 total, 200 passed, 2 failed`
  - 失败仅限 threaded 的两条
  - epoll 两条直接 GREEN
- 失败断言是：
  - `stalled body does not append synthetic 500`
- 因此目标契约本身没问题，差异确实存在于 threaded whole-run 路径。

### 2. threaded live 路径的真实根因不是最初猜的 `read deadline exceeded`

- 初看
  [src/nextpas.core.net.tcp.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.net.tcp.pas)
  容易以为 read timeout 会抛
  `ENetworkError('read deadline exceeded')`，因为 `TryRead` / `ApplyReadTimeout`
  都有这条分支。
- 但 threaded live path 在
  [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  的 `TH1ServerConnectionState.Run` 用的是 blocking `FConn.Read(...)`，
  不是 `TryRead(...)`。
- blocking `TTcpStream.Read` 的真实行为是：
  - 先 `ApplyReadTimeout` 只设置 `SO_RCVTIMEO`
  - 之后直接调用 `platform_socket_recv(...)`
  - 如果 socket timeout 触发，Linux 上 `recv` 会返回错误码
    `EAGAIN/EWOULDBLOCK`
  - `TTcpStream.Read` 会把它统一包装成
    `ENetworkError('tcp read failed (...)')`
- 所以最初只识别 `read deadline exceeded` 的最小修复没有打中真实异常形态。

### 3. synthetic `500` 的来源已经锁定在 `TH1ServerConnectionState.Run`

- 真正写出 synthetic `500` 的位置是
  [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  里 `TH1ServerConnectionState.Run` 的 outer `try/except`。
- 在 interim `100` 已发出后，如果后续 body read 因 timeout 变成
  `ENetworkError('tcp read failed (...)')`，旧代码会把这类 request-side
  ingress 读失败误判成内部错误并补写 `500`。
- epoll backend 不会落这条 whole-run 异常兜底，所以之前已经是正确的安全关闭语义。

### 4. 最小生产修复已经让 threaded / epoll 重新对齐

- 在
  [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  增加了很窄的 helper：
  - `IsRequestReadFailure(const E: Exception): Boolean`
- 只在 `TH1ServerConnectionState.Run` 的 outer `except` 使用它：
  - request-side read failure 直接安全关闭
  - 不再补写 final `500`
  - 其他异常仍保持原有 `500` 语义
- 这保持了修复范围最小，只针对 threaded ingress read failure 收口，
  不扩散到 handler 异常、write-timeout 或 direct-error 契约。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
    - `202/202 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮修掉的是一个真实 threaded / epoll 语义分叉，不是单纯补文档 truth。
- 目前 `Expect` request-side contract 的大分支已经比较完整：
  - 正向 fixed-length
  - 正向 chunked
  - after-interim `MaxBodySize -> 413`
  - bodyless / no-length 不发 interim `100`
  - unsupported `Expect -> 417`
  - after-interim body stall -> safe-close / no synthetic `500`
- 下一刀不应该再回到大面积 parity 平铺，更自然的是继续挑：
  - 仍未分类完的 request-side runtime / malformed 小缺口
  - 或者 `test_http_server` 是否还缺同主题但更贴近 public contract 的 focused proof
