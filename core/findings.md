# Findings: HTTP server benchmark comparison runner

## Scope

本轮补齐 `benchmarks/nextpas.core.http` 的 server comparison runner。目标是把上一轮已落地的
nextPas / Go / Rust comparator harness 收束成一个可手动运行、可写报告文件的入口，为后续
正式 benchmark 结果表做准备。

## Confirmed truths

### 1. RED 证明 runner 缺口

首次扩展 `test_http_benchmarks` 后 focused gate 失败：

- `4 total, 3 passed, 1 failed`
- failure: `server comparison runner exists`
- heaptrc: `0 unfreed memory blocks`

这证明仓库还缺少统一 comparison runner。

### 2. RED 证明 result capture 缺口

新增 `--output` 契约后 focused gate 再次失败：

- `4 total, 3 passed, 1 failed`
- failure: `unknown argument: --output`
- heaptrc: `0 unfreed memory blocks`

这证明 runner 需要显式支持报告写入，而不是只依赖调用方 shell redirect。

### 3. 最小实现

`run_server_comparison.sh` 现在支持：

- `--requests <n>`
- `--threads <n>`
- `--output <path>`

runner 会：

- build nextPas `bench_server`
- build Go `net/http` comparator
- build Rust std-only comparator
- 顺序运行三路 benchmark
- 输出 `comparison=http.server.keepalive`
- 保留每一路的 `operation`、`impl`、`iterations`、`threads`、`completed`、`elapsed_ns`、
  `ns/op`、`req/s`
- 如果传入 `--output`，用同一份 stdout 内容写入报告文件

## Remaining gaps / risks

- Rust comparator 当前仍是 std-only microbaseline，不是 Hyper/Tokio 生态 server。
- runner 现在提供可重复采集入口，但还没有固定的正式结果表、环境元数据表或性能阈值。
- 当前 benchmark 仍是 HTTP/1.1 keep-alive hello-world QPS 基线，不覆盖 TLS、WebSocket、request body、
  router/middleware full-chain 或 epoll backend。
