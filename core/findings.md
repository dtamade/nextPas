# Findings: HTTP server benchmark smoke

## Scope

本轮补齐 `benchmarks/nextpas.core.http/bench_server` 的可自动 smoke 能力。目标不是宣称
Go/Rust 对照已经完成，而是先把 nextPas HTTP server benchmark 变成可小规模验证、可稳定采集
指标的基线。

## Confirmed truths

### 1. RED 证明真实缺口

`test_http_benchmarks` 新增后首次 focused gate 失败：

- `1 total, 0 passed, 1 failed`
- failure: `operation marker missing from output: operation=http.server.keepalive`
- heaptrc: `0 unfreed memory blocks`

旧 `bench_server` 会忽略 `--requests 32 --threads 2`，仍用固定 `20000 / 4` 运行，并只输出
`Req/s`，没有 `operation`、`iterations`、`ns/op` 等标准字段。

### 2. 最小实现

`bench_http_server` 现在支持：

- `--requests <n>`
- `--threads <n>`

并输出：

- `operation=http.server.keepalive`
- `iterations=<requests>`
- `threads=<threads>`
- `completed=<successful requests>`
- `elapsed_ns=<elapsed>`
- `ns/op=<elapsed per completed request>`
- `req/s=<throughput>`

### 3. Focused proof

`test_http_benchmarks` 现在覆盖：

- 自动 build `bench_server`。
- 以 `--requests 32 --threads 2` 运行 benchmark。
- 验证 benchmark 进程 exit code 为 0。
- 验证标准字段存在。

## Remaining gaps / risks

- Go/Rust/FPC RTL 对照 benchmark 尚未落地；本轮只是先固定 nextPas 侧 benchmark 输出契约。
- 当前 server benchmark 是 keep-alive hello-world QPS 基线，不覆盖 TLS、WebSocket 或 request body。
