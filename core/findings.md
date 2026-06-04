# Findings: http poll-driven chunked-not-final direct-error proof

## Scope

- 本轮不碰生产逻辑，只继续收口 `HttpServer` poll-driven direct-error seam。
- 目标是确认 `Transfer-Encoding: chunked, gzip` 这条
  `chunked`-not-final malformed request 不只在 parser / generic server / epoll live backend
  上返回 `400`，在 poll-driven standalone direct-error writable-drain 路径上也保持同样语义。

## Confirmed truths

### 1. 这条 malformed `400` 之前还缺一条 poll-driven standalone direct-error seam 证据

- 现有证据已经包括：
  - parser focused proof：`Transfer-Encoding: chunked, gzip` 会被判为 malformed
  - server focused proof：generic/threaded 路径返回显式 `400`
  - security live proof：`epoll` backend raw-wire 返回显式 `400`
- 现有 poll-driven standalone direct-error seam 已覆盖：
  - generic bad request `400`
  - invalid chunk-size `400`
  - missing chunk-data CRLF `400`
  - unsupported transfer-coding before chunked `501`
- 但 `chunked, gzip -> 400` 这条 transfer-coding order malformed 还没有自己的 poll-driven writable-drain proof。

### 2. 当前实现对这条 malformed request 也会走 poll-driven reactor-owned writable drain

- `test_http_server` 新增 focused proof：
  - `H1 poll-driven standalone chunked-not-final transfer-coding drains via writable events`
- 新 case 直接锁定：
  - 请求：`Transfer-Encoding: chunked, gzip`
  - handler 不会被调用
  - 不发生 worker handoff
  - direct error 不回退到 sync socket write
  - writable wake 后会写出 `HTTP/1.1 400 Bad Request`

新测试直接通过，说明 runtime 当前已把这条 malformed transfer-coding order contract 收敛到 poll-driven direct-error seam。

### 3. 本轮仍是 coverage-expansion，不需要生产修复

- 没有新增实现改动。
- 新测试直接通过，说明已有运行时行为已经满足我们要冻结的 seam 语义。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `178/178 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这一刀只补一条缺失的 poll-driven seam 证据，不应继续把同型 malformed `400` 分支机械铺满。
- 下一步更值的方向仍应二选一：
  - 回到真正还没分类完的 runtime / malformed 边角
  - 或开始审视 `3/6 H1 正确性加固` 的阶段收口条件，避免继续低价值补洞
