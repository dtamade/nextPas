# Task Plan: HTTP truncated trailer field EOF proof

## Goal

补齐 terminal `0` chunk 后 trailer field 行本体自己被 EOF 截断的两个相邻子类的
parser/server/security focused proof，把这两个 grammar 边界单独锁实：

- `...hello\r\n0\r\nX-Test: value`
- `...hello\r\n0\r\nX-Test: value\r`

确认：

- parser 在 `Finish` 后把两类输入都判成 error/not-complete；
- server 在 peer half-close 后都返回显式 `400` 且 handler 不落地；
- security raw-wire 语义也都稳定锁成显式 `400`。

## Current Phase

`nextpas.core.http` H1 correctness coverage-expansion。当前继续做 malformed chunk framing 审计，把
`chunk-size line`、`chunk-extension line`、`terminal chunk extension line`、`chunk-data line ending`、
`terminal 0 chunk ending`、`terminal chunk ending CR`、`terminal chunk ending after extension`、`terminal chunk ending after extension CR`、`trailer field line`、`trailer field CR`、`trailer section`、`trailer section CR` 这些 EOF 边界子类逐个拆开锁实，而不是停留在宽泛的
“truncated chunked EOF” 表述。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 复读 `docs/design-conventions.md`、`docs/nextpas.core.http.inbox.md`、
  `docs/http/API_COVERAGE.md` 与现有控制文件。
- [x] 确认当前缺口是 trailer field 行本体自己缺失结尾 `CRLF` 的两个 EOF 子类，
  且现有 case 还没单独覆盖 `...0\r\nX-Test: value` 与 `...0\r\nX-Test: value\r`。
- [x] 新增 parser focused test：
  `Chunked request truncated trailer field line at EOF`。
- [x] 新增 server focused test：
  `Malformed chunked request truncated trailer field line at EOF -> 400`。
- [x] 新增 security focused test：
  `Truncated trailer field line at EOF -> 400`。
- [x] 新增 parser/server/security 对应的 `...X-Test: value\r` 相邻 CR-only 子类 focused tests。
- [x] 跑 `test_http_h1parser`、`test_http_server`、`test_http_security` 首轮验证，记录是 RED 还是 direct GREEN。
- [x] 若失败则仅在 HTTP parser/server 内最小修复；若直接通过，则按 coverage-expansion 收口。
- [x] 同步 inbox、API coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 跑 HTTP 聚合验证、`git diff --check` 与 path-limited git hygiene。
- [x] path-limited commit，并输出中文收尾报告。

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
| 本轮优先补 trailer field 行本体的 EOF 截断子类 | 这是紧邻既有 `...X-Test: value\r\n` / `...X-Test: value\r\n\r` 两类 proof 的自然相邻边界。 |
| 分开锁 `...0\r\nX-Test: value` 与 `...0\r\nX-Test: value\r` | 它们分别代表 field line 完整缺失 `CRLF` 与只收到半个行尾 `CR` 的不同 grammar 边界。 |
| 若首跑直接 GREEN，则不碰生产代码 | 当前目标是 correctness proof，不制造伪修复。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；六条新增 focused tests 首轮 direct GREEN，HTTP aggregate 复跑也通过 | 1 | 按 coverage expansion 收口，无需生产修复。 |
