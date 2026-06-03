# Findings: HTTP chunked trailer pipelined next-request proof

## Repo / Git Safety

- shared checkout 仍有大量无关 dirty / untracked 路径，不能做广泛 staging、reset 或回滚。
- 本轮只允许提交：
  - `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Existing HTTP Truth Before This Batch

- trailer-complete chunked keep-alive tail 的三类 malformed current truth 已锁实：
  - garbage tail -> 首请求完成，follow-up `400`
  - partial follow-up request line -> 首请求完成，follow-up `400`
  - partial follow-up headers -> 首请求完成，follow-up `400`
- 无 trailer 的合法 pipelined next request 也已有 focused proof：
  - parser 只消费首个 chunked request
  - server 在同连接上正确完成两个请求
- 但 “trailer-complete chunked 首请求 + 合法 pipelined next request” 这一正向对称 proof 还没单独锁实。

## New Evidence From This Batch

- parser focused test 证明：
  - 当输入是 `Trailer-complete Req1 + valid Req2` 时，parser 只消费首个合法 chunked request；
  - 首个请求的 method / url / decoded body 不会被下一请求污染；
  - `Trailer: X-Test` 声明头仍保留，而实际 `X-Test: value` trailer field 仍不进入普通请求头。
- server focused test 证明：
  - 同一 write 中，首个 trailer-complete chunked request 会先正常进入 handler 并完成 `200`；
  - 第二个 pipelined request 也会在同连接上继续完成 `200`；
  - 首请求 handler 看到的 body 仍是解码后的 `hello`，且 trailer declaration 保留、trailer field 不暴露为普通 header。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 两条新增 focused tests 首轮即 GREEN，因此本轮仍然是
  **coverage expansion / current-truth locking**，不是生产修复。
- `chunked + trailer` 这条线现在同时具备：
  - trailer-complete malformed tail -> 首请求完成，follow-up `400`
  - trailer-complete valid pipelined next request -> 两个请求独立完成

## Remaining Questions

- keep-alive request-tail / pipeline policy decision 仍在：
  当前 fixed-length、plain chunked、以及 trailer-complete chunked 的 transport truth 已越来越完整，但是否把这些行为冻结成公开契约，还是继续系统性收紧成更早拒绝，仍需判断。
- 如果继续做 correctness proof 而不是 policy tightening，下一步更自然的是回到
  `API_COVERAGE` 里的 keep-alive policy decision，而不是再补更多相邻小变体。
