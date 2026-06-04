# Findings: HTTP server benchmark result snapshot

## Scope

本轮把 `capture_server_comparison_snapshot.sh` 的实际输出转成文档化 benchmark 证据。
目标不是宣称 nextPas 已经全面胜过 Go/Rust，而是先让 HTTP server keep-alive 对照有可重复
方法、环境元数据和本机结果。

## Confirmed truths

### 1. Snapshot command

运行：

```sh
benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh \
  --requests 20000 --threads 4 \
  --output build/projects/nextpas.core.http/server_comparison/snapshot-2026-06-05.md
```

### 2. Environment

- `captured_at=2026-06-04T21:50:49Z`
- `git_head=f62d2a28dae20ab403a9f75bd2af8e7fa2d6aff7`
- `fpc_version=3.3.1`
- `go_version=go version go1.23.5 linux/amd64`
- `rustc_version=rustc 1.94.0 (4a4ef493e 2026-03-02)`
- `requests=20000`
- `threads=4`

### 3. Local result

| impl | completed | elapsed_ns | ns/op | req/s |
| --- | ---: | ---: | ---: | ---: |
| nextPas | 20000 | 247938762 | 12396 | 80665 |
| Go `net/http` | 20000 | 981937616 | 49096 | 20367 |
| Rust std-only | 20000 | 197099848 | 9854 | 101471 |

### 4. Interpretation boundary

- 这是本机一次 run 的 evidence，不是永久性能排名。
- Rust 当前是 std-only comparator，不代表 Hyper/Tokio ecosystem server。
- workload 是 HTTP/1.1 keep-alive hello-world，不覆盖 TLS、request body、WebSocket、
  router/middleware full-chain 或 epoll backend。

## Remaining gaps / risks

- 还需要 Hyper/Tokio comparator 才能更合理对标现代 Rust async server。
- 还需要 full-chain / router / request-body / epoll backend benchmark snapshot。
- 如果要形成正式性能报告，应至少多轮运行并记录 variance，而不是只用单次 snapshot。
