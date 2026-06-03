# Task Plan: HTTP truncated terminal chunk ending proof

## Goal

补齐 `terminal 0 chunk` 后空 trailer section 最终 CRLF 缺失的 parser/server/security focused proof，
确认：

- parser 在 `Finish` 后把该输入判成 error/not-complete；
- server 在 peer half-close 后返回显式 `400` 且 handler 不落地；
- security raw-wire 语义也稳定锁成显式 `400`。

## Current Phase

`nextpas.core.http` H1 correctness coverage-expansion。当前继续做 malformed chunk framing 审计，把
terminal chunk / trailer boundary 的 EOF 截断子类逐个锁实，而不是停留在宽泛的 “truncated chunked EOF”
表述。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 复读 `docs/design-conventions.md`、`docs/nextpas.core.http.inbox.md`、
  `docs/http/API_COVERAGE.md` 与现有控制文件。
- [x] 确认当前缺口是 `terminal 0 chunk` 后空 trailer section 最终 CRLF 缺失。
- [x] 新增 parser focused test：`Chunked request truncated terminal chunk ending at EOF`。
- [x] 新增 server focused test：`Malformed chunked request truncated terminal chunk ending at EOF -> 400`。
- [x] 新增 security focused test：`Truncated terminal chunk ending at EOF -> 400`。
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
| 本轮优先补 terminal chunk ending EOF 截断 | 这是 terminal chunk / trailer boundary 上未单独锁住的 grammar 子类。 |
| parser/server/security 三层一起补 | 这样能一次性把 boundary truth 锁实。 |
| 若首跑直接 GREEN，则不碰生产代码 | 当前目标是 correctness proof，不制造伪修复。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；focused 首轮 direct GREEN，HTTP aggregate 也已通过 | 1 | 按 coverage expansion 收口，无需生产修复。 |
