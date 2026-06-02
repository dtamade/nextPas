# Task Plan: HTTP chunked pipelined request isolation proof

## Goal

把 `chunked` 首请求后紧跟同包下一请求的 parser/server 当前行为锁进 focused 回归，确认：

- parser 在 same-read 路径只消费首个完整 chunked request；
- server 在 same-write 路径会把第二个 request 留到后续分发；
- 若首跑直接 GREEN，如实记录为 coverage expansion，不虚构生产修复。

## Current Phase

`nextpas.core.http` H1 correctness coverage-expansion。当前不重开新设计，也不主动扩公开 API；先继续把
keep-alive / pipelining 边界的 current truth 证明清楚，再决定是否需要更激进的契约收紧。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 复读 `docs/design-conventions.md`、`docs/nextpas.core.http.inbox.md`、
  `docs/http/API_COVERAGE.md` 与现有控制文件。
- [x] 审阅未提交的 parser/server focused tests，确认它们只锁定 chunked first-request pipelining 行为。
- [x] 跑 `test_http_h1parser` 首轮验证，记录是 RED 还是 direct GREEN。
- [x] 跑 `test_http_server` 首轮验证，记录是 RED 还是 direct GREEN。
- [x] 若失败则仅在 HTTP parser/server 内最小修复；若直接通过，则按 coverage-expansion 收口。
- [x] 同步 inbox、API coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 跑 HTTP 聚合验证、`git diff --check` 与 path-limited git hygiene。
- [x] path-limited commit，并输出中文收尾报告。

## Quality Gates

| Gate | Rule |
| --- | --- |
| Scope discipline | 只处理 `nextpas.core.http` 相关测试与控制文档，不触碰无关脏文件。 |
| TDD truthfulness | 新增 focused tests 必须先首跑，诚实记录 RED 或 direct GREEN。 |
| API gate | 如果行为描述进入文档矩阵，必须有 focused parser/server 证据支撑。 |
| Leak gate | changed-surface focused suites 与 HTTP aggregate 都必须给出 heaptrc `0 unfreed memory blocks`。 |
| Git safety | 只允许 path-limited staging/commit；禁止 `git add .`、reset、覆盖无关文件。 |

## Decisions

| Decision | Rationale |
| --- | --- |
| 本轮优先完成未提交的 chunked pipelining focused tests | 这是当前工作树里唯一未收口的 HTTP 改动，先把事实闭环。 |
| 如果 tests 直接 GREEN，则不碰生产代码 | 当前轮目标是 correctness proof，不为了“看起来更有动作”而制造实现改动。 |
| 更新控制文件而不是只在聊天里说明 | 用户要求 HTTP inbox/coverage/planning 持续可恢复，不依赖会话上下文。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；首轮 focused tests 直接 GREEN | 1 | 记录为 coverage expansion，继续做文档和验证收口。 |
