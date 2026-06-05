# Findings: HTTP router dispatch benchmark contract

## Scope

本轮是 benchmark/tooling 强化，不改变 public HTTP API，不改变 wire contract，
不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

`bench_router` 现在输出稳定 marker：

```text
operation=http.router.dispatch
```

并新增 row：

```text
handler dispatch (match + no-op handler)
```

这个 row 复用一个 `NewGetRequest('/health')`，通过 `THttpRouter.ServeHTTP`
执行静态 route match 与 no-op handler invocation。它刻意不包含 socket I/O、
H1 parser、response writer serialization、middleware 或 URL/query materialization。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

23 total, 22 passed, 1 failed
bench_router handler dispatch smoke failed:
router dispatch operation marker missing from output: operation=http.router.dispatch
heaptrc: 0 unfreed memory blocks
```

GREEN:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

23 total, 23 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local router dispatch row:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='handler dispatch' \
make -C benchmarks/nextpas.core.http/bench_router clean run

handler dispatch (match + no-op handler): 508.1 ns/op, 1968021 ops/s
```

The final `bench_router` build emitted no FPC `Warning:` or `Note:` lines.

## Direction review

方向没有走偏：上一轮 full-chain server comparison 显示 nextPas 与 Rust std-only
差距约 `1.16x`，这轮没有继续堆 full-chain single row，而是开始拆窄成本。当前
router dispatch row 说明普通静态 route + no-op handler invocation 是亚微秒级成本，
后续更应继续拆 response serialization / outbound buffer / socket drain，而不是凭
full-chain row 盲猜。

## Remaining gaps / risks

- 当前 dispatch row 不覆盖 middleware chain、param extraction、query materialization 或
  response writer serialization。
- `bench_fullchain` 仍是旧式非 normalized output，暂时不适合作为机器断言入口。
- Rust comparator 仍是 std-only comparator，不代表 Hyper/Tokio。
