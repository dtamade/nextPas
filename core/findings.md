# Findings: http server expect-continue chunked ingress coverage

## Scope

- 本轮继续 request-side protocol completeness，不扩散成更大的 `Expect`
  矩阵，只把 `Expect: 100-continue` 和 chunked ingress 的 live contract
  直接锁下来。

## Confirmed truths

### 1. `Expect + chunked` 这条 request-side live contract 先前缺直接证据

- 先前已有：
  - fixed-length `Expect: 100-continue -> interim 100 -> final 200`
  - declared oversize `Content-Length` under `Expect` -> early `413`
- 但还没有把 chunked ingress 接进同一条 live 证据链：
  - valid chunked body after interim `100`
  - cross-chunk `MaxBodySize` overflow after interim `100`

### 2. 首轮 failed case 不是生产 bug，而是测试体 chunk framing 自己写错了

- 首轮新增的 oversize chunked case failed 在：
  - `chunked oversize rejected with final 413 after interim 100`
- 但复盘后发现问题不在 server，而在测试 literal：
  - header 写的是 `2BC`（700 bytes）
  - 实际两段 body literal 只有 `477` / `476` bytes
- 这会把 case 自己变成 malformed chunked request，自然不能拿来证明
  `413 after interim 100`。

### 3. 把 oversize case 改成动态构造真实 700-byte chunks 后，现有生产行为直接 GREEN

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  把 oversize case 改成：
  - 运行时 `SetLength + FillChar`
  - `IntToHex(Length(chunk), 1)` 生成匹配的 chunk-size line
- 校正后两条新增契约都直接 GREEN，说明当前生产代码已经满足：
  - chunked body 在 interim `100` 之后可被正常解码
  - chunked ingress 在收到 `100` 之后跨 chunk 越过 `MaxBodySize` 会最终返回 `413`

### 4. 现在 `Expect` request-side live contract 更完整了

- threaded / epoll 两条 live 路径现在直接锁住：
  - `Expect + chunked` -> interim `100 Continue`
  - handler 能读到 decoded chunked body
  - `Expect + chunked + MaxBodySize` after-interim overflow -> final `413`
- 因此这轮是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `200/200 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮把 chunked ingress 接进 `Expect` live contract 了，但还没系统铺开：
  - bodyless `Expect: 100-continue`
  - 更复杂的 `Expect` 组合 / OWS / repeated header-line characterization
- 下一刀如果继续做 `Expect`，应该仍保持“小而真”，不要一次扩成大矩阵。
