# Findings: http server expect plus transfer-coding rejection ordering

## Scope

- 本轮继续 request-side protocol completeness，不扩散成更大的 `Expect`
  矩阵，只把 `Expect: 100-continue` 与异常 transfer-coding 的优先级次序
  直接锁下来。

## Confirmed truths

### 1. `Expect` 与 transfer-coding error 的先后次序先前只靠实现顺序推断

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  里，whole-run 与 poll-driven 两条路径当前都是先判：
  - parser error / parser error status
  - unsupported expectations
  - declared oversize content-length
  - 然后才看 `ShouldSendContinueResponse`
- 也就是说，代码本来就打算在 transfer-coding 已经落成 `501/400`
  的情况下，直接拒绝而不是先发 interim `100 Continue`。
- 但这条顺序先前没有 direct live proof。

### 2. `Expect + unsupported/malformed transfer-coding` 是更值钱的 live characterization

- 这轮只锁两个最小但高价值分支：
  - `Transfer-Encoding: gzip, chunked` -> unsupported request transfer-coding -> `501`
  - `Transfer-Encoding: chunked, gzip` -> `chunked` not final -> malformed -> `400`
- 两条都带 `Expect: 100-continue`，直接验证：
  - server 会不会先误发 interim `100`
  - 还是先按 transfer-coding error 直接拒绝

### 3. 现有生产行为直接 GREEN，说明 error-first ordering 已成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 四条 live proofs：
  - `Expect + Transfer-Encoding: gzip, chunked` -> 直接 final `501 Not Implemented`
  - `Expect + Transfer-Encoding: chunked, gzip` -> 直接 final `400 Bad Request`
  - 两条响应里都不出现 interim `100 Continue`
  - handler 都不会被调用
- focused gate 直接 GREEN，说明当前生产代码已经满足这条契约，本轮不需要生产修复。

### 4. 现在 `Expect` request-side live contract 的“什么时候绝不能先发 100”边界更完整了

- 已有 direct live truth：
  - fixed-length body -> interim `100`
  - chunked body -> interim `100`
  - chunked after-interim overflow -> final `413`
  - declared oversize body -> early `413`, no interim `100`
  - unsupported `Expect` -> early `417`, no interim `100`
  - bodyless `Content-Length: 0` -> final `200`, no interim `100`
  - bodyless no-length request -> final `200`, no interim `100`
  - `Expect + Transfer-Encoding: gzip, chunked` -> final `501`, no interim `100`
  - `Expect + Transfer-Encoding: chunked, gzip` -> final `400`, no interim `100`
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `210/210 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮把 transfer-coding error ordering 接进来了，但还没系统铺开：
  - `Expect` 与其他 parser-stage rejection 的相对优先级 characterization
  - 更复杂的 `Expect` 组合 / OWS / repeated header-line characterization
- 下一刀如果继续做 `Expect`，应该仍保持“小而真”，不要一次扩成大矩阵。
