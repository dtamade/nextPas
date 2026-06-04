# Task Plan: HTTP server benchmark comparators

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark 完成度。上一轮已经把 nextPas
`bench_http_server` 收成可小规模 smoke 的稳定输出，本轮补 Go/Rust 对照 smoke，让
后续真实 benchmark 采集可以沿用同一字段格式。

要求：

- 先 RED：扩展 `test_http_benchmarks`，要求 nextPas / Go / Rust 三条 keep-alive
  server benchmark 都能以 `--requests 32 --threads 2` 构建并运行。
- GREEN：补 `impl=<nextpas|go|rust>` 字段，并新增 Go/Rust comparator 源码。
- comparator smoke 不引入外部 crate / module 下载，避免 focused gate 慢化或不稳定。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_benchmarks` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、HTTP coverage / README、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 写 RED：`test_http_benchmarks` 要求 Go/Rust comparator 和统一 `impl` 字段。
- [x] 给 nextPas benchmark 输出补 `impl=nextpas`。
- [x] 新增 Go `net/http` keep-alive comparator。
- [x] 新增 Rust std-only keep-alive HTTP/1.1 comparator。
- [x] 更新 HTTP docs 与控制文件。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/bench_server/bench_http_server.lpr`
- `benchmarks/nextpas.core.http/compare_go/main.go`
- `benchmarks/nextpas.core.http/compare_rust/main.rs`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- `test_http_benchmarks` 同时证明 nextPas / Go / Rust 三条 server benchmark smoke 可运行。
- 三条输出都包含 `operation`、`impl`、`iterations`、`threads`、`completed`、`elapsed_ns`、
  `ns/op`、`req/s`。
- 当前只是 comparator harness，不宣称正式性能排名；正式大规模 benchmark 和 Go/Rust/FPC
  结果表放到后续 benchmark 轮次。
