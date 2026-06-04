# Findings: HTTP server benchmark comparators

## Scope

本轮补齐 `benchmarks/nextpas.core.http` 的 server benchmark comparator smoke。目标是把
nextPas / Go / Rust 都锁到同一小规模 keep-alive hello-world 输出契约，先保证 harness 可
构建、可运行、可采集字段，再进入后续正式 benchmark 结果对照。

## Confirmed truths

### 1. RED 证明真实缺口

扩展 `test_http_benchmarks` 后首次 focused gate 失败：

- `3 total, 0 passed, 3 failed`
- nextPas benchmark 缺少 `impl=nextpas`
- Go / Rust comparator 路径尚不存在，core root resolution 失败
- heaptrc: `0 unfreed memory blocks`

这说明测试确实在锁新契约，而不是重复验证旧 smoke。

### 2. 最小实现

本轮实现：

- `bench_http_server` 输出新增 `impl=nextpas`。
- `compare_go/main.go` 使用 Go 标准库 `net/http` server 和 keep-alive client。
- `compare_rust/main.rs` 使用 Rust standard library 实现最小 HTTP/1.1 keep-alive server/client，
  不依赖外部 crate，保证 smoke gate 快速稳定。

三条输出统一包含：

- `operation=http.server.keepalive`
- `impl=<nextpas|go|rust>`
- `iterations=<requests>`
- `threads=<threads>`
- `completed=<successful requests>`
- `elapsed_ns=<elapsed>`
- `ns/op=<elapsed per completed request>`
- `req/s=<throughput>`

### 3. Focused proof

`test_http_benchmarks` 现在覆盖：

- 自动 build `bench_server`。
- 自动 `go build -o ... main.go`。
- 自动 `rustc -O -o ... main.rs`。
- 三条都以 `--requests 32 --threads 2` 运行。
- 验证进程 exit code 为 0，并验证统一字段存在。

## Remaining gaps / risks

- Rust comparator 当前是 std-only microbaseline，不是 Hyper/Tokio 生态 server；这是为了保持
  focused smoke 零外部依赖。正式 benchmark 轮次仍应补 Hyper/Tokio 或其他主流 Rust server 对照。
- 当前 benchmark 是 HTTP/1.1 keep-alive hello-world QPS 基线，不覆盖 TLS、WebSocket、request body、
  router/middleware full-chain 或 epoll backend。
- 本轮只做 harness smoke，不给性能排名下结论。
