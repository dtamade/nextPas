# Findings: HTTP server comparison median snapshot

## Scope

本轮是 benchmark evidence / route-selection batch，不改变 public HTTP API，不改变生产
HTTP server/client 代码，不改 benchmark harness，不手改 generated llhttp，不写
`docs/nextpas.core.http.inbox.md`。

## Median snapshot

Commands:

```text
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload no_url --runs 3
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload adapter_no_url --runs 3
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload url_path --runs 3
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload response_1k --runs 3
```

Median summary:

| workload | nextPas ns/op | nextPas req/s | Rust std-only ns/op | Rust std-only req/s | Go ns/op | Go req/s |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `no_url` | 10405 | 96098 | 9051 | 110479 | 47688 | 20969 |
| `adapter_no_url` | 12280 | 81433 | 8140 | 122845 | 48857 | 20467 |
| `url_path` | 10133 | 98685 | 7391 | 135291 | 47782 | 20928 |
| `response_1k` | 9896 | 101044 | 9408 | 106285 | 50560 | 19778 |

## Direction review

方向没有走偏：本轮没有继续盲目做 micro-optimization，而是用 multi-run median 确认
workload-specific gap。

- `response_1k` 已接近 Rust std-only，暂不优先。
- `no_url` 还慢约 15%，但差距不像 adapter / URL path 明显。
- `url_path` 慢约 37%，说明 URL materialization / path accessor 后续值得做 narrowed proof。
- `adapter_no_url` 慢约 51%，且该 workload 的设计目的就是强制离开 H1 fast path，所以
  下一批优先看 llhttp adapter path。

## Remaining gaps / risks

- Rust comparator 仍是 std-only，不代表 Hyper/Tokio。
- 当前结果是 same-host live snapshot；正式宣称长期排名前还需要更多 runs 和环境记录。
- 下一批如果优化 adapter path，必须补 focused parser/adapter benchmark 或 contract test，
  不能直接改生产代码。
