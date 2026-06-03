# Findings: HTTP truncated terminal chunk ending proof

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

- `chunk-size line EOF truncation` 已有 focused proof。
- `truncated trailer section at EOF` 也已有 focused proof，但它覆盖的是 trailer field 已经开始后的截断。
- terminal `0` chunk 后空 trailer section 的最终空行缺失，仍然没有单独的 focused proof。

## New Evidence From This Batch

- parser focused test 证明：
  - 当 terminal `0` chunk 已到达，但结尾空 trailer section 的最终 CRLF 缺失时，`Finish` 后会进入 parser error；
  - 输入保持 not-complete，不会被误判成合法完成。
- server focused test 证明：
  - peer half-close 暴露出 truncated terminal chunk ending 时，server 返回显式 `400`；
  - handler 不会被调用。
- security focused test 证明：
  - raw-wire 下该输入也稳定落到显式 `400`，没有静默关闭或 handler 落地。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 三条新增 focused tests 首轮即 GREEN，因此本轮的真实性质仍然是
  **coverage expansion / current-truth locking**，不是生产修复。
- 现在 terminal chunk / trailer boundary 的陈述可以更细：
  - chunk-size line 截断已证明；
  - terminal `0` chunk ending 截断也已单独证明；
  - trailer field 已开始后的 trailer section 截断也已单独证明。

## Remaining Questions

- malformed chunk framing 审计还可以继续细化 terminal/trailer grammar 的其他子类，但这轮已经把最直接的
  boundary gap 补上。
- keep-alive request-tail 契约决策仍然存在，不过不阻塞当前继续把 H1 grammar truth 做扎实。
