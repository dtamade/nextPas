# Task Plan: nextpas.core.http h1 response short-write hardening

## Goal

继续收紧 `nextpas.core.http` 的 response write correctness，
把关注点从已完成的 `epoll` follow-up tail differential proof，
推进到 `TH1ResponseWriter` / `TChunkedWriter` 的 short-write / zero-progress seam，
确认 response framing 与 body write 不会在底层 partial write 时静默截断。

## Checklist

- [x] 读取 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status`，确认共享 worktree 里仍有大量无关脏文件，本轮继续只做 path-limited 变更。
- [x] 审阅 `h1.writer` / `h1.chunked` / `io.buffer` 实现与现有 tests，锁定 short-write seam：
  - status/header/CRLF framing 不能静默 short-write
  - chunked framing / terminal chunk 不能静默 short-write
  - non-chunked body write 不能只返回 partial count 而无异常
- [x] 先在 `tests/nextpas.core.http/test_http_h1chunked` 与
  `tests/nextpas.core.http/test_http_h1writer` 增加 focused RED tests。
- [x] 运行 focused 验证：
  - `make -C tests/nextpas.core.http/test_http_h1chunked clean test`
  - `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 做 path-limited staging / commit，并输出中文收尾报告。

## Current Status

- 本轮先 RED 后 GREEN，是一轮真实生产修复。
- `TH1ResponseWriter` / `TChunkedWriter` 现在在 short-write 下改为 write-all-or-raise，不再静默截断 framing / body。
- 本轮 path-limited commit 已完成。
- 本轮不跑全量测试，不做 benchmark，不碰 HTTP 以外的无关脏文件。

## Out of Scope

- 把 Linux `epoll` 直接升级成完整版 per-connection evented runtime
- 实现 `kqueue` / `IOCP`
- 做 full benchmark 或 async public API 改造
