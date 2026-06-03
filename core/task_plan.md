# Task Plan: nextpas.core.net/http server runtime foundation

## Goal

固定 `nextpas.core.net.server` 与 `nextpas.core.http` 的 server runtime 设计真相，
把当前已落地的 foundation / runtime / `epoll` phase-1 路线写进仓库文件，并用 focused
tests 验证公开 contract 没有回退。

## Checklist

- [x] 读取 `docs/design-conventions.md`、`docs/nextpas.core.http.inbox.md`、
  `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status`，确认共享 worktree 里存在大量无关脏文件，本轮只做 path-limited 变更。
- [x] 审阅 `nextpas.core.net.server` 当前未提交改动，确认 foundation runtime helper、
  Linux `epoll` backend 与 focused tests 的真实边界。
- [x] 校准 `docs/net/ARCHITECTURE.md`、`docs/net/README.md`、`docs/http/README.md`、
  `docs/http/API_COVERAGE.md` 的设计/实现漂移。
- [x] 运行 focused 验证：
  - `make -C tests/nextpas.core.net.server/test_net_server clean test`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
- [ ] 做 path-limited staging / commit，并输出中文收尾报告。

## Current Status

- 当前相关生产改动已经存在于共享工作树：
  - `nextpas.core.net.server.runtime`
  - `nextpas.core.net.server.epoll`
  - `nextpas.core.net.server` / `threaded` 复用 runtime helper
  - `test_net_server` / `test_http_server` 对应 focused proof
- 本轮主要工作是把设计固定到文档，并验证这些 runtime 改动确实通过 focused tests。
- 本轮不跑全量测试，不做 benchmark，不碰 HTTP 以外的无关脏文件。

## Out of Scope

- 把 Linux `epoll` 直接升级成完整版 per-connection evented runtime
- 实现 `kqueue` / `IOCP`
- 做 full benchmark 或 async public API 改造
