# Findings: HTTP server comparison multi-run evidence tightening

## Scope

本轮是 benchmark/tooling 强化，不改变 public HTTP API，不改变 wire contract，
不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

`run_server_comparison.sh` 现在支持：

```text
--runs N
```

multi-run 语义：

- nextPas / Go / Rust 各自只 build 一次。
- 每轮输出 `run=N`，保留原始三方 benchmark output。
- 末尾输出 `summary=http.server.keepalive`。
- 每个 impl 输出 `summary_impl=... runs=N median_ns/op=... median_req/s=...`。

`capture_server_comparison_snapshot.sh` 也支持同一 `--runs N`，并在 Markdown snapshot
中记录 `runs=`、完整命令和 raw summary rows。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

21 total, 20 passed, 1 failed
server comparison runner runs summary smoke failed:
unknown argument: --runs
heaptrc: 0 unfreed memory blocks
```

GREEN:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

22 total, 22 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local `no_url` full-chain summary:

```text
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload no_url --runs 3

nextPas median: 11431 ns/op, 87476 req/s
Go net/http median: 55017 ns/op, 18176 req/s
Rust std-only median: 9885 ns/op, 101153 req/s
```

Representative per-run rows:

```text
nextPas no_url: 11388 / 12818 / 11431 ns/op
Go net/http no_url: 54598 / 55017 / 55111 ns/op
Rust std-only no_url: 10407 / 9885 / 9741 ns/op
```

结论：full-chain no-URL row 现在有了中位数口径。nextPas 在本机继续明显快于
Go `net/http`，并落后 Rust std-only comparator 约 `1.16x`（按 `ns/op` median）。
这说明下一步不应只盯单次 server row，而应拆 request dispatch / response serialization
或补更真实的 async Rust comparator。

## Tooling bug note

初版 runner summary 解析时错误假设 `impl=` 与 `ns/op=` 在同一行。focused gate
暴露出旧单次 smoke 也会失败。修正后改为先确认 `impl=` marker，再从同一 impl 输出块
分别读取 `ns/op=` 与 `req/s=`。

## Direction review

方向没有走偏：这轮把 full-chain server comparison 的噪声问题直接收口到工具层，
减少后续优化误判。没有改生产 HTTP server 行为，也没有把 benchmark-only 工具误包装成
API 变更。

## Remaining gaps / risks

- Rust comparator 仍是 std-only comparator，不代表 Hyper/Tokio。
- 还缺 request dispatch / handler invocation / response serialization 的更窄对照。
- local scheduler noise 仍存在，但 multi-run median 已经比单次 row 更稳。
