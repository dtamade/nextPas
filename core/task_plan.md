# Task Plan: HTTP server benchmark comparison runner

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark 完成度。已有 nextPas / Go / Rust
keep-alive comparator smoke，本轮补正式 comparison runner，让三路 benchmark 可以用同一个
入口构建、运行、输出，并可把结果写成报告文件。

要求：

- 先 RED：扩展 `test_http_benchmarks`，要求 `run_server_comparison.sh` 存在并能小规模运行。
- GREEN：runner 支持 `--requests` / `--threads` / `--output`。
- runner 输出必须包含 `comparison=http.server.keepalive`，并保留三路 benchmark 的统一字段。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_benchmarks` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、HTTP coverage / README、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 写 RED：`test_http_benchmarks` 要求 comparison runner 存在并输出三路 impl。
- [x] 写 RED：runner 必须支持 `--output` 并生成报告文件。
- [x] 新增 `benchmarks/nextpas.core.http/run_server_comparison.sh`。
- [x] 更新 HTTP docs 与控制文件。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/run_server_comparison.sh`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 用户可以直接运行 `benchmarks/nextpas.core.http/run_server_comparison.sh` 做三路对照。
- focused test 会证明 runner stdout 与 `--output` 报告都包含 nextPas / Go / Rust 三路指标。
- 当前仍不声明正式性能排名；正式结果表和更高质量 Rust async comparator 放到后续 benchmark 轮次。
