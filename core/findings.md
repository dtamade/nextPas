# Findings: http server no-length expect-continue guard proof

## Scope

- 本轮继续 request-side protocol completeness，不扩散成更大的 `Expect`
  矩阵，只把 `Expect: 100-continue` 在“完全不声明 body”的请求上的守卫
  语义直接锁下来。

## Confirmed truths

### 1. `Expect` 的 no-body guard 还差一个最自然的相邻分支

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  里的 `ShouldSendContinueResponse` 已经要求：
  - `RequestExpectsContinue(AParser)`
  - `RequestDeclaresBody(AParser)`
- 也就是说，实现上本来就打算只在“请求确实声明 body”时才发
  interim `100 Continue`。
- 上一刀已经锁了：
  - `Content-Length: 0 + Expect: 100-continue`
- 但 `RequestDeclaresBody = False` 的另一个最自然分支，
  “完全没有 `Content-Length` / `Transfer-Encoding`”，还没有 direct live proof。

### 2. no-length bodyless `Expect` 是比 zero-length 更贴近 parser 真值的相邻 case

- 这条 case 同样直接对准 `RequestDeclaresBody`：
  - 没有 `Transfer-Encoding`
  - 也没有正数 `Content-Length`
  - 因而不应等待 body，更不应误发 `100 Continue`
- 这轮顺手把 bodyless `Expect` live helper 泛化，避免 duplicated test body。

### 3. 现有生产行为直接 GREEN，说明 no-body guard 在 no-length 分支也成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 两条 live proofs：
  - `POST /echo` + `Expect: 100-continue`，但无 `Content-Length` / `Transfer-Encoding`
    -> 直接 final `200`
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
  - bodyless no-length request -> final `200`, no interim `100`
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `204/204 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮把最自然的两个 no-body 分支都锁了，但还没系统铺开：
  - 其他 method 上的 bodyless `Expect` characterization
  - 更复杂的 `Expect` 组合 / OWS / repeated header-line characterization
- 下一刀如果继续做 `Expect`，应该仍保持“小而真”，不要一次扩成大矩阵。
