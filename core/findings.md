# Findings: http epoll chunked-not-final security parity

## Scope

- 本轮不碰生产逻辑，只继续收口 `HttpServer` malformed chunked security。
- 目标是确认 `Transfer-Encoding: chunked, gzip` 这条
  `chunked`-not-final malformed request 不只在 threaded/generic 路径返回 `400`，
  在 `epoll` live backend 下也保持同样语义。

## Confirmed truths

### 1. `chunked`-must-be-final 之前缺少一条 epoll live parity 证据

- 现有证据已经包括：
  - parser focused proof：`Transfer-Encoding: chunked, gzip` 会被判为 malformed
  - server focused proof：threaded/generic 路径返回显式 `400`
  - security epoll live parity：已经覆盖 `gzip, chunked -> 501`、多类 chunk/trailer EOF、以及其他代表性 malformed chunked `400`
- 但 `chunked, gzip -> 400` 这条 still lacked its own epoll raw-wire proof。

如果不补这一刀，就还不能说 transfer-coding order 这条 malformed chunked contract 在 epoll live backend 上已经闭环。

### 2. 当前实现对这条 malformed request 在 epoll live backend 下也返回显式 `400`

- `test_http_security` 新增 focused/live proof：
  - `Chunked must be final transfer coding -> 400 with epoll backend`
- 新 case 直接锁定：
  - 请求：`Transfer-Encoding: chunked, gzip`
  - backend：`TCP_SERVER_BACKEND_EPOLL`
  - raw-wire 结果：显式 `HTTP/1.1 400`

新测试直接通过，说明 runtime 当前已把这条 malformed transfer-coding order contract 收敛到 threaded 与 epoll 一致。

### 3. 本轮仍是 coverage-expansion，不需要生产修复

- 没有新增实现改动。
- 新测试直接通过，说明已有运行时行为已经满足我们要冻结的 backend parity 语义。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security test`
    - `118/118 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这一刀只补一条缺失的 epoll live parity，不应继续把 transfer-coding order 分支无限细分。
- 下一步更值的方向仍应二选一：
  - 回到真正还没分类完的 runtime / malformed 边角
  - 或开始审视 `3/6 H1 正确性加固` 的阶段收口条件，避免继续低价值补洞
