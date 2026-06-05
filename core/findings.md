# Findings: HTTP H1 writer 200 OK status-line fast path

## Scope

本轮是 production performance micro-optimization，不改变 public HTTP API，不改变
HTTP wire contract，不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

`TH1ResponseWriter.WriteStatusLine` 现在对常见 `HTTP_STATUS_OK` 使用固定 status-line：

```text
HTTP/1.1 200 OK\r\n
```

其他 status 仍走旧逻辑：

```text
HTTP/1.1 <status-code> <HttpStatusText(status)>\r\n
```

这避免了 `200 OK` 路径上的 `IntToStr`、`HttpStatusText` 与多段 `WriteStr` 调用，
但不改 headers 输出、chunked 判断、body 写入、HEAD suppression、1xx/101/204/304
语义或 short-write retry 行为。

## Contract evidence

Baseline before production change:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test

29 total, 29 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

After production change:

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test

29 total, 29 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

Benchmark contract:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local H1 writer rows after the change:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='headers only 200' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run

headers only 200: 1284.0 ns/op, 778840 ops/s
```

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='fixed 200 13B' \
make -C benchmarks/nextpas.core.http/bench_h1writer run

fixed 200 13B: 1261.1 ns/op, 792973 ops/s
```

Previous committed local rows were:

- `headers only 200`: `1414.6 ns/op`, `706917 ops/s`
- `fixed 200 13B`: `1389.1 ns/op`, `719869 ops/s`

The clean `headers only 200` build emitted no FPC `Warning:` or `Note:` lines.

## Direction review

方向没有走偏：本轮只优化最高频的 `200 OK` status-line 写入，不碰 HTTP public API、
header iteration、chunked/no-body/HEAD 语义或 server runtime。收益出现在两个 filtered
writer rows 上，且 focused wire-byte tests 保持 green，因此这条 micro-optimization
值得保留。

## Remaining gaps / risks

- 这不是 full-chain server throughput 结论；只证明 H1 writer narrowed rows 变快。
- `WriteAllHeaders` 仍然按 header name / separator / value / CRLF 多段写入，可能仍是
  下一层成本来源。
- 后续若合并 header 输出，必须保护 `IHttpHeaders.ForEach` 顺序、小写 normalization、
  repeated headers、short-write retry 和 no-body/chunked contract。
