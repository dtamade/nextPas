# Task Plan: nextpas.core.http committed-response exception boundary

## Goal

继续收紧 `nextpas.core.http` 的 response-side correctness，
把上一轮的 writer short-write hardening 往上一层推进到 server session 异常路径，
直接锁定一个更重要的 raw-wire 契约：
一旦响应已经 committed（至少已经 `Flush` 到连接），后续 handler 异常不能再追加 synthetic `500`。

## Checklist

- [x] 读取 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status`，确认 shared checkout 里仍有大量无关脏文件，本轮继续只做 path-limited 变更。
- [x] 审阅 `docs/http/ARCHITECTURE.md` / `docs/http/README.md` 与
  `src/nextpas.core.http.impl.h1.pas`，确认 backend truth 已固定，
  这轮不重开 server 模型讨论，直接补 response exception contract。
- [x] 先在 `tests/nextpas.core.http/test_http_server` 新增 committed-response
  exception RED tests，threaded / epoll 两条路径同时锁定。
- [x] 运行 RED：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
- [x] 在 `src/nextpas.core.http.impl.h1.pas` / `src/nextpas.core.http.impl.h1.writer.pas`
  做最小 GREEN 修复：已 committed 或 hijack 的异常路径不再补写 `500`。
- [x] 运行 focused 验证：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `make -C tests/nextpas.core.http/test_http_h1writer clean test`
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 做 path-limited staging / commit，并输出中文收尾报告。

## Current Status

- 本轮是真实生产修复，不是纯 coverage-expansion。
- committed-response exception seam 已经由 focused tests 锁定并修复。
- 本轮不跑全量测试，不做 benchmark，不碰 HTTP 以外的无关脏文件。

## Out of Scope

- 重开 HTTP server / `nextpas.core.net.server` runtime 选型讨论
- 实现 `kqueue` / `IOCP` / 完整 per-connection evented runtime
- 做 full benchmark 或 async public API 改造
- 扩散到 parser/security 以外的无关 HTTP 子模块
