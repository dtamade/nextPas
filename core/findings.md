# Findings: expect interim-100 truncated trailer field-name EOF proof

## Scope

- 上一刀已经锁住了 `Expect: 100-continue` 在 interim `100` 发出后，
  malformed trailer field / oversize trailer 的 after-interim truth。
- 本轮继续补更贴近 EOF 邻接的小缺口：
  interim `100` 发出后，如果 chunked trailer 的 field-name 在 EOF 前被截断，
  server 仍应返回 final `400 Bad Request`，且不应进入 handler，
  也不应误补 synthetic `500`。

## Confirmed truths

### 1. 现有 after-interim helper 之前不能直接表达 trailer EOF 截断

- 现有 `RunExpectContinueChunkedMalformedBodyRejectedAfterInterim...`
  helper 只覆盖“收到 `100` 后继续写完整 malformed body，再读 final response”的路径。
- 但 trailer EOF 截断需要更窄的 raw-wire 形状：
  - 先发请求头
  - 收到 interim `100 Continue`
  - 只发送部分 trailer field-name
  - 客户端执行 write-half-close
  - 再读取 final `400`
- 因此先做了一次 RED，确认 helper 缺少
  `shutdown-after-body` 这个最小表达能力。

### 2. 新增最小 helper 扩展后，after-interim trailer field-name EOF 直接 GREEN

- 在
  [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  给现有 after-interim malformed helper 增加了可选
  `shutdown-after-body` 参数，并新增了 2 条 raw-wire focused tests：
  - threaded `Expect chunked truncated trailer field-name EOF rejects after interim 100`
  - epoll `Expect chunked truncated trailer field-name EOF rejects after interim 100`
- 在
  [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  对称扩展同型 helper，并新增了 2 条 public-contract focused tests：
  - threaded `Expect: chunked truncated trailer field-name EOF rejects after interim response`
  - epoll `Expect: chunked truncated trailer field-name EOF rejects after interim response`
- 这 4 条 tests 直接锁住：
  - 先收到单条 `HTTP/1.1 100 Continue`
  - partial trailer field-name + peer write-half-close 后最终返回 `400 Bad Request`
  - final response 不重复 interim `100`
  - final response 不误回 `200`
  - handler 永远不会进入
- focused gate 直接 GREEN，说明当前生产代码已经自然满足这条契约，
  本轮不需要生产修复。

### 3. `Expect` request-side contract 的 trailer EOF 邻接 truth 进一步闭环

- 非 `Expect` 路径此前已经有 parser / security / server 三层
  `truncated trailer field-name at EOF -> 400` 证据。
- 本轮把同一 truth 延伸到 after-interim `100 Continue` 路径后，
  request-side runtime truth 进一步闭环：
  - 请求已进入 `Expect` body phase 也不会放松 trailer EOF 校验
  - threaded / epoll 两条 live path 都稳定落到 final `400`
  - handler 不会因为 interim `100` 已发出而被误放行

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security test`
    - `218/218 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `248/248 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是 `Expect` request-side 契约的 EOF 邻接补证，不是行为修改。
- 现有 helper 现在已经能表达 “收到 `100` 后写 partial body / trailer 再 shutdown”
  的窄场景，后续相邻 case 可以复用，不需要再复制一套 helper。
- 下一刀更自然的是继续挑一个 after-interim trailer EOF 邻接 case：
  - `truncated trailer separator at EOF after interim 100`
  - 或 `truncated trailer field line at EOF after interim 100`
- 继续保持单刀推进，不再宽铺同型 parity。
