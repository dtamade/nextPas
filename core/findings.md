# Findings: HTTP adapter_no_url fast-gate optimization

## Scope

本轮是 performance/correctness batch，目标是减少 `adapter_no_url` 的 nextPas 内部
fast-gate 开销。不改变 public HTTP API，不手改 generated llhttp，不写
`docs/nextpas.core.http.inbox.md`。

## Subagent findings

- `adapter_no_url` 最可疑热点不是 llhttp 本身，而是旧 server fast gate 先完整跑
  `FastParseRequest`，因为 `Connection` header 退出，然后又完整跑 llhttp adapter。
- `url_path` 慢于 Rust std-only 的语义不等价更明显：Rust 只做字节前缀匹配，
  nextPas handler 读取 `AReq.Url.Path` 会触发 public `Url` materialization。
- benchmark fairness review 确认 `adapter_no_url` 不是跨语言 apples-to-apples；
  它适合作为 nextPas 内部 `no_url` vs explicit-keep-alive fast-gate 差分。

## RED evidence

Filtered narrowed benchmark before adding rows:

```text
NEXTPAS_BENCH_MAX_ITERS=2000 NEXTPAS_BENCH_FILTER='adapter no-url' \
make -C benchmarks/nextpas.core.http/bench_h1parser clean run

bench_filter=adapter no-url
summary contained no matching adapter no-url rows
```

Focused fast-parser contract RED:

```text
make -C tests/nextpas.core.http/test_http_h1fast clean test

test_http_h1fast.lpr(...): Error: Identifier idents no member "ConnectionKeepAlive"
test_http_h1fast.lpr(...): Error: Identifier idents no member "ConnectionClose"
test_http_h1fast.lpr(...): Error: Identifier idents no member "ConnectionUnsupported"
```

## Implementation

- `TFastParseResult` now carries connection-policy flags:
  `ConnectionKeepAlive`, `ConnectionClose`, `ConnectionUnsupported`.
- `FastParseRequest` treats trimmed exact `keep-alive` as fast-path compatible,
  exact `close` as safe fallback, and `upgrade` / multi-token / unknown values as
  unsupported fallback.
- `TH1ServerConnectionState.TryUseFastRequestParser` now accepts explicit
  HTTP/1.1 `Connection: keep-alive` no-body requests while still rejecting
  `close`, `upgrade`, unsupported tokens, `Expect`, `Transfer-Encoding`, and
  non-zero request bodies.
- Hot fast-parser helper functions were marked `inline`; this was deliberately
  limited to the touched fast parser helpers, not applied broadly.

## Verification

- `NEXTPAS_BENCH_MAX_ITERS=2000 NEXTPAS_BENCH_FILTER='adapter no-url' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  -> metadata `372.2 ns/op`, old fast-reject + llhttp `2084.3 ns/op`,
  llhttp direct `1494.0 ns/op`, fast parse only `629.3 ns/op`.
- `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  -> `22 total, 22 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 26 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- `make -C tests/nextpas.core.http/test_http_server clean test`
  -> `275 total, 275 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload adapter_no_url --runs 3`
  -> nextPas median `11022 ns/op`, `90720 req/s`; all nextPas runs completed `20000/20000`.
- `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload no_url --runs 3`
  -> nextPas median `10948 ns/op`, `91335 req/s`; all nextPas runs completed `20000/20000`.

## Direction review

方向没有走偏：本轮没有继续把 `adapter_no_url` 当跨语言公平排名，而是先缩小到 nextPas
内部 fast-gate tax，并用 RED/GREEN + heaptrc 验证收口。性能改善真实但不夸大：
`adapter_no_url` same-day median 从 `12280 ns/op` 到 `11022 ns/op`，同时 `no_url`
row 仍有 scheduler noise。

## Remaining gaps / risks

- `run_server_comparison.sh` summary 目前仍只解析 `ns/op` / `req/s`，没有强制
  `completed == requests`；下一批应补 harness contract。
- `adapter_no_url` workload name 已带历史含义；当前它更准确地表示 explicit
  keep-alive fast-gate differential，而不是 llhttp adapter-only path。
- `url_path` 下一步需要 path-only URL materialization narrowed proof，不能直接从 Rust
  std-only prefix check 推导 nextPas URL API 性能结论。
