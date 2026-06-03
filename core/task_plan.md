# Task Plan: HTTP fixed-length keep-alive tail proof

## Goal

补齐 `Content-Length` keep-alive garbage tail 的 parser/security focused proof，和现有 server
current-truth 证据形成对称闭环，确认：

- parser 在 same-read 路径只消费首个完整 fixed-length request；
- security raw-wire 下首个请求先正常完成；
- 多余尾巴会在同连接上作为 follow-up malformed request 进入显式 `400` 语义。

## Current Phase

`nextpas.core.http` H1 correctness coverage-expansion。当前继续沿着 request-tail contract 主线前进，
先把 fixed-length 与 chunked 两侧的 current truth 证据补齐，再决定是否需要把 keep-alive overrun
进一步收紧成更早拒绝。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 复读 `docs/design-conventions.md`、`docs/nextpas.core.http.inbox.md`、
  `docs/http/API_COVERAGE.md` 与现有控制文件。
- [x] 扫描 request-tail 相关现有测试与实现，确认 fixed-length keep-alive tail 在 parser/security 两层仍是缺口。
- [x] 新增 parser focused test：`Content-Length keep-alive garbage tail consumes first request only`。
- [x] 新增 security focused test：`Content-Length keep-alive garbage tail safe handling`。
- [x] 跑 `test_http_h1parser` 与 `test_http_security` 首轮验证，记录是 RED 还是 direct GREEN。
- [x] 若失败则仅在 HTTP parser/server 内最小修复；若直接通过，则按 coverage-expansion 收口。
- [x] 同步 inbox、API coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 跑 HTTP 聚合验证、`git diff --check` 与 path-limited git hygiene。
- [ ] path-limited commit，并输出中文收尾报告。

## Quality Gates

| Gate | Rule |
| --- | --- |
| Scope discipline | 只处理 `nextpas.core.http` 相关测试与控制文档，不触碰无关脏文件。 |
| TDD truthfulness | 新增 focused tests 必须先首跑，诚实记录 RED 或 direct GREEN。 |
| API gate | 若把 keep-alive tail 行为写进覆盖矩阵，必须有 parser/server/security 三层证据。 |
| Leak gate | changed-surface focused suites 与 HTTP aggregate 都必须给出 heaptrc `0 unfreed memory blocks`。 |
| Git safety | 只允许 path-limited staging/commit；禁止 `git add .`、reset、覆盖无关文件。 |

## Decisions

| Decision | Rationale |
| --- | --- |
| 本轮优先补 fixed-length keep-alive tail 对称证据 | 这是 request-tail contract 决策前最直接的缺口。 |
| 先补 parser/security，不重复改 server 现有 proof | server 层已有 focused current-truth test，本轮只补缺失层次。 |
| 若首跑直接 GREEN，则不碰生产代码 | 这批目标是 contract proof，不人为制造修复。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；focused 首轮直接 GREEN | 1 | 按 coverage expansion 收口，并继续做聚合验证与文档同步。 |
