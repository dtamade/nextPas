# Findings: HTTP full-chain benchmark output contract

## Scope

本轮是 benchmark/tooling 强化，不改变 public HTTP API，不改变 wire contract，
不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

`bench_fullchain` 现在支持：

```text
NEXTPAS_BENCH_MAX_ITERS=<positive integer>
NEXTPAS_BENCH_FILTER=<workload or display-name fragment>
```

并输出稳定 marker：

```text
operation=http.fullchain.keepalive
workload=<plaintext|json|echo_1k|sink_16k|param_route>
iterations=<N>
completed=<N>
elapsed_ns=<ns>
ns/op=<float>
req/s=<float>
```

这个 benchmark 仍然启动真实 `THttpServer`，使用单连接 keep-alive，逐次写入请求并
读取完整响应。`completed` 只统计读到足够响应字节的请求，用来防止只读 header
或前缀的 benchmark 误报成功。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

26 total, 25 passed, 1 failed
bench_fullchain plaintext smoke failed:
fullchain operation marker missing from output: operation=http.fullchain.keepalive
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

Fresh local full-chain plaintext row:

```text
NEXTPAS_BENCH_MAX_ITERS=1000 \
NEXTPAS_BENCH_FILTER=plaintext \
make -C benchmarks/nextpas.core.http/bench_fullchain clean run

workload=plaintext
iterations=1000
completed=1000
elapsed_ns=127167209
ns/op=127167.2
req/s=7864
```

The clean build emitted no FPC `Warning:` lines, but did emit two existing FPC
`Note:` lines from `nextpas.core.text.format` and the translated llhttp inline
call. Those notes are not from the changed benchmark file.

## Direction review

方向没有走偏：本轮把 full-chain server benchmark 从人工输出整理成可测试契约，
没有把 benchmark 结果误当生产优化，也没有引入新的 HTTP runtime behavior。现在
`bench_router`、`bench_h1writer`、`bench_h1outbound` 和 `bench_fullchain` 都有
focused smoke，可以继续做成本归因。

## Remaining gaps / risks

- `bench_fullchain` 仍是单连接 keep-alive row，不覆盖多连接并发、epoll、TLS、H2/H3
  或 backpressure。
- 单次 full-chain row 噪声较大；性能判断仍应优先看 narrowed micro rows 或后续
  multi-run summary。
- 现有依赖的 FPC `Note:` 尚未治理，本轮只如实记录，不扩大范围。
