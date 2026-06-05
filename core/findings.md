# Findings: H1 fast parser Content-Length hot-path trim

## Scope

本轮是 `nextpas.core.http` H1 fast parser 的窄性能修正，不改公开 API，不改
HTTP wire contract。目标是减少 fast path 中一个明确重复的 `Content-Length`
lookup / normalization / scan。

## Baseline evidence

当前 `bench_h1parser` fresh baseline：

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

关键行：

| workload | adapter ns/op | fast ns/op |
| --- | ---: | ---: |
| simple GET | 632.5 | 856.4 |
| 10 headers | 3367.5 | 3679.0 |
| POST 1KB | 1454.5 | 1500.2 |
| pipeline 10 reqs | 6412.8 | 8685.5 |

这说明 standalone fast parser 当前没有达到“fast”预期，尤其 simple GET / pipeline
明显慢于 adapter。

## Negative experiment

我先做了一个不提交的实验：在 server integration 层禁用 fast path。

- baseline `bench_server`: `86066 req/s`
- disabled fast path `bench_server`: `82888 req/s`

结论：禁用 fast path 不是最佳方案，已撤销。即使 standalone parser rows 较慢，
server full-chain 仍可能受分配、request handoff、响应路径和调度噪声影响；不能直接把
microbench 结论等价成 server path 禁用策略。

## Implemented change

旧 `FastParseRequest` 行为：

1. header scan 中已识别 `content-length`，只记录是否见过。
2. 所有 headers 都加入 `IHttpHeaders`。
3. header scan 后再调用 `Result.Headers.Get('Content-Length')`。
4. `Get` 会做 uppercase normalize 判断和线性扫描，然后再 parse int。

新行为：

- 在 header scan 中遇到 `content-length` 时立即用 value span 做 `ParseInt64Fast`。
- 缓存 parsed `LContentLength`。
- header scan 结束后直接使用缓存值计算 `Consumed`。
- duplicate `Content-Length` 仍 fallback。
- invalid `Content-Length` 仍 fallback。
- incomplete body 仍 fallback。

新增 focused regression：

- `test_http_h1fast`: invalid `Content-Length: nope` 必须 `Success=False`。

## Fresh local evidence

After change:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

| workload | before fast ns/op | after fast ns/op |
| --- | ---: | ---: |
| simple GET | 856.4 | 754.9 |
| 10 headers | 3679.0 | 3429.8 |
| POST 1KB | 1500.2 | 1374.2 |
| pipeline 10 reqs | 8685.5 | 7581.2 |

`bench_server` after change produced two local rows:

- clean run: `74197 req/s`
- immediate second run: `85182 req/s`

这些 server rows 噪声明显，本轮不把它们写成 server throughput win。可靠结论只限于
fast parser microbench：重复 lookup 已删除，fast rows 有方向性改善。

## Verification

- `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `19 total, 19 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Remaining gaps / risks

- Fast parser 仍会 eagerly materialize `IHttpHeaders`，这仍是主要成本。
- Fast parser simple GET 仍慢于 optimized adapter simple GET；下一步要考虑 lazy header
  snapshot 或把 server policy flags 从 fast scan 直接传给 server，减少 post-parse lookups。
- Server benchmark 当前噪声较大；正式性能判断需要改进 runner 统计质量。
