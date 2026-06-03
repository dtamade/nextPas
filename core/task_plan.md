# Task Plan: HTTP chunked trailer keep-alive tail proof

## Goal

补齐 `chunked + trailer + keep-alive tail` 的三个相邻 current-truth 子类：

- `...0\r\nX-Test: value\r\n\r\ngarbage`
- `...0\r\nX-Test: value\r\n\r\nGET /next HTTP/1.1`
- `...0\r\nX-Test: value\r\n\r\nGET /next HTTP/1.1\r\nHost: localhost\r\n`

确认：

- parser 在完整 trailer section 结束后只消费首个合法 chunked request，不会被后续垃圾尾巴或半截 follow-up request 污染；
- trailer 声明头仍保留，实际 trailer field 仍不进入普通请求头；
- server 首个请求仍然正常完成，随后在同连接上把尾巴稳定落成 follow-up `400`；
- security raw-wire 语义也稳定锁成“首个请求完成 + follow-up `400`”。

## Current Phase

`nextpas.core.http` H1 correctness coverage-expansion。当前继续沿 malformed
chunked request / trailer contract boundary 做 coverage 收口，重点补完整 trailer
section 之后的 keep-alive tail isolation truth。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 复读 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md` 与现有控制文件。
- [x] 审阅现有 parser/server/security 布局，确认 gap 是“完整 trailer section 结束后的 keep-alive tail isolation”。
- [x] 新增 parser focused tests：
  `Chunked trailer keep-alive garbage tail consumes first request only`、
  `Chunked trailer keep-alive truncated follow-up request line consumes first request only`、
  `Chunked trailer keep-alive truncated follow-up headers consumes first request only`。
- [x] 新增 server focused tests：
  `Chunked trailer keep-alive garbage tail -> follow-up 400`、
  `Chunked trailer keep-alive truncated follow-up request line -> follow-up 400`、
  `Chunked trailer keep-alive truncated follow-up headers -> follow-up 400`。
- [x] 新增 security focused tests：
  `Chunked trailer keep-alive garbage tail safe handling`、
  `Chunked trailer keep-alive truncated follow-up request line safe handling`、
  `Chunked trailer keep-alive truncated follow-up headers safe handling`。
- [x] 跑 `test_http_h1parser`、`test_http_server`、`test_http_security` 首轮验证，记录是 RED 还是 direct GREEN。
- [x] 根据首轮结果判断是否需要生产修复。
- [x] 同步 API coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 跑 HTTP 聚合验证、`git diff --check` 与 path-limited git hygiene。
- [ ] path-limited commit，并输出中文收尾报告。

## Quality Gates

| Gate | Rule |
| --- | --- |
| Scope discipline | 只处理 `nextpas.core.http` 相关测试与控制文档，不触碰无关脏文件。 |
| TDD truthfulness | 新增 focused tests 已首跑；必须诚实记录 RED 或 direct GREEN。 |
| API gate | 如果 trailer-complete keep-alive tail 行为写进覆盖矩阵，必须有 parser/server/security 三层证据。 |
| Leak gate | changed-surface focused suites 与 HTTP aggregate 都必须给出 heaptrc `0 unfreed memory blocks`。 |
| Git safety | 只允许 path-limited staging/commit；禁止 `git add .`、reset、覆盖无关文件。 |

## Decisions

| Decision | Rationale |
| --- | --- |
| 本轮选 `chunked + trailer + keep-alive tail` | 这是“chunked keep-alive tail isolation”与“trailer isolation”两条线的交汇边界，现有矩阵尚未单独锁实。 |
| parser 额外断言 trailer 声明头保留且 trailer field 不进普通请求头 | 这样可以确认 keep-alive tail proof 没有绕开既有 trailer isolation 契约。 |
| 首轮 direct GREEN 就不碰生产代码 | 当前目标仍是 correctness proof，不制造伪修复。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；九条新增 focused tests 首轮 direct GREEN | 1 | 保持 coverage expansion 路线，不改生产代码。 |
