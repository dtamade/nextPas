# Findings: http server fixed-length partial follow-up headers bridge

## Scope

- 本轮继续 keep-alive request-tail contract refinement，不扩散成更大的
  malformed 输入矩阵，只把 fixed-length partial follow-up headers 从
  half-close current truth 收成更具体的 server-layer bridge proof。

## Confirmed truths

### 1. fixed-length partial follow-up headers 先前只有 half-close current truth，还缺 bridge proof

- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  之前对 `IHttpServer` 只锁到：
  - 首个 fixed-length request 会先完成
  - 如果 peer half-close，半截 follow-up headers 会作为 malformed follow-up 返回 `400`
- 这对 safe-handling 足够，但还不能证明 server 不会过早把“仍可补全”的 follow-up
  headers 误判成 malformed。

### 2. 现有实现已经允许 fixed-length request 完成后保留未决 follow-up header bytes

- 与现有 `partial follow-up request-line can complete later` bridge proof 相邻的行为表明：
  - 当前请求 framing 一旦结束，尾部字节会被留给 follow-up parse
  - 问题不在“会不会保留 tail”，而在“header 已开始但未终止时，后续补字节是否还能继续”
- 这正是本轮要补的固定长度 request-tail 邻接空档。

### 3. 现有生产行为直接 GREEN，说明这条 bridge contract 已成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 两条 live bridge proofs：
  - 第一个 `POST /upload` 先返回 `200`
  - handler 只读到声明的 body `hello`
  - 同连接里 follow-up partial headers 在补齐 `Connection: close\r\n\r\n` 后继续完成为第二个 `GET /next`
- focused gate 直接 GREEN，说明当前生产代码已经满足这条 bridge 契约，本轮不需要生产修复。

### 4. fixed-length request-tail 现在不只剩 half-close safe-handling，而是多了一条更硬的 bridge truth

- 已有 direct live truth：
- `test_http_server`
  - fixed-length partial follow-up request-line can complete later
  - fixed-length partial follow-up headers can complete later
- `test_http_security`
  - 仍保留 peer half-close 后 follow-up malformed `400` 的 raw-wire safe-handling truth
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `214/214 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮只补了 fixed-length partial follow-up headers bridge。
- 邻接 still-open 收口方向仍包括：
  - plain chunked partial follow-up headers bridge
  - trailer-complete chunked partial follow-up headers bridge
- 下一刀仍应继续 keep-alive request-tail contract，而不是回去铺 `Expect` 矩阵或 benchmark。
