# Findings: HTTP completed trailer-line final blank-line EOF proof

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

- terminal / trailer EOF proof 已经覆盖：
  - `terminal 0 chunk ending EOF truncation`
  - `terminal chunk ending CR EOF truncation`
  - `terminal chunk ending after extension EOF truncation`
  - `terminal chunk ending after extension CR EOF truncation`
  - trailer field-name / separator / empty-value CR / empty-value EOF
  - trailer whitespace / whitespace CR
  - trailer field line / field CR / section CR
- 也就是说，trailer line 尚未完成的各类边界已经基本锁实。
- 但仍缺少一组相邻 truth：
  trailer field 本身已经完整结束，随后 final blank-line 又在下一步 EOF：
  - `...0\r\nX-Test:\r\n\r`
  - `...0\r\nX-Test: \r\n`
  - `...0\r\nX-Test: \r\n\r`

## New Evidence From This Batch

- parser focused tests 证明：
  - 当输入结束在 `...0\r\nX-Test:\r\n\r`、`...0\r\nX-Test: \r\n`、`...0\r\nX-Test: \r\n\r` 时，
    `Finish` 后都会进入 parser error；
  - 三类输入都保持 not-complete，不会被误判成合法完成。
- server focused tests 证明：
  - peer half-close 暴露出 completed trailer line 后 final blank-line 未完整结束时，
    server 都返回显式 `400`；
  - 三类输入下 handler 都不会被调用。
- security focused tests 证明：
  - raw-wire 下这三个 completed-line grammar 子类都稳定落到显式 `400`，
    没有静默关闭或 handler 落地。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 九条新增 focused tests 首轮即 GREEN，因此本轮仍然是
  **coverage expansion / current-truth locking**，不是生产修复。
- 现在 chunked EOF 截断的边界陈述又细了一层：
  - malformed chunk extension 已证明；
  - chunk-extension line EOF 截断已证明；
  - terminal chunk ending CR EOF 截断也已单独证明；
  - terminal chunk extension line EOF 截断也已单独证明；
  - terminal chunk ending after extension EOF 截断也已单独证明；
  - terminal chunk ending after extension CR EOF 截断也已单独证明；
  - truncated trailer field-name EOF 截断也已单独证明；
  - truncated trailer separator EOF 截断也已单独证明；
  - truncated trailer empty-value CR EOF 截断也已单独证明；
  - truncated trailer empty-value EOF 截断也已单独证明；
  - truncated trailer empty-value section CR EOF 截断也已单独证明；
  - truncated trailer whitespace EOF 截断也已单独证明；
  - truncated trailer whitespace CR EOF 截断也已单独证明；
  - truncated trailer whitespace section EOF 截断也已单独证明；
  - truncated trailer whitespace section CR EOF 截断也已单独证明；
  - truncated trailer field line EOF 截断也已单独证明；
  - truncated trailer field CR EOF 截断也已单独证明；
  - truncated trailer section CR EOF 截断也已单独证明；
  - chunk-size line 截断已证明；
  - chunk-data line ending 截断已证明；
  - terminal `0` chunk ending 截断已证明；
  - trailer field 已开始后的 trailer section 截断已证明。

## Remaining Questions

- malformed chunk framing 审计仍可继续细化其他 terminal/trailer grammar 子类，但这轮已经把
  completed empty-value / OWS-only trailer line 之后 final blank-line 的剩余相邻 truth 锁实。
- keep-alive request-tail 契约决策仍然存在，不过不阻塞继续把 H1 grammar truth 做扎实。
