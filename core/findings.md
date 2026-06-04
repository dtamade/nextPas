# Findings: http server head expect-continue no-body guard proof

## Scope

- 本轮继续 request-side protocol completeness，不扩散成更大的 `Expect`
  矩阵，只把 `Expect: 100-continue` 在 HEAD no-body 请求上的守卫语义
  直接锁下来。

## Confirmed truths

### 1. `Expect` 的 no-body guard 还差一个 method 相邻分支

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  里的 `ShouldSendContinueResponse` 已经要求：
  - `RequestExpectsContinue(AParser)`
  - `RequestDeclaresBody(AParser)`
- 也就是说，实现上本来就打算只在“请求确实声明 body”时才发
  interim `100 Continue`。
- 前两刀已经锁了：
  - `Content-Length: 0 + Expect: 100-continue`
  - 普通 no-length `POST + Expect: 100-continue`
- 但“不同 method 上是否也保持同样 no-body guard”还没有 direct live proof。

### 2. `HEAD + Expect` 是高价值但仍然足够窄的相邻 case

- `RequestDeclaresBody` 本身不看 method，因此：
  - no-length `HEAD + Expect` 也不应等待 body
  - 更不应误发 `100 Continue`
- 同时 HEAD 还有自己独立的 response-side no-body contract。
- 这条 case 因而还能顺手验证：
  - request-side `Expect` no-body guard
  - response-side HEAD body suppression
  两者不会互相打架。

### 3. 现有生产行为直接 GREEN，说明 no-body guard 在 HEAD 分支也成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 两条 live proofs：
  - `HEAD /head-expect` + `Expect: 100-continue`，但无 `Content-Length` / `Transfer-Encoding`
    -> 直接 final `200`
  - 响应里不出现 interim `100 Continue`
- handler 会被正常调用
- HEAD 响应仍保留 `content-length` 且不把 body bytes 写到 wire
- focused gate 直接 GREEN，说明当前生产代码已经满足这条契约，本轮不需要生产修复。

### 4. 现在 `Expect` request-side live contract 的“要不要发 100”边界更完整了

- 已有 direct live truth：
  - fixed-length body -> interim `100`
  - chunked body -> interim `100`
  - chunked after-interim overflow -> final `413`
  - declared oversize body -> early `413`, no interim `100`
  - unsupported `Expect` -> early `417`, no interim `100`
  - bodyless `Content-Length: 0` -> final `200`, no interim `100`
  - bodyless no-length request -> final `200`, no interim `100`
  - no-length `HEAD + Expect` -> final `200`, no interim `100`
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `206/206 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮把 HEAD method 也接进来了，但还没系统铺开：
  - 其他 method 上的 bodyless `Expect` characterization
  - 更复杂的 `Expect` 组合 / OWS / repeated header-line characterization
- 下一刀如果继续做 `Expect`，应该仍保持“小而真”，不要一次扩成大矩阵。
