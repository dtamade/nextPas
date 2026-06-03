# Task Plan: nextpas.core.http epoll trailer-complete differential proof

## Goal

继续收紧 `nextpas.core.http` 在 Linux `epoll` backend 下的 correctness proof，
把 differential matrix 从已落地的 keep-alive / fixed-chunked pipelining / hijack，
继续推进到最复杂的 chunked trailer-complete follow-up 语义，
确认 phase-1 backend 与 threaded 路径保持同一 public contract。

## Checklist

- [x] 读取 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status`，确认共享 worktree 里仍有大量无关脏文件，本轮继续只做 path-limited 变更。
- [x] 审阅 `test_http_server`，选定本轮 `epoll` phase-1 最值钱的差异契约：
  - chunked trailer-complete garbage tail -> follow-up `400`
  - chunked trailer-complete truncated follow-up request line / headers -> follow-up `400`
  - chunked trailer-complete same-write pipelining
  - chunked trailer-complete partial follow-up request line 后续可补全为合法第二请求
- [x] 先在 `tests/nextpas.core.http/test_http_server/test_http_server.lpr` 增加 focused tests。
- [x] 运行 focused 验证：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [ ] 做 path-limited staging / commit，并输出中文收尾报告。

## Current Status

- 本轮是 coverage-expansion，不是生产修复。
- 新增 `epoll` trailer-complete focused tests 直接绿，说明 current truth 已满足这批 backend-differential contract。
- 本轮不跑全量测试，不做 benchmark，不碰 HTTP 以外的无关脏文件。

## Out of Scope

- 把 Linux `epoll` 直接升级成完整版 per-connection evented runtime
- 实现 `kqueue` / `IOCP`
- 做 full benchmark 或 async public API 改造
