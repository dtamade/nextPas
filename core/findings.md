# Findings: HTTP chunked trailer keep-alive tail proof

## Repo / Git Safety

- shared checkout 仍有大量无关 dirty / untracked 路径，不能做广泛 staging、reset 或回滚。
- 本轮只允许提交：
  - `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Existing HTTP Truth Before This Batch

- 无 trailer 的 keep-alive chunked tail truth 已完整覆盖：
  - garbage tail
  - partial follow-up request line
  - partial follow-up headers
- chunked trailer 本身也已有 focused truth：
  - trailer declaration 保留
  - trailer field 不污染普通请求头
  - 多类 malformed trailer / EOF truncation 都会被拒绝
- 但“完整 trailer section 结束后再出现 keep-alive tail”的交汇边界还没被单独锁实。

## New Evidence From This Batch

- parser focused tests 证明：
  - 当输入是 `Trailer-complete Req1 + garbage tail / partial follow-up line / partial follow-up headers` 时，
    parser 都只消费首个合法 chunked request；
  - 首个请求的 method / url / decoded body 不会被尾巴污染；
  - `Trailer: X-Test` 声明头仍保留，而实际 `X-Test: value` trailer field 仍不进入普通请求头；
  - leftover 单独 `Finish` 后仍会落成 parser error，不会误判成合法完成。
- server focused tests 证明：
  - 首个 chunked trailer request 会先正常进入 handler 并完成 `200`；
  - handler 看到的 body 仍是解码后的 `hello`，且 `Trailer` 声明头保留、实际 trailer field 不暴露为普通 header；
  - 完整 trailer section 之后的 garbage tail / partial follow-up line / headers 都会在同连接后续稳定返回 follow-up `400`。
- security focused tests 证明：
  - raw-wire 下这三类 `chunked + trailer + keep-alive tail` 输入都稳定落到
    “首个请求完成 + follow-up `400`” 语义，没有污染首个请求的已解码 body。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 九条新增 focused tests 首轮即 GREEN，因此本轮仍然是
  **coverage expansion / current-truth locking**，不是生产修复。
- chunked keep-alive request-tail truth 现在进一步覆盖到
  **trailer-complete** 路径：
  - 完整 trailer section 后的 garbage tail -> 首请求完成，follow-up `400`
  - 完整 trailer section 后的 partial follow-up request line -> 首请求完成，follow-up `400`
  - 完整 trailer section 后的 partial follow-up headers -> 首请求完成，follow-up `400`

## Remaining Questions

- keep-alive request-tail 契约决策仍在：
  当前 fixed-length、plain chunked、以及 trailer-complete chunked 三条路径的 current truth
  都已较完整，但是否把 follow-up `400` 冻结成公开契约，还是继续系统性收紧成更早拒绝，仍需判断。
- 如果继续做 correctness proof 而不是 policy tightening，下一步最自然的是：
  - `chunked + trailer + valid pipelined next request` 的 first-request isolation / second-request completion proof；
  - 或回到 `API_COVERAGE` 中仍挂着的 keep-alive policy decision。
