# Findings: expect interim-100 malformed chunk framing proof

## Scope

- 上一刀已经锁住了 `Expect: 100-continue` 发出 interim `100` 后，
  invalid chunk-size 的 after-interim truth。
- 本轮继续补更贴近 chunk framing grammar 的相邻缺口：
  interim `100` 发出后，如果 chunked body 出现 malformed chunk extension
  或 missing chunk-data CRLF，server 仍应返回 final `400 Bad Request`，
  不会进入 handler，也不会误补 synthetic `500`。

## Confirmed truths

### 1. `Expect + chunked malformed chunk framing after interim 100` 之前确实缺双层 proof

- `test_http_security` / `test_http_server` 之前都已经覆盖：
  - `Expect` 正向 fixed-length
  - `Expect` 正向 chunked
  - `Expect + chunked MaxBodySize -> 413`
  - after-interim invalid chunk-size -> final `400`
  - after-interim timeout 邻接 truth
  - bodyless / no-length 不发 interim `100`
  - unsupported `Expect` / transfer-coding error
- 但缺少更直接的 malformed-after-interim truth：
  - interim `100` 已发出后，malformed chunk extension 仍应落到 final `400`
  - interim `100` 已发出后，missing chunk-data CRLF 仍应落到 final `400`

### 2. 新增 malformed-after-interim focused tests 后直接 GREEN，说明这轮只是补证

- 在
  [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增了 4 条 raw-wire focused tests：
  - threaded `Expect: chunked malformed chunk extension rejects after interim 100`
  - threaded `Expect: chunked missing chunk-data CRLF rejects after interim 100`
  - epoll `Expect: chunked malformed chunk extension rejects after interim 100`
  - epoll `Expect: chunked missing chunk-data CRLF rejects after interim 100`
- 在
  [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增了 4 条 public-contract focused tests：
  - threaded `Expect: chunked malformed chunk extension rejects after interim response`
  - threaded `Expect: chunked missing chunk-data CRLF rejects after interim response`
  - epoll `Expect: chunked malformed chunk extension rejects after interim response`
  - epoll `Expect: chunked missing chunk-data CRLF rejects after interim response`
- 这 8 条都直接锁住：
  - 先收到 `HTTP/1.1 100 Continue`
  - malformed chunk body 到达前不会误回 `200`
  - malformed chunk extension 到达后最终返回 `400 Bad Request`
  - missing chunk-data CRLF 到达后最终返回 `400 Bad Request`
  - 不会重复 interim `100`
  - 不会追加 synthetic `500`
  - 不会误回成功响应
  - handler 永远不会进入
- 两个 focused gate 都直接 GREEN，说明当前生产代码已经自然满足这条契约，
  本轮不需要再动生产代码。

### 3. `Expect` request-side contract 的 malformed chunk framing 邻接分支已闭环

- security 层：
  - 直接 raw-wire truth
  - 证明 threaded / epoll 两条 live path 在 malformed chunk extension /
    missing chunk-data CRLF 情况下都返回 final `400`，不补 `500`
- server 层：
  - 更贴近 public API / contract 的 focused live proof
  - 证明 handler 不进入、不会误发成功响应
- 因此 `Expect after interim 100 + malformed chunk framing -> final 400`
  这条 request-side runtime truth 现在不再是隐含行为，而是完成了双层补证。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security test`
    - `212/212 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `242/242 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是对 `Expect` request-side 契约的 malformed-after-interim 邻接补证，不是新的
  行为修改。
- 目前 `Expect` request-side contract 已经覆盖：
  - positive fixed-length
  - positive chunked
  - declared oversize early reject
  - after-interim `MaxBodySize -> 413`
  - after-interim invalid chunk-size -> final `400`
  - after-interim malformed chunk extension -> final `400`
  - after-interim missing chunk-data CRLF -> final `400`
  - bodyless / no-length no interim `100`
  - unsupported `Expect` / malformed transfer-coding early reject
  - after-interim partial body stall safe-close / no synthetic `500`
  - after-interim zero-progress idle-timeout safe-close / no synthetic `500`
- 下一刀更自然的是继续找：
  - 仍未分类完的 raw-wire malformed / runtime 小缺口
  - 优先挑 after-interim trailer grammar 的代表性缺口，而不是继续宽铺同型 parity
