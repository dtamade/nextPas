# Findings: http server request-target over MaxHeaderSize contract

## Scope

- 本轮继续 request-side protocol completeness，不扩散成更大的 malformed
  输入矩阵，只把 long-request-line 的 broad safe-handling 收成更具体的
  server-layer `MaxHeaderSize` 契约。

## Confirmed truths

### 1. long-request-line 先前只有 security current truth，还缺 server-layer focused contract

- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  之前只把 long-request-line 记成 security current truth：
  - 可能落到 `431/414/400/...`
  - 关键只是 runtime stays safe
- 这对 security 足够，但对 `IHttpServer.MaxHeaderSize` 公开契约来说太宽了。

### 2. 现有实现其实已经把 request-line bytes 算进 `MaxHeaderSize` 预算

- [src/nextpas.core.http.impl.h1.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.impl.h1.pas)
  在 whole-run / poll-driven 两条路径上，headers complete 后都会先检查：
  - `total_read - body_size > MaxHeaderSize`
- 这意味着 request-line 与 header fields 共用同一条 header budget。
- 因而完全可以在 server 层直接锁一个更具体的契约：
  - request-target 把 request-line 顶过 budget 时 -> `431`

### 3. 现有生产行为直接 GREEN，说明这条 `431` contract 已成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 两条 live proofs：
  - 小 `MaxHeaderSize` 下，oversized request-target -> 直接 `HTTP/1.1 431`
  - handler 不会被调用
- focused gate 直接 GREEN，说明当前生产代码已经满足这条契约，本轮不需要生产修复。

### 4. long-request-line 现在不只剩 broad safe-handling，而是多了一条可依赖的 server-layer budget truth

- 已有 direct live truth：
- `test_http_security`
  - 仍保留 broad safe-handling truth：long request-line 不会让 runtime 崩溃或误入 handler
- `test_http_server`
  - 现在进一步锁住主分支：在受控小 `MaxHeaderSize` 下，oversized request-target
    会直接返回显式 `431`
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `212/212 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮把 long-request-line 的 server 主分支锁住了，但还没系统铺开：
  - `414 URI Too Long` 是否值得未来单独做成独立 contract
  - 其他 current-truth keep-alive tail policy 是否要继续从 characterization 提升到更硬契约
- 下一刀更适合继续挑 runtime / malformed 邻接 current truth 收口，而不是回去铺 `Expect` 矩阵。
