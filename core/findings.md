# Findings: expect interim-100 body-stall server contract proof

## Scope

- 上一刀已经在 security 层拿到 RED -> GREEN，并修掉了 threaded whole-run
  路径把 request-side read failure 误补 synthetic `500` 的问题。
- 本轮不再改生产代码，只把同一条 truth 补成
  `IHttpServer` public-contract focused proof，确保 server 层也直接锁住：
  `Expect: 100-continue` 发出 interim `100` 后，如果 body 只到达一部分然后
  stall，连接会安全关闭，不会进入 handler，也不会再补 final status。

## Confirmed truths

### 1. `test_http_server` 之前确实缺这一条 public-contract proof

- `test_http_server` 之前已经覆盖：
  - `Expect` 正向 fixed-length
  - `Expect` 正向 chunked
  - `Expect + chunked MaxBodySize -> 413`
  - bodyless / no-length 不发 interim `100`
  - unsupported `Expect` / transfer-coding error
- 但缺少一条更贴近 `IHttpServer` 合同面的 live proof：
  - interim `100` 已发出后，partial body stall 的 safe-close 语义

### 2. 新增 server focused tests 后直接 GREEN，说明上一刀生产修复已成立

- 在
  [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增了 4 条 focused tests：
  - threaded `Expect: fixed-length body stall closes safely after interim response`
  - threaded `Expect: chunked body stall closes safely after interim response`
  - epoll `Expect: fixed-length body stall closes safely after interim response`
  - epoll `Expect: chunked body stall closes safely after interim response`
- 这四条都直接锁住：
  - 先收到 `HTTP/1.1 100 Continue`
  - body byte 到齐前不会误回 `200`
  - stall 之后连接会在观察窗口内关闭
  - 不会重复 interim `100`
  - 不会追加 synthetic `500`
  - 不会再发任何 final status line
  - handler 永远不会进入
- focused gate 直接 GREEN，说明上一刀生产修复已经自然满足 server 层契约，
  本轮不需要再动生产代码。

### 3. `IHttpServer` 的 `Expect` request-side contract 现在在两层证据上闭环

- security 层：
  - 直接 raw-wire truth
  - 证明 threaded / epoll 两条 live path 都安全关闭，不补 `500`
- server 层：
  - 更贴近 public API / contract 的 focused live proof
  - 证明 handler 不进入、不会再发 final status line
- 因此 `Expect after interim 100 + body stall` 这条 request-side runtime truth
  现在不再只停留在 security 修复事实，而是完成了 public-contract 收口。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `232/232 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是对上一刀生产修复的 server 层补证，不是新的行为修改。
- 目前 `Expect` request-side contract 已经覆盖：
  - positive fixed-length
  - positive chunked
  - declared oversize early reject
  - after-interim `MaxBodySize -> 413`
  - bodyless / no-length no interim `100`
  - unsupported `Expect` / malformed transfer-coding early reject
  - after-interim body stall safe-close / no synthetic `500`
- 下一刀更自然的是继续找：
  - 仍未分类完的 raw-wire malformed / runtime 小缺口
  - 而不是继续在 `Expect` 分支上做机械平铺
