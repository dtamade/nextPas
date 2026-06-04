# Findings: expect interim-100 truncated trailer empty-value section CR EOF proof

## Scope

- 上一刀已经锁住了 `Expect: 100-continue` 在 interim `100` 发出后，
  truncated trailer whitespace EOF 的 after-interim truth。
- 本轮继续补更贴近 EOF 邻接的小缺口：
  interim `100` 发出后，如果 chunked trailer field 已经完成 empty-value line，
  trailer section closing 只收到单个 `CR` 就直接 EOF 截断，
  server 仍应返回 final `400 Bad Request`，且不应进入 handler，
  也不应误补 synthetic `500`。

## Confirmed truths

### 1. 现有 after-interim helper 已足够表达 empty-value section CR EOF 截断

- 上一刀已经给
  `RunExpectContinueChunkedMalformedBodyRejectedAfterInterim...`
  helper 增加了可选 `shutdown-after-body` 路径。
- 因此这轮不需要再改 helper 形状，只要复用同一路径，把请求体切成：
  - `5\r\nhello\r\n`
  - `0\r\n`
  - partial trailer empty-value section CR `X-Test:\r\n\r`
  - 然后客户端 write-half-close
- 这使得本轮真正保持为纯测试补证，而不是再做测试基础设施扩展。

### 2. after-interim trailer empty-value section CR EOF focused tests 直接 GREEN

- 在
  [tests/nextpas.core.http/test_http_security/test_http_security.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_security/test_http_security.lpr)
  新增了 2 条 raw-wire focused tests：
  - threaded `Expect chunked truncated trailer empty-value section CR EOF rejects after interim 100`
  - epoll `Expect chunked truncated trailer empty-value section CR EOF rejects after interim 100`
- 在
  [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增了 2 条 public-contract focused tests：
  - threaded `Expect: chunked truncated trailer empty-value section CR EOF rejects after interim response`
  - epoll `Expect: chunked truncated trailer empty-value section CR EOF rejects after interim response`
- 这 4 条 tests 直接锁住：
  - 先收到单条 `HTTP/1.1 100 Continue`
  - partial trailer empty-value section CR + peer write-half-close 后最终返回 `400 Bad Request`
  - final response 不重复 interim `100`
  - final response 不误回 `200`
  - handler 永远不会进入
- focused gate 直接 GREEN，说明当前生产代码已经自然满足这条契约，
  本轮不需要生产修复。

### 3. `Expect` request-side contract 的 trailer EOF 邻接 truth 再补一格

- 非 `Expect` 路径此前已经有 parser / security / server 三层
  `truncated trailer empty-value section CR at EOF -> 400` 证据。
- 本轮把同一 truth 延伸到 after-interim `100 Continue` 路径后，
  request-side runtime truth 再补一格：
  - 请求已进入 `Expect` body phase 也不会放松 trailer section closing CR EOF 校验
  - threaded / epoll 两条 live path 都稳定落到 final `400`
  - handler 不会因为 interim `100` 已发出而被误放行

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_security test`
    - `234/234 passed`
    - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `264/264 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮是 `Expect` request-side 契约的 EOF 邻接补证，不是行为修改。
- 现有 helper 现在已经能表达 `field-name` / `separator` / `empty-value` / `empty-value section CR` / `whitespace` / `field line` / `field CR` / `section` / `section CR` 九个 after-interim
  trailer EOF 邻接形状，后续可以继续复用。
- 下一刀更自然的是继续挑一个 after-interim trailer EOF 邻接 case：
  - `truncated trailer whitespace section EOF after interim 100`
  - 或 `truncated trailer whitespace section CR EOF after interim 100`
- 继续保持单刀推进，不宽铺同型 parity。
