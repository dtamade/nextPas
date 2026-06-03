# Findings: HTTP keep-alive chunked partial follow-up proof

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

- `chunked + Connection: close + extra bytes after terminal chunk` 已经在 parser/server/security
  三层锁成显式 `400`。
- keep-alive chunked garbage tail 也已有 current-truth proof：
  首个合法请求先完成，尾巴随后作为 follow-up malformed request 返回 `400`。
- 合法 chunked pipelined next request 也已覆盖：chunked 首请求不会被同包第二请求污染。
- 但 `garbage tail` 与“完整合法下一请求”之间还缺两类相邻 truth：
  - decoded body 后只到下一请求行中途 EOF
  - decoded body 后到下一请求头中途 EOF

## New Evidence From This Batch

- parser focused tests 证明：
  - 当输入是 `Req1 + partial follow-up request line` 或 `Req1 + partial follow-up headers` 时，
    parser 都只消费首个合法 chunked request；
  - leftover 单独 `Finish` 后都会进入 parser error，不会被误判成合法完成。
- server focused tests 证明：
  - 首个 chunked request 会先正常进入 handler 并完成 `200`；
  - peer half-close 暴露出 partial follow-up request line / headers 时，
    server 会在后续稳定返回 follow-up `400`。
- security focused tests 证明：
  - raw-wire 下这两类 keep-alive chunked partial follow-up 子类都稳定落到
    “首个请求完成 + follow-up `400`” 语义，没有污染首个请求体。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 六条新增 focused tests 首轮即 GREEN，因此本轮仍然是
  **coverage expansion / current-truth locking**，不是生产修复。
- chunked keep-alive request-tail 的 current truth 现在也细到与 fixed-length 对称：
  - `Connection: close` extra bytes -> 显式 `400`；
  - keep-alive garbage tail -> 首请求完成，follow-up `400`；
  - keep-alive partial follow-up request line -> 首请求完成，follow-up `400`；
  - keep-alive partial follow-up headers -> 首请求完成，follow-up `400`；
  - keep-alive valid pipelined next request -> 两个请求都能各自独立完成。

## Remaining Questions

- keep-alive request-tail 契约决策仍然存在：
  当前 fixed-length 与 chunked 两条路径的 current truth 都已较完整，但是否把 follow-up `400`
  冻结成公开契约，还是继续系统性收紧成更早拒绝，仍需判断。
- keep-alive tail 这条线下一步最自然不是再补相邻 grammar，而是开始做
  transport truth 与最终 public policy 的决策收口。
