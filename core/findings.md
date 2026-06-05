# Findings: HTTP H1 writer serialization benchmark contract

## Scope

本轮是 benchmark/tooling 强化，不改变 public HTTP API，不改变 wire contract，
不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

新增 `bench_h1writer`，输出稳定 marker：

```text
operation=http.h1writer.serialize
```

并新增 row：

```text
fixed 200 13B
```

这个 row 每次迭代创建一个 `TH1ResponseWriter`，设置 `content-type` 与
`content-length=13`，写出固定 `200 OK` header 和 `Hello, World!` body 到固定容量
内存 writer。它刻意不包含 request parsing、router dispatch、middleware、socket drain
或 backpressure。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

24 total, 23 passed, 1 failed
bench_h1writer response serialization smoke failed:
unable to resolve core root from current directory or executable path
heaptrc: 0 unfreed memory blocks
```

GREEN:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

24 total, 24 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local H1 writer serialization row:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='fixed 200 13B' \
make -C benchmarks/nextpas.core.http/bench_h1writer clean run

fixed 200 13B: 1441.1 ns/op, 693895 ops/s
```

The final `bench_h1writer` build emitted no FPC `Warning:` or `Note:` lines.

## Direction review

方向没有走偏：本轮沿上一批 router dispatch 继续拆 server full-chain 成本，没有改
生产 HTTP 行为。当前证据显示固定小响应的 writer construction + header serialization +
body copy 约 `1.44 us/op`，明显高于上一批静态 router dispatch `0.51 us/op`，后续更应
看 writer allocation/header materialization/outbound drain，而不是先回到泛化 full-chain row。

## Remaining gaps / risks

- 当前 writer row 不覆盖 chunked response、large body、informational response、HEAD
  suppress-body 或 socket drain/backpressure。
- `bench_fullchain` 仍是旧式非 normalized output，暂时不适合作为机器断言入口。
- Rust comparator 仍是 std-only comparator，不代表 Hyper/Tokio。
