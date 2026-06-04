# Task Plan: HTTP server benchmark snapshot capture

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark 完成度。已有 nextPas / Go / Rust
comparison runner，本轮补 Markdown snapshot capture，让 benchmark 证据可以带环境元数据
归档，同时不把一次本机结果误称为永久性能排名。

要求：

- 先 RED：扩展 `test_http_benchmarks`，要求 `capture_server_comparison_snapshot.sh`
  存在并能生成 Markdown。
- GREEN：snapshot 必须包含 `git_head`、OS、FPC、Go、Rust 版本、运行参数和三路 raw output。
- 质量门：snapshot 不允许包含 FPC `Warning:` / `Note:`，避免把 benchmark 编译噪音固化进结果。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_benchmarks` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、HTTP coverage / README、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 写 RED：`test_http_benchmarks` 要求 snapshot capture runner 存在并生成 Markdown。
- [x] 写 RED：snapshot 不允许包含 compiler `Warning:` / `Note:`。
- [x] 新增 `benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh`。
- [x] 清理 `bench_http_server` 的编译 warning/note。
- [x] 更新 HTTP docs 与控制文件。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh`
- `benchmarks/nextpas.core.http/bench_server/bench_http_server.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 用户可以运行 `capture_server_comparison_snapshot.sh` 生成带环境元数据的 Markdown benchmark 证据。
- focused test 会证明 snapshot 包含 nextPas / Go / Rust 三路指标、环境元数据、且没有 FPC warning/note。
- 当前仍不声明正式性能排名；后续可在干净 commit 上跑一次较大规模 snapshot 并作为报告材料。
