# Findings: HTTP terminal chunk ending-after-extension CR EOF proof

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

- `terminal 0 chunk ending EOF truncation` 已覆盖 `0\r\n` 后最终空 trailer section 缺失。
- `chunk-extension line EOF truncation` 已覆盖普通 non-terminal chunk 的 extension line 截断。
- `terminal chunk extension EOF truncation` 已覆盖 `0;sig=abc` 与 `0;sig=abc\r` 这两类 extension line 截断。
- `terminal chunk ending after extension EOF truncation` 已覆盖 `0;sig=abc\r\n` 这类最终空 trailer section 整段缺失。
- `chunk-size line EOF truncation`、`chunk-data CRLF EOF truncation`、
  `truncated trailer section at EOF` 都已有单独 focused proof。
- 但 terminal `0` chunk 如果自己携带 extension 且 extension line 已完整结束、只是最终空 trailer section
  只收到单个 `CR` 后 EOF，仍没有把 `...0;sig=abc\r\n\r` 这类输入单独锁住。

## New Evidence From This Batch

- parser focused tests 证明：
  - 当输入结束在 `...0;sig=abc\r\n\r` 时，`Finish` 后会进入 parser error；
  - 该输入保持 not-complete，不会被误判成合法完成。
- server focused tests 证明：
  - peer half-close 暴露出 terminal chunk ending after extension CR EOF 截断时，server 返回显式 `400`；
  - handler 不会被调用。
- security focused tests 证明：
  - raw-wire 下该子类稳定落到显式 `400`，没有静默关闭或 handler 落地。

## Batch Truth

- 这轮没有发现新的 HTTP 实现缺陷。
- 六条新增 focused tests 首轮即 GREEN，因此本轮仍然是
  **coverage expansion / current-truth locking**，不是生产修复。
- 现在 chunked EOF 截断的边界陈述又细了一层：
  - malformed chunk extension 已证明；
  - chunk-extension line EOF 截断已证明；
  - terminal chunk extension line EOF 截断也已单独证明；
  - terminal chunk ending after extension EOF 截断也已单独证明；
  - terminal chunk ending after extension CR EOF 截断也已单独证明；
  - chunk-size line 截断已证明；
  - chunk-data line ending 截断已证明；
  - terminal `0` chunk ending 截断已证明；
  - trailer field 已开始后的 trailer section 截断已证明。

## Remaining Questions

- malformed chunk framing 审计仍可继续细化其他 terminal/trailer grammar 子类，但这轮已经把
  terminal chunk 带 extension 后空 trailer section 的 CR-only EOF truth 锁实。
- keep-alive request-tail 契约决策仍然存在，不过不阻塞继续把 H1 grammar truth 做扎实。
