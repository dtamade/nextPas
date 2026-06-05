# Findings: HTTP H1 writer header-only benchmark split

## Scope

本轮是 benchmark/tooling 强化，不改变 public HTTP API，不改变 wire contract，
不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

`bench_h1writer` 现在除了 `fixed 200 13B`，还输出：

```text
operation=http.h1writer.serialize
headers only 200
```

`headers only 200` 每次迭代创建一个 `TH1ResponseWriter`，设置
`content-type: text/plain` 与 `content-length: 0`，调用 `WriteHeader(200)` 和
`Flush`，然后把响应写入固定 in-memory writer。它不写 body，也不触发 chunked
default，用来隔离 writer construction + header/status serialization 成本。

`test_http_benchmarks` 现在对 H1 writer row 使用真实 run-row 断言：同一行必须包含
row name 和 `iters`，避免 `bench_filter=` 或 summary 行误判成 benchmark row。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

26 total, 25 passed, 1 failed
bench_h1writer response serialization smoke failed:
H1 writer headers-only benchmark row missing benchmark run row: headers only 200
heaptrc: 0 unfreed memory blocks
```

GREEN:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local H1 writer rows:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='headers only 200' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run

headers only 200: 1414.6 ns/op, 706917 ops/s
```

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='fixed 200 13B' \
make -C benchmarks/nextpas.core.http/bench_h1writer run

fixed 200 13B: 1389.1 ns/op, 719869 ops/s
```

The clean `headers only 200` build emitted no FPC `Warning:` or `Note:` lines.

## Sidecar review

Sidecar 子代理只读审计结论与本轮方向一致：

- 最小可测试 seam 是 `bench_h1writer` 的 `headers only 200` row。
- 真正生产热点 seam 更可能在 `TH1ResponseWriter.WriteStatusLine` 与
  `TH1ResponseWriter.WriteAllHeaders` 的多段小写入。
- 不应先改 `IHttpHeaders.ForEach`、header normalization/order、chunked/no-body/HEAD
  contract，也不应复用 writer/header object 以免 keep-alive 请求间泄漏状态。

## Direction review

方向没有走偏：本轮没有把 benchmark 当成优化成果，只补足了 writer 成本归因的可测试
row。新 row 显示 header/status serialization 与 writer setup 已经占据小响应 writer
row 的大部分成本，因此下一批生产优化应针对 status-line/header materialization，而不是
继续优化 body copy 或 outbound buffer。

## Remaining gaps / risks

- 本轮没有改生产 writer，因此没有吞吐提升；它只是把优化目标从猜测收窄为可测 seam。
- 单次 benchmark row 有噪声，优化后必须对比同一 binary / same-host filtered rows。
- 若下一批改 `WriteStatusLine`，必须跑 `test_http_h1writer` 保护精确 wire bytes，
  再跑 `test_http_benchmarks` 保护 benchmark contract。
