# Task Plan: HTTP server benchmark result snapshot

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark 完成度。已有 comparison runner 和
snapshot capture，本轮在当前干净 HTTP benchmark commit 上跑一次较大规模本机 snapshot，
并把方法、环境、结果和解释边界写进 HTTP 文档。

要求：

- 运行 `capture_server_comparison_snapshot.sh --requests 20000 --threads 4`。
- 新增 `docs/http/BENCHMARKS.md`，记录环境、参数、nextPas / Go / Rust 三路结果。
- 明确当前结果是本机证据，不是永久性能排名。
- 明确 Rust 当前是 std-only microbaseline，不代表 Hyper/Tokio 等 async Rust server。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_benchmarks` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、HTTP benchmark docs、coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 `capture_server_comparison_snapshot.sh --requests 20000 --threads 4`。
- [x] 新增 `docs/http/BENCHMARKS.md`。
- [x] 更新 `docs/http/README.md` 与 `docs/http/API_COVERAGE.md`。
- [x] 更新控制文件。
- [ ] 运行 focused 验证。
- [ ] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- HTTP benchmark docs 现在不仅有 runner，还记录一份可追溯的本机 snapshot。
- 后续可在同一文档追加更高质量 comparator，例如 Hyper/Tokio Rust server、epoll backend 或 full-chain workload。
