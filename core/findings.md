# Findings: http server trailer-complete chunked partial follow-up headers bridge

## Scope

- 本轮继续 keep-alive request-tail contract refinement，不扩散成更大的
  malformed 输入矩阵，只把 trailer-complete chunked partial follow-up headers 从
  half-close current truth 收成更具体的 server-layer bridge proof。

## Confirmed truths

### 1. trailer-complete chunked partial follow-up headers 先前只有 half-close current truth，还缺 bridge proof

- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  之前对 `IHttpServer` 只锁到：
  - 首个 trailer-complete chunked request 会先完成
  - 如果 peer half-close，半截 follow-up headers 会作为 malformed follow-up 返回 `400`
- 这对 safe-handling 足够，但还不能证明 server 不会过早把“仍可补全”的 follow-up
  headers 误判成 malformed。

### 2. 现有实现已经允许 trailer-complete chunked request 完成后保留未决 follow-up header bytes

- 与现有 `partial follow-up request-line can complete later` bridge proof 相邻的行为表明：
  - 当前请求 framing 一旦结束，尾部字节会被留给 follow-up parse
  - 问题不在“会不会保留 tail”，而在“header 已开始但未终止时，后续补字节是否还能继续”
- trailer-complete 这支还多一层约束：
  - 首请求的 `Trailer` declaration 必须继续保留
  - 实际 trailer field 仍不能泄漏成普通 header
- 这正是本轮要补的 trailer-complete request-tail 邻接空档。

### 3. 现有生产行为直接 GREEN，说明这条 bridge contract 已成立

- 在 [tests/nextpas.core.http/test_http_server/test_http_server.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_server/test_http_server.lpr)
  新增 threaded / epoll 两条 live bridge proofs：
  - 第一个 `POST /upload` 先返回 `200`
  - handler 只读到解码后的 body `hello`
  - `Trailer: X-Test` 仍保留，而实际 `X-Test` trailer field 仍不暴露为普通 header
  - 同连接里 follow-up partial headers 在补齐 `Connection: close\r\n\r\n` 后继续完成为第二个 `GET /next`
- focused gate 直接 GREEN，说明当前生产代码已经满足这条 bridge 契约，本轮不需要生产修复。

### 4. trailer-complete request-tail 现在不只剩 half-close safe-handling，而是多了一条更硬的 bridge truth

- 已有 direct live truth：
- `test_http_server`
  - trailer-complete partial follow-up request-line can complete later
  - trailer-complete partial follow-up headers can complete later
- `test_http_security`
  - 仍保留 peer half-close 后 follow-up malformed `400` 的 raw-wire safe-handling truth
- 因此这轮仍然是 coverage-expansion，不是生产修复。

## Verification evidence

- focused:
  - `make -C tests/nextpas.core.http/test_http_server test`
    - `218/218 passed`
    - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- 这轮只补了 trailer-complete chunked partial follow-up headers bridge。
- 邻接 still-open 收口方向仍包括：
  - `test_http_security` 中把 partial follow-up headers 从 safe-handling 提升到 raw-wire bridge proof
- 如果继续沿 raw-wire / server 契约同一条线推进，下一刀最自然就是先补 trailer-complete partial follow-up headers 的 security/raw-wire bridge，再评估是否把 fixed-length / plain chunked 也补成同型 raw-wire bridge。
- 下一刀仍应继续 keep-alive request-tail contract，而不是回去铺 `Expect` 矩阵或 benchmark。
