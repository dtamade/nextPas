# Findings: HTTP H1 outbound drain benchmark contract

## Scope

本轮是 benchmark/tooling 强化，不改变 public HTTP API，不改变 wire contract，
不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

新增 `bench_h1outbound`，输出稳定 marker：

```text
operation=http.h1outbound.drain
```

并新增 row：

```text
buffer write+drain 1KB
```

这个 row 每次迭代创建一个 `IH1OutboundBuffer`，写入固定 1 KiB payload，然后
`DrainAllTo` 固定容量内存 writer。它刻意不包含 response writer serialization、
真实 socket I/O、readiness wake、write deadline 或 backpressure。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

25 total, 24 passed, 1 failed
bench_h1outbound drain smoke failed:
unable to resolve core root from current directory or executable path
heaptrc: 0 unfreed memory blocks
```

GREEN:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

25 total, 25 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local H1 outbound drain row:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='buffer write+drain 1KB' \
make -C benchmarks/nextpas.core.http/bench_h1outbound clean run

buffer write+drain 1KB: 303.0 ns/op, 3300665 ops/s
```

The final `bench_h1outbound` build emitted no FPC `Warning:` or `Note:` lines.

## Direction review

方向没有走偏：本轮沿上一批 H1 writer serialization 继续拆 response-side 成本，没有改
生产 HTTP 行为。当前证据显示 internal outbound buffer 1 KiB write+drain 约
`303 ns/op`，明显低于固定小响应 writer row `1441.1 ns/op`，所以后续生产优化前更应
继续拆 writer allocation/header materialization，而不是先优化 outbound buffer。

## Remaining gaps / risks

- 当前 outbound row 不覆盖 `TryDrainTo` runtime path、real socket、partial writes、
  write deadline 或 backpressure。
- `bench_fullchain` 仍是旧式非 normalized output，暂时不适合作为机器断言入口。
- Rust comparator 仍是 std-only comparator，不代表 Hyper/Tokio。
