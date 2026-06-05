# Task Plan: HTTP server comparison multi-run evidence tightening

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 `HttpServer` full-chain comparison 的证据稳定性，而不是继续依赖单次
server row。目标是把 `run_server_comparison.sh` 和
`capture_server_comparison_snapshot.sh` 提升为 multi-run runner / snapshot，
让 nextPas / Go / Rust 对照直接产出逐次结果和中位数汇总。

本轮不改 public HTTP API，不改 server/client 生产逻辑，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP coverage / benchmark docs、控制文件与 git status。
- [x] RED：新增 `run_server_comparison.sh --runs 2` summary smoke，先看到
  runner 直接报 `unknown argument: --runs`。
- [x] GREEN：`run_server_comparison.sh` 支持 `--runs N`，每轮保留 `run=...`
  raw output，并追加 nextPas / Go / Rust median summary。
- [x] RED/GREEN：`capture_server_comparison_snapshot.sh` 支持 `--runs N`，
  snapshot 记录 `runs=`、命令和 summary rows。
- [x] 跑 focused benchmark gate，锁住 runner/snapshot multi-run 契约与 heaptrc 无泄漏。
- [x] 跑 fresh `no_url --runs 3` live row，固定 server full-chain 中位数。
- [x] 更新 API coverage / README / benchmark docs / 控制文件。
- [x] 跑 diff check 并 path-limited commit。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/run_server_comparison.sh`
- `benchmarks/nextpas.core.http/capture_server_comparison_snapshot.sh`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Fresh `no_url` 50k/4 `--runs 3` summary:

- nextPas median: `11431 ns/op`, `87476 req/s`
- Go `net/http` median: `55017 ns/op`, `18176 req/s`
- Rust std-only median: `9885 ns/op`, `101153 req/s`

这个结果把 server full-chain 对比从单次 row 提升成了 multi-run 中位数证据。
nextPas 在本机 no-URL microbaseline 中继续明显快于 Go `net/http`，仍落后于 Rust
std-only comparator，但差距必须用 multi-run 或更窄 benchmark 再判断。

## Next target

继续 `6/6 benchmark/performance`。下一批建议直接补 request dispatch /
response serialization 的 micro/full-chain 对照，或增加 Hyper/Tokio Rust comparator，
避免继续只围绕 std-only comparator 做判断。
