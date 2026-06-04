# Findings: HTTP server benchmark snapshot capture

## Scope

本轮补齐 `benchmarks/nextpas.core.http` 的 Markdown benchmark snapshot capture。目标是把
comparison runner 的 raw output 和当前环境元数据放进同一份可归档报告，为后续正式性能对照
提供稳定证据入口。

## Confirmed truths

### 1. RED 证明 snapshot capture 缺口

首次扩展 `test_http_benchmarks` 后 focused gate 失败：

- `5 total, 4 passed, 1 failed`
- failure: `server comparison snapshot runner exists`
- heaptrc: `0 unfreed memory blocks`

这证明仓库还缺少 Markdown snapshot capture 入口。

### 2. RED 证明 benchmark build 噪音

新增 snapshot quality gate 后 focused gate 再次失败：

- `5 total, 4 passed, 1 failed`
- failure: snapshot 内出现 FPC `Warning:`
- 同一 raw output 还暴露 `GReady`、`LThreadCount` unused notes
- heaptrc: `0 unfreed memory blocks`

这证明 benchmark 证据会把编译 warning/note 固化进报告，需要清理。

### 3. 最小实现

`capture_server_comparison_snapshot.sh` 现在支持：

- `--requests <n>`
- `--threads <n>`
- `--output <path>`

snapshot 会包含：

- `captured_at`
- `git_head`
- `git_status`
- `os`
- `fpc_version`
- `go_version`
- `rustc_version`
- `requests`
- `threads`
- raw comparison output

`bench_http_server` 同步清理：

- 删除未使用的 `GReady`
- 删除未使用的 `LThreadCount`
- 将线程参数读取从 signed pointer cast 改为 `PtrUInt`

## Remaining gaps / risks

- 当前提供的是 snapshot capture 工具，不提交固定性能排名。
- Rust comparator 当前仍是 std-only microbaseline，不是 Hyper/Tokio 生态 server。
- 当前 benchmark 仍是 HTTP/1.1 keep-alive hello-world QPS 基线，不覆盖 TLS、WebSocket、request body、
  router/middleware full-chain 或 epoll backend。
