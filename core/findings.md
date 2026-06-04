# Findings: http server bodyless expect-continue guard proof

## Scope

- 本轮继续 request-side protocol completeness，不扩散成更大的 `Expect`
  矩阵，只把 `Expect: 100-continue` 在 no-body 请求上的守卫语义直接锁下来。

## Confirmed truths

### 1. `Expect` 的 no-body guard 先前只靠实现阅读，没有 direct live proof

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  里的 `ShouldSendContinueResponse` 已经要求：
  - `RequestExpectsContinue(AParser)`
  - `RequestDeclaresBody(AParser)`
- 也就是说，实现上本来就打算只在“请求确实声明 body”时才发
  interim `100 Continue`。
- 但这条守卫之前没有 live-socket proof。

### 2. `Content-Length: 0 + Expect: 100-continue` 是最小且直接的 characterization case

- 这条 case 直接对准 `RequestDeclaresBody`：
  - 请求 method / route 仍走普通 handler 路径
  - `Content-Length: 0` 明确表明没有 body bytes 要继续等待
  - 如果 server 还误发 `100 Continue`，测试会立即失败

### 3. 现有生产行为直接 GREEN，说明 no-body guard 已经成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 两条 live proofs：
  - `Content-Length: 0 + Expect: 100-continue` -> 直接 final `200`
  - 响应里不出现 interim `100 Continue`
  - handler 会被正常调用，且读到空 body
- focused gate 直接 GREEN，说明当前生产代码已经满足这条契约，本轮不需要生产修复。

### 4. 现在 `Expect` request-side live contract 的“要不要发 100”边界更完整了

- 已有 direct live truth：
  - fixed-length body -> interim `100`
  - chunked body -> interim `100`
  - chunked after-interim overflow -> final `413`
  - declared oversize body -> early `413`, no interim `100`
  - unsupported `Expect` -> early `417`, no interim `100`
  - bodyless `Content-Length: 0` -> final `200`, no interim `100`
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `202/202 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮锁的是 `Content-Length: 0` 这一种 no-body characterization，还没系统铺开：
  - 无 `Content-Length` / 无 `Transfer-Encoding` 的 bodyless `Expect`
  - 更复杂的 `Expect` 组合 / OWS / repeated header-line characterization
- 下一刀如果继续做 `Expect`，应该仍保持“小而真”，不要一次扩成大矩阵。
