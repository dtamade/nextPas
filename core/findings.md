# Findings: HTTP chunked pipelined request isolation proof

## Repo / Git Safety

- shared checkout 当前存在大量无关 dirty / untracked 路径，不能做任何广泛 staging 或回滚。
- 本轮只允许提交：
  - `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/nextpas.core.http.inbox.md`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Existing HTTP Truth Before This Batch

- `Content-Length` 首请求的 same-read / same-write pipelining isolation proof 已经存在。
- keep-alive `Content-Length` garbage tail 与 keep-alive chunked garbage tail 的 server/security
  current-truth proof 已经存在：首个合法 request 先完成，尾巴随后作为 follow-up malformed request
  返回 `400`。
- 当前最有价值的缺口不是再堆 malformed close-only case，而是补齐
  `chunked first request + next request in same buffer/write` 的正向隔离证明。

## New Evidence From This Batch

- parser focused test 证明：
  - `chunked` 首请求后即使同一缓冲区里紧跟第二个 request，parser 也只消费首个完整 request；
  - method / url / decoded body 保持为首个 request 的真实值，不会被第二个 request 污染。
- server focused test 证明：
  - 同一连接同一 write 中发送 `chunked POST` 后再跟 `GET`，两个 handler 都会依次完成；
  - 首个 response body 保持 `upload:hello`，第二个 response body 保持 `next`；
  - 这说明 H1 transport 的 read-ahead tail 在 chunked 首请求场景下也能正确保留与续派发。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 两条新增 focused tests 首轮即 GREEN，因此本轮的真实性质是
  **coverage expansion / current-truth locking**，不是生产修复。
- 现阶段可以更明确地说：
  - `same-read pipelined request isolation` 已覆盖 fixed-length 与 chunked 首请求；
  - `same-write pipelined request isolation` 也已覆盖 fixed-length 与 chunked 首请求。

## Remaining Questions

- 现在已经有 enough proof 支撑 keep-alive request-tail 行为讨论；下一步应决定哪些 tail / overrun
  case 继续保持“首请求完成，尾巴 follow-up `400`”的 transport truth，哪些要进一步收紧成更早拒绝。
- raw-wire malformed chunk framing 仍可继续系统性扫尾，但本轮不再需要为了 chunked pipelining 去改生产代码。
