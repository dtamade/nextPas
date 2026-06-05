# Findings: HTTP full-chain benchmark client read correction

## Scope

本轮是 benchmark harness correctness/performance correction，不改变 public HTTP API，
不改变生产 HTTP server/client 代码，不手改 generated llhttp，不写
`docs/nextpas.core.http.inbox.md`。

## Root cause

`bench_fullchain.ReadResponse` 原来用：

```text
AConn.Read(..., 1)
LResp := LResp + Chr(...)
```

逐字节读取 response header 并逐字节拼接 string。这个 row 因此主要测客户端读法和字符串分配，
不是只测 server full-chain。same-turn 对照进一步证明了差距：

- `bench_fullchain plaintext`: `112063.8 ns/op`, `8923 req/s`
- `run_server_comparison --workload no_url`: nextPas `9345 ns/op`, `107002 req/s`

## Implemented decision

`bench_fullchain.ReadResponse` 现在按 chunk 读取可用响应字节，追加到响应缓冲后查找
`CRLFCRLF`，再按 `Content-Length` 读取剩余 body。benchmark 输出新增：

```text
client_read_mode=buffered
```

测试用这个 marker 锁住 harness 不再回退到 byte-at-a-time read。

## RED evidence

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

26 total, 25 passed, 1 failed
bench_fullchain plaintext smoke - fullchain client read mode marker missing
heaptrc: 0 unfreed memory blocks
```

## GREEN / contract evidence

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

26 total, 26 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Before harness correction:

```text
NEXTPAS_BENCH_MAX_ITERS=1000 NEXTPAS_BENCH_FILTER=plaintext \
make -C benchmarks/nextpas.core.http/bench_fullchain clean run

plaintext: 111504.7 ns/op, 8968 req/s
```

RED smoke also captured the same old mode at smaller iteration count:

```text
plaintext: 112063.8 ns/op, 8923 req/s
```

After buffered read:

```text
NEXTPAS_BENCH_MAX_ITERS=1000 NEXTPAS_BENCH_FILTER=plaintext \
make -C benchmarks/nextpas.core.http/bench_fullchain clean run

client_read_mode=buffered
plaintext: 42132.4 ns/op, 23735 req/s
```

Same-turn server comparison:

```text
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload no_url

nextPas: 9345 ns/op, 107002 req/s
Rust std-only: 9576 ns/op, 104418 req/s
Go net/http: 47251 ns/op, 21163 req/s
```

## Direction review

方向没有走偏：本轮没有把 fullchain 低分误判成生产 server 低效，而是先用 narrowed/live
evidence 区分 benchmark harness 和 server path。修正后，fullchain row 可继续作为单连接
同步 ping-pong row；正式对标 Rust/Go 仍应以 multi-client server comparison median 为主。

## Remaining gaps / risks

- `bench_fullchain` 仍使用 string accumulation 查找 header boundary；已足够避免逐字节 read，
  但不是零分配 parser。
- 当前 server comparison 只覆盖 Rust std-only comparator，不代表 Hyper/Tokio。
- 下一批应跑 `--runs 3` 的 multi-workload median snapshot，并按 workload 决定是否继续优化
  adapter path、URL path 或 response_1k path。
