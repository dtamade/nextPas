# Task Plan: HTTP truncated chunk-data CRLF EOF proof

## Goal

补齐 chunked request 在 chunk-data 结束后、行尾 CRLF 自身被 EOF 截断时的 parser/server/security focused proof，
把这两个相邻子类单独锁实：

- `... 5\r\nhello`
- `... 5\r\nhello\r`

确认：

- parser 在 `Finish` 后把两类输入都判成 error/not-complete；
- server 在 peer half-close 后返回显式 `400` 且 handler 不落地；
- security raw-wire 语义也稳定锁成显式 `400`。

## Current Phase

`nextpas.core.http` H1 correctness coverage-expansion。当前继续做 malformed chunk framing 审计，把
`chunk-size line`、`chunk-data line ending`、`terminal 0 chunk ending`、`trailer section` 这些 EOF
边界子类逐个拆开锁实，而不是停留在宽泛的 “truncated chunked EOF” 表述。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 复读 `docs/design-conventions.md`、`docs/nextpas.core.http.inbox.md`、
  `docs/http/API_COVERAGE.md` 与现有控制文件。
- [x] 确认当前缺口是 chunk-data 后 CRLF 的 EOF 截断，且现有 case 还没单独覆盖
  `...hello` / `...hello\r`。
- [x] 新增 parser focused tests：
  `Chunked request truncated chunk-data ending at EOF`、
  `Chunked request truncated chunk-data CR at EOF`。
- [x] 新增 server focused tests：
  `Malformed chunked request truncated chunk-data ending at EOF -> 400`、
  `Malformed chunked request truncated chunk-data CR at EOF -> 400`。
- [x] 新增 security focused tests：
  `Truncated chunk-data ending at EOF -> 400`、
  `Truncated chunk-data CR at EOF -> 400`。
- [x] 跑 `test_http_h1parser`、`test_http_server`、`test_http_security` 首轮验证，记录是 RED 还是 direct GREEN。
- [x] 若失败则仅在 HTTP parser/server 内最小修复；若直接通过，则按 coverage-expansion 收口。
- [x] 同步 inbox、API coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 跑 HTTP 聚合验证、`git diff --check` 与 path-limited git hygiene。
- [ ] path-limited commit，并输出中文收尾报告。

## Quality Gates

| Gate | Rule |
| --- | --- |
| Scope discipline | 只处理 `nextpas.core.http` 相关测试与控制文档，不触碰无关脏文件。 |
| TDD truthfulness | 新增 focused tests 必须先首跑，诚实记录 RED 或 direct GREEN。 |
| API gate | 如果 malformed chunk framing 行为写进覆盖矩阵，必须有 parser/server/security 三层证据。 |
| Leak gate | changed-surface focused suites 与 HTTP aggregate 都必须给出 heaptrc `0 unfreed memory blocks`。 |
| Git safety | 只允许 path-limited staging/commit；禁止 `git add .`、reset、覆盖无关文件。 |

## Decisions

| Decision | Rationale |
| --- | --- |
| 本轮优先补 chunk-data line ending EOF 子类 | 这是当前 malformed chunk framing 里最自然的剩余边界缺口。 |
| 一次性锁 `...hello` 与 `...hello\r` 两个相邻子类 | 可以把 chunk-data CRLF 截断 truth 说清楚，而不必下一轮再补半个 CRLF。 |
| 若首跑直接 GREEN，则不碰生产代码 | 当前目标是 correctness proof，不制造伪修复。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；focused 首轮 direct GREEN，HTTP aggregate 也已通过 | 1 | 按 coverage expansion 收口，无需生产修复。 |
