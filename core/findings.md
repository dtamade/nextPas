# Findings: H1 server no-URL benchmark correlation

## Scope

本轮是 benchmark/correlation 强化，不改变 public HTTP API，不改变 wire contract，
不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Root cause

上一批 lazy request-target projection 的微基准显示 request creation 子步骤有收益，
但缺少 full-chain 证据说明这个收益是否能穿透到真实 server benchmark。

只读检查后发现当前 `bench_server` handler 已经完全不读取 `AReq.Url` 或
`AReq.QueryParam`。也就是说它天然就是 lazy projection 最可能受益的 no-URL
workload；问题是输出没有显式标注 workload，容易被误读成一般 router/middleware
场景。

## Implemented decision

在三方 comparator 输出中加入同一行：

```text
workload=no_url
```

覆盖范围：

- nextPas `bench_server`
- Go `net/http` comparator
- Rust std-only comparator
- `run_server_comparison.sh` 与 snapshot smoke 通过 existing raw output 自动覆盖

## Performance evidence

Fresh local row:

```text
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4

nextPas no_url: 77958 req/s, 12827 ns/op
Go net/http no_url: 18871 req/s, 52990 ns/op
Rust std-only no_url: 98422 req/s, 10160 ns/op
```

这个结果没有证明上一批 lazy projection 带来了稳定 full-chain req/s 提升。nextPas
仍落在此前本机 server benchmark 噪声带内，并继续落后 Rust std-only comparator。

## Verification evidence

RED proof:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

5 failed: bench_server, go comparator, rust comparator, server comparison runner,
server comparison snapshot all missed workload=no_url.
heaptrc: 0 unfreed memory blocks
```

GREEN focused gate:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

13 total, 13 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Direction review

方向没有走偏：本轮没有把微基准收益夸大成 server throughput 结论，而是把 benchmark
语义标清，并用 Go/Rust 对照重测。当前证据指向：下一步应继续定位 no-URL workload
里的 socket/runtime、response writer、request dispatch 或 header materialization
成本，而不是优先改 public API。

## Remaining gaps / risks

- 还缺 URL-touch / router-touch workload，用来证明 lazy projection 与 route-heavy
  场景之间的差异。
- Rust comparator 仍是 std-only microbaseline，不代表 Hyper/Tokio 生态性能。
- 本机 benchmark 仍有调度噪声；正式性能结论需要多轮 snapshot 或更稳定 runner。
