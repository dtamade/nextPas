# Task Plan: HTTP server comparison median snapshot

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批修正了 `bench_fullchain` 的客户端逐字节读法，本轮用 `run_server_comparison.sh --runs 3`
对四个 server workload 做 median snapshot，避免基于单次噪声判断优化方向。

本轮不改 public HTTP API，不改生产 server/client 代码，不改 benchmark harness，
不手改 generated `src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] 跑 `run_server_comparison.sh --requests 20000 --threads 4 --workload no_url --runs 3`。
- [x] 跑 `run_server_comparison.sh --requests 20000 --threads 4 --workload adapter_no_url --runs 3`。
- [x] 跑 `run_server_comparison.sh --requests 20000 --threads 4 --workload url_path --runs 3`。
- [x] 跑 `run_server_comparison.sh --requests 20000 --threads 4 --workload response_1k --runs 3`。
- [x] 汇总 nextPas / Rust std-only / Go `net/http` median `ns/op` 与 `req/s`。
- [x] 判断下一批优化 seam：优先 `adapter_no_url` / llhttp adapter path，其次 `url_path` / URL materialization。
- [x] 更新 API coverage / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

2026-06-05 same-host median snapshot:

| workload | nextPas ns/op | Rust std-only ns/op | Go ns/op | Direction |
| --- | ---: | ---: | ---: | --- |
| `no_url` | 10405 | 9051 | 47688 | nextPas 比 Rust 慢约 15%，显著快于 Go |
| `adapter_no_url` | 12280 | 8140 | 48857 | nextPas 比 Rust 慢约 51%，下一批首要 seam |
| `url_path` | 10133 | 7391 | 47782 | nextPas 比 Rust 慢约 37%，第二优先 seam |
| `response_1k` | 9896 | 9408 | 50560 | nextPas 比 Rust 慢约 5%，暂不优先 |

`adapter_no_url` 强制请求离开 H1 fast path，进入 llhttp adapter path；这是当前最清晰的
性能差距来源。`url_path` 仍走 fast parser，但 handler 访问 `AReq.Url.Path`，因此更像
request URL materialization / path accessor 成本。

## Next target

继续 `6/6 benchmark/performance`。下一批建议直接针对 `adapter_no_url`：先补或复用
H1 parser / adapter narrowed benchmark，找出 llhttp adapter path 的分配与 header/request
construction 成本，再先 RED 后做最小优化。
