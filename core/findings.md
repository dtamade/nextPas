# Findings: expect interim-100 zero-progress idle-timeout proof

## Scope

- 上一刀已经锁住了 `Expect: 100-continue` 发出 interim `100` 后，
  partial body stall 的安全关闭语义。
- 本轮继续补它的自然相邻缺口：interim `100` 发出后，如果 body 一个字节都
  不再到达，连接仍会按 `IdleTimeout` 安全关闭，不会进入 handler，也不会再补
  final status。

## Confirmed truths

### 1. zero-progress 之前确实缺 raw-wire + public-contract 双层 proof

- `test_http_security` / `test_http_server` 之前都已经覆盖：
  - `Expect` 正向 fixed-length
  - `Expect` 正向 chunked
  - `Expect + chunked MaxBodySize -> 413`
  - after-interim partial body stall safe-close
  - bodyless / no-length 不发 interim `100`
  - unsupported `Expect` / transfer-coding error
- 但缺少 zero-progress 这条更窄的 live truth：
  - interim `100` 已发出后，body 一个字节都不再发，连接仍会安全关闭

### 2. 新增 zero-progress focused tests 后直接 GREEN，说明这轮只是补证

- 在
  [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增了 4 条 raw-wire focused tests：
  - threaded `Expect: fixed-length zero body progress idle-timeout`
  - threaded `Expect: chunked zero body progress idle-timeout`
  - epoll `Expect: fixed-length zero body progress idle-timeout`
  - epoll `Expect: chunked zero body progress idle-timeout`
- 在
  [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增了 4 条 public-contract focused tests：
  - threaded `Expect: fixed-length zero body progress idle-timeout closes after interim response`
  - threaded `Expect: chunked zero body progress idle-timeout closes after interim response`
  - epoll `Expect: fixed-length zero body progress idle-timeout closes after interim response`
  - epoll `Expect: chunked zero body progress idle-timeout closes after interim response`
- 这 8 条都直接锁住：
  - 先收到 `HTTP/1.1 100 Continue`
  - body byte 到齐前不会误回 `200`
  - stall 之后连接会在观察窗口内关闭
  - 不会重复 interim `100`
  - 不会追加 synthetic `500`
  - 不会再发任何 final status line
  - handler 永远不会进入
- 两个 focused gate 都直接 GREEN，说明当前生产代码已经自然满足这条契约，
  本轮不需要再动生产代码。

### 3. `Expect` request-side contract 的 zero-progress 邻接分支已闭环

- security 层：
  - 直接 raw-wire truth
  - 证明 threaded / epoll 两条 live path 在 zero-progress 情况下都安全关闭，
    不补 `500`
- server 层：
  - 更贴近 public API / contract 的 focused live proof
  - 证明 handler 不进入、不会再发 final status line
- 因此 `Expect after interim 100 + zero body progress idle-timeout` 这条
  request-side runtime truth 现在不再是隐含行为，而是完成了双层补证。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
    - `206/206 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
    - `236/236 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是对 `Expect` request-side 契约的 zero-progress 邻接补证，不是新的
  行为修改。
- 目前 `Expect` request-side contract 已经覆盖：
  - positive fixed-length
  - positive chunked
  - declared oversize early reject
  - after-interim `MaxBodySize -> 413`
  - bodyless / no-length no interim `100`
  - unsupported `Expect` / malformed transfer-coding early reject
  - after-interim partial body stall safe-close / no synthetic `500`
  - after-interim zero-progress idle-timeout safe-close / no synthetic `500`
- 下一刀更自然的是继续找：
  - 仍未分类完的 raw-wire malformed / runtime 小缺口
  - 而不是继续在 `Expect` 分支上做机械平铺
