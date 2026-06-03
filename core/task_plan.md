# Task Plan: nextpas.core.http zero-progress buffered write boundary

## Goal

继续收紧 `nextpas.core.http` 的 response-side correctness，
把上轮已经明确的 silent flush-error residual 真正收口：
当底层 `IWriter` 出现 zero-progress write 时，buffered writer 必须显式失败，
HTTP server session 也必须在首个响应写失败后停止，不得继续消费同连接里的后续 pipelined request。

## Checklist

- [x] 读取 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status`，确认 shared checkout 里仍有大量无关脏文件，本轮继续只做 path-limited 变更。
- [x] 审阅 `io.buffer` 与 `h1` session 当前实现，确认 residual 是 zero-progress buffered write 被静默吞掉。
- [x] 先做 RED：
  - `test_io`: buffered writer flush/direct-write 的 zero-progress 必须抛 `EIOError`
  - `test_http_server`: 首个响应写失败后，session 不得继续处理第二个 pipelined request
- [x] 运行 RED：
  - `make -C tests/nextpas.core.io/test_io clean test`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
- [x] 做最小 GREEN 修复：
  - `src/nextpas.core.io.buffer.pas`
- [x] 运行 focused 验证：
  - `make -C tests/nextpas.core.io/test_io clean test`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `make -C tests/nextpas.core.http/test_http_client clean test`
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 做 path-limited staging / commit，并输出中文收尾报告。

## Current Status

- 本轮是真实生产修复，不是纯 coverage-expansion。
- zero-progress buffered write seam 已由 `io` + `http server` 两层 focused tests 锁定并修复。
- 本轮不跑全量测试，不做 benchmark，不碰 HTTP 以外的无关脏文件；只触及为 HTTP correctness 必需的 `io.buffer` 依赖点。

## Out of Scope

- 重开 HTTP server / `nextpas.core.net.server` runtime 选型讨论
- 实现 `kqueue` / `IOCP` / 完整 per-connection evented runtime
- 做 full benchmark 或 async public API 改造
- 扩散到 parser/security 以外的无关 HTTP 子模块
