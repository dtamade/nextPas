# Findings: HTTP truncated chunk-size line proof

## Repo / Git Safety

- shared checkout 仍有大量无关 dirty / untracked 路径，不能做广泛 staging、reset 或回滚。
- 本轮只允许提交：
  - `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/nextpas.core.http.inbox.md`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Existing HTTP Truth Before This Batch

- `chunked request truncated at EOF` 已有 focused proof，但实例只覆盖 chunk-data 被截断。
- malformed chunk framing 审计还缺 `chunk-size line` 自身在 EOF/half-close 截断时的独立 proof。
- 这个缺口如果不补，会让“chunked truncation”覆盖看起来更完整，但其实 grammar truth 还不够细。

## New Evidence From This Batch

- parser focused test 证明：
  - 请求在 chunk-size line 尚未完成时 EOF，`Finish` 后会进入 parser error；
  - 输入保持 not-complete，不会伪装成合法完成。
- server focused test 证明：
  - peer half-close 暴露出 truncated chunk-size line 时，server 返回显式 `400`；
  - handler 不会被调用。
- security focused test 证明：
  - raw-wire 下该输入也稳定落到显式 `400`，没有回退成静默关闭或 handler 落地。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 三条新增 focused tests 首轮即 GREEN，因此本轮的真实性质仍然是
  **coverage expansion / current-truth locking**，不是生产修复。
- 现在对 chunked truncation 的陈述可以更精确：
  - chunk-data 截断已证明；
  - chunk-size line 截断也已单独证明；
  - trailer section 截断也已单独证明。

## Remaining Questions

- malformed chunk framing 审计还可以继续细化，例如最后一个 `0` chunk 自身的 line truncation、或更多
  trailer grammar 子类，但本轮已经把一个真实缺口补上。
- keep-alive request-tail 契约决策仍然存在，不过不阻塞当前继续把 H1 grammar truth 做扎实。
