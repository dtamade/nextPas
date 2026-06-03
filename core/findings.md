# Findings: HTTP fixed-length keep-alive tail proof

## Repo / Git Safety

- shared checkout 当前依然有大量无关 dirty / untracked 路径，不能做广泛 staging、reset 或回滚。
- 本轮只允许提交：
  - `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/nextpas.core.http.inbox.md`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Existing HTTP Truth Before This Batch

- fixed-length 首请求的 same-read / same-write pipelining isolation 已经有 focused proof。
- server 层已有 `Content-Length keep-alive garbage tail -> follow-up 400` focused current-truth 证据。
- chunked 侧已经更完整：parser/server/security 都有 keep-alive garbage-tail proof。

## Gap Confirmed

- `Content-Length keep-alive garbage tail` 还缺 parser focused proof：
  - parser 是否只消费首个完整 fixed-length request，而不把尾巴污染进 body / method / url。
- 同时也缺 security raw-wire proof：
  - 首个请求是否仍先正常完成；
  - 尾巴是否稳定作为 follow-up malformed request 返回 `400`。

## New Evidence From This Batch

- parser focused test 证明：
  - fixed-length keep-alive tail 输入下，parser 只消费首个合法 request；
  - 首个 request 的 method / url / body 保持正确，尾巴不会污染当前请求。
- security focused test 证明：
  - raw-wire 下首个 fixed-length request 会先返回 `200`；
  - handler 仍按 `Content-Length: 5` 看到 `echo:5`；
  - 同连接上的多余尾巴会稳定触发 follow-up `400`。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 两条新增 focused tests 首轮即 GREEN，因此本轮的真实性质是
  **coverage expansion / current-truth locking**，不是生产修复。
- 到当前为止，keep-alive request-tail 讨论所需的证据已经更完整：
  - fixed-length tail：parser/server/security 都有 focused proof；
  - chunked tail：parser/server/security 都有 focused proof；
  - fixed-length/chunked 首请求的 same-read / same-write pipelining isolation 也都已有 proof。

## Remaining Questions

- 下一步可以更明确地做契约决策：
  - 保留“首请求完成，尾巴 follow-up `400`”为 keep-alive transport truth；
  - 或进一步设计更早拒绝的 public policy。
- raw-wire malformed chunk framing 审计仍未结束，本轮只是把 fixed-length tail 这条对称证据补齐。
