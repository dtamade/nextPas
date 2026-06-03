# Task Plan: HTTP chunked trailer pipelined next-request proof

## Goal

补齐 `chunked + trailer + valid pipelined next request` 的正向对称 proof：

- parser：完整 trailer section 结束后，same-read 下一请求不会污染首个 request；
- server：同一 write 中，trailer-complete 的首个 chunked request 与下一请求都能各自独立完成；
- 继续保持 trailer declaration 保留、实际 trailer field 不进入普通请求头的窄契约。

## Current Phase

`nextpas.core.http` correctness coverage-expansion。当前沿 keep-alive request-tail /
pipeline 边界继续收口，把上一批 trailer-complete malformed tail truth 再补上
valid pipelined next-request 对称 proof。

## Active Batch Checklist

- [x] 检查 shared checkout 的无关脏文件，确认本轮只处理 HTTP 相关路径。
- [x] 快速确认 `chunked + trailer + valid pipelined next request` 目前尚无单独 focused proof。
- [x] 新增 parser focused test：
  `Chunked trailer pipelined next request does not pollute current request`。
- [x] 新增 server focused test：
  `Chunked trailer pipelined requests in single write`。
- [x] 只跑 changed-surface focused suites：
  `test_http_h1parser`、`test_http_server`。
- [x] 根据首轮结果判断是否需要生产修复。
- [x] 最小更新 `API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 跑 `git diff --check` 与 path-limited git hygiene。
- [ ] path-limited commit，并输出中文收尾报告。

## Quality Gates

| Gate | Rule |
| --- | --- |
| Scope discipline | 只处理 `nextpas.core.http` 相关测试与控制文档。 |
| Verification discipline | 本轮只跑 changed-surface focused suites，不默认跑全量。 |
| TDD truthfulness | 新增 tests 已首跑，必须诚实记录 RED 或 direct GREEN。 |
| Leak gate | changed-surface suites 必须给出 heaptrc `0 unfreed memory blocks`。 |
| Git safety | 只允许 path-limited staging/commit；禁止 `git add .`、reset、覆盖无关文件。 |

## Decisions

| Decision | Rationale |
| --- | --- |
| 本轮只补 parser/server，不补 security | 这是正向 pipeline contract，不是新的 malformed/security rejection 子类；优先保持 batch 窄且高效。 |
| 不跑 HTTP aggregate | 本轮只是 changed-surface coverage-expansion，focused suites 已足够证明新增契约。 |
| 首轮 direct GREEN 就不碰生产代码 | 当前目标仍是 correctness proof，不制造伪修复。 |

## Errors Encountered

| Error | Attempt | Resolution |
| --- | --- | --- |
| 暂无实现错误；两条新增 focused tests 首轮 direct GREEN | 1 | 维持 coverage expansion 路线，不改生产代码。 |
