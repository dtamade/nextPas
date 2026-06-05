# Findings: HTTP H1 writer header-line coalescing

## Scope

本轮是 production performance micro-optimization，不改变 public HTTP API，不改变
HTTP wire contract，不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

`TH1ResponseWriter.WriteAllHeaders` 现在会把每个 header line 物化成一段连续字节后写出：

- 常见长度 `<= 512` bytes 的 header line 走栈缓冲，无 heap string 分配。
- 更长 header line fallback 到 heap string，保持相同 wire bytes。
- 每个 header line 只进入一次 write-all invocation；full-progress writer 下一次 `Write` 完成，short writer 仍由 `WriteAllOrRaise` 负责 retry 和 zero-progress failure。

保留语义：

- `IHttpHeaders.ForEach` 顺序不变。
- header name normalization / repeated headers 不变。
- `Transfer-Encoding: chunked` default、no-body statuses、HEAD suppression 不变。
- short-writer 下 header/body/chunk framing 的 write-all contract 不变。

## RED evidence

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test

30 total, 29 passed, 1 failed
Header lines use a single writer call each: expected 4, got 10
heaptrc: 0 unfreed memory blocks
```

## GREEN / contract evidence

```text
make -C tests/nextpas.core.http/test_http_h1writer clean test

30 total, 30 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Rejected intermediate implementation:

- simple string concatenation reduced write calls but regressed live rows:
  `headers only 200` `1324.4 ns/op`, `fixed 200 13B` `1363.7 ns/op`.
- explicit heap `SetLength + Move` improved that but still did not beat the prior committed row:
  `headers only 200` `1291.2 ns/op`, `fixed 200 13B` `1311.7 ns/op`.

Kept stack-buffer implementation:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='headers only 200' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run

headers only 200: 1247.1 ns/op, 801852 ops/s
```

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='fixed 200 13B' \
make -C benchmarks/nextpas.core.http/bench_h1writer run

fixed 200 13B: 1250.5 ns/op, 799680 ops/s
```

Previous committed local rows after `HTTP_STATUS_OK` status-line fast path:

- `headers only 200`: `1284.0 ns/op`, `778840 ops/s`
- `fixed 200 13B`: `1261.1 ns/op`, `792973 ops/s`

## Direction review

方向没有走偏：本轮没有为了“减少调用次数”盲目提交退化实现，而是先用 focused RED 锁住
contract，再用 live rows 淘汰拼接版，最终保留栈缓冲常见路径。当前结论仍只限于
H1 writer narrowed rows，不声明 full-chain server throughput 提升。

## Remaining gaps / risks

- 栈缓冲阈值 `512` 是保守常见路径，不是 header-size policy；超长 header line 仍走 fallback。
- 还没有证明这条优化对 real socket / epoll full-chain 有直接收益。
- 下一步需要避免继续碎片化微调，优先用 full-chain / narrowed profiler 判断新的瓶颈位置。
