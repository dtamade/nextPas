# Task Plan: HTTP server benchmark smoke

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark 完成度。HTTP 目录已有 `bench_server`，
但当前不适合自动 smoke：运行规模固定为 20000/4，输出缺少项目规范要求的标准化
`operation / iterations / ns/op` 字段。

要求：

- 先 RED：新增 `test_http_benchmarks`，构建并以小规模 `--requests 32 --threads 2`
  运行 `bench_server`，要求输出 `operation=http.server.keepalive`、`iterations`、`threads`、
  `ns/op`、`req/s`。
- GREEN：`bench_http_server` 支持 `--requests` / `--threads`，并打印标准化指标。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_benchmarks` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `benchmarks/nextpas.core.http/bench_server` 选择可自动 smoke 的 benchmark 缺口。
- [x] 在 `test_http_benchmarks` 写 RED：benchmark 必须可小规模运行并输出标准字段。
- [x] 改造 `bench_http_server` 参数与输出。
- [x] 更新 `docs/http/API_COVERAGE.md`、`docs/http/README.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/bench_server/bench_http_server.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/Makefile`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- `bench_server` 可被 CI/smoke 用小规模参数快速验证。
- benchmark 输出具备后续 Go/Rust 对照需要的稳定字段。
