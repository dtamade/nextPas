# Task Plan: HTTP keep-alive Content-Length partial follow-up proof

## Goal

补齐 fixed-length keep-alive request-tail 的两个相邻 partial follow-up request
子类，把 declared body 正常结束后剩余半截下一请求的 current truth 单独锁实：

- `...helloGET /next HTTP/1.1`
- `...helloGET /next HTTP/1.1\r\nHost: localhost\r\n`

确认：

- parser 只消费首个合法 fixed-length request，不会被半截 follow-up line / headers 污染；
- server 首个请求仍然正常完成，随后在 peer half-close 后把半截 follow-up 稳定落成 follow-up `400`；
- security raw-wire 语义也稳定锁成“首个请求完成 + follow-up `400`”。

## Current Phase

`nextpas.core.http` H1 correctness coverage-expansion。当前从 malformed chunk framing
阶段转到 keep-alive request-tail 契约细化，把 fixed-length overrun truth 从“garbage tail”
再往前拆成更具体的 partial follow-up request line / headers 子类。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 复读 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md` 与现有控制文件。
- [x] 确认当前缺口是 keep-alive `Content-Length` declared body 后紧跟半截 follow-up request line / headers。
- [x] 新增 parser focused tests：
  `Content-Length keep-alive truncated follow-up request line consumes first request only`、
  `Content-Length keep-alive truncated follow-up headers consumes first request only`。
- [x] 新增 server focused tests：
  `Content-Length keep-alive truncated follow-up request line -> follow-up 400`、
  `Content-Length keep-alive truncated follow-up headers -> follow-up 400`。
- [x] 新增 security focused tests：
  `Content-Length keep-alive truncated follow-up request line safe handling`、
  `Content-Length keep-alive truncated follow-up headers safe handling`。
- [x] 跑 `test_http_h1parser`、`test_http_server`、`test_http_security` 首轮验证，记录是 RED 还是 direct GREEN。
- [x] 若失败则仅在 HTTP parser/server 内最小修复；若直接通过，则按 coverage-expansion 收口。
- [x] 同步 API coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 跑 HTTP 聚合验证、`git diff --check` 与 path-limited git hygiene。
- [x] path-limited commit，并输出中文收尾报告。

## Quality Gates

| Gate | Rule |
| --- | --- |
| Scope discipline | 只处理 `nextpas.core.http` 相关测试与控制文档，不触碰无关脏文件。 |
| TDD truthfulness | 新增 focused tests 必须先首跑，诚实记录 RED 或 direct GREEN。 |
| API gate | 如果 keep-alive request-tail 行为写进覆盖矩阵，必须有 parser/server/security 三层证据。 |
| Leak gate | changed-surface focused suites 与 HTTP aggregate 都必须给出 heaptrc `0 unfreed memory blocks`。 |
| Git safety | 只允许 path-limited staging/commit；禁止 `git add .`、reset、覆盖无关文件。 |

## Decisions

| Decision | Rationale |
| --- | --- |
| 本轮优先补 fixed-length keep-alive partial follow-up line / headers | 这是 `garbage tail` 与“完整合法 pipelined next request”之间最自然、最关键的契约中间态。 |
| parser 层除了首请求隔离，还额外对 leftover 单独 `Finish` 验证 | 这样可以把“首请求不污染”和“半截下一请求最终报错”同时锁实。 |
| 若首跑直接 GREEN，则不碰生产代码 | 当前目标是 correctness proof，不制造伪修复。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；六条新增 focused tests 首轮 direct GREEN，HTTP aggregate 复跑也通过 | 1 | 按 coverage expansion 收口，无需生产修复。 |
