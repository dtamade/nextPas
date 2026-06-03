# Task Plan: HTTP completed trailer-line final blank-line EOF proof

## Goal

补齐 terminal `0` chunk 后，trailer field 已经完整结束但最终空 trailer section
仍未完整结束的三个相邻 grammar 子类，把这些 final blank-line EOF 边界单独锁实：

- `...hello\r\n0\r\nX-Test:\r\n\r`
- `...hello\r\n0\r\nX-Test: \r\n`
- `...hello\r\n0\r\nX-Test: \r\n\r`

确认：

- parser 在 `Finish` 后把三类输入都判成 error/not-complete；
- server 在 peer half-close 后都返回显式 `400` 且 handler 不落地；
- security raw-wire 语义也都稳定锁成显式 `400`。

## Current Phase

`nextpas.core.http` H1 correctness coverage-expansion。当前继续做 malformed chunk framing
审计，把 terminal/trailer grammar 的 EOF 子类逐个拆开锁实，而不是停留在宽泛的
“truncated chunked EOF” 表述。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 复读 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md` 与现有控制文件。
- [x] 确认当前缺口是 completed trailer line 之后 final blank-line 未完整结束的三类 EOF 子类。
- [x] 新增 parser focused tests：
  `Chunked request truncated trailer empty-value section CR at EOF`、
  `Chunked request truncated trailer whitespace section at EOF`、
  `Chunked request truncated trailer whitespace section CR at EOF`。
- [x] 新增 server focused tests：
  `Malformed chunked request truncated trailer empty-value section CR at EOF -> 400`、
  `Malformed chunked request truncated trailer whitespace section at EOF -> 400`、
  `Malformed chunked request truncated trailer whitespace section CR at EOF -> 400`。
- [x] 新增 security focused tests：
  `Truncated trailer empty-value section CR at EOF -> 400`、
  `Truncated trailer whitespace section at EOF -> 400`、
  `Truncated trailer whitespace section CR at EOF -> 400`。
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
| API gate | 如果 malformed chunk framing 行为写进覆盖矩阵，必须有 parser/server/security 三层证据。 |
| Leak gate | changed-surface focused suites 与 HTTP aggregate 都必须给出 heaptrc `0 unfreed memory blocks`。 |
| Git safety | 只允许 path-limited staging/commit；禁止 `git add .`、reset、覆盖无关文件。 |

## Decisions

| Decision | Rationale |
| --- | --- |
| 本轮优先补 completed trailer line 之后 final blank-line 未完整结束的三类 EOF 子类 | 这是 empty-value / OWS-only trailer line 在前一轮之后最自然剩余的 grammar 边界。 |
| 把 empty-value 与 OWS-only 分开锁 section EOF / section CR EOF | 它们在 parser 状态机里属于不同可达边界，不能只靠宽泛“truncated trailer”覆盖。 |
| 若首跑直接 GREEN，则不碰生产代码 | 当前目标是 correctness proof，不制造伪修复。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；九条新增 focused tests 首轮 direct GREEN，HTTP aggregate 复跑也通过 | 1 | 按 coverage expansion 收口，无需生产修复。 |
