# Findings: H1 server 1 KiB response benchmark correlation

## Scope

本轮是 benchmark/correlation 强化，不改变 public HTTP API，不改变 wire
contract，不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

三方 server comparator 现在支持同一个 workload selector：

```text
--workload no_url
--workload url_path
--workload adapter_no_url
--workload response_1k
```

`response_1k` 语义：

- request target 仍是 `/`，不触碰 URL path。
- server 写 fixed-length `1024` bytes response body。
- nextPas raw client 按 response header boundary + expected body length 等完整响应。
- Rust std-only comparator 也按 workload expected body length 读取完整响应。
- Go comparator 原本用 `io.Copy`，已经天然读取完整 body。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

19 total, 18 passed, 1 failed
server comparison runner response_1k small smoke failed:
--workload must be no_url, url_path, or adapter_no_url
heaptrc: 0 unfreed memory blocks
```

GREEN:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

19 total, 19 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local `response_1k` row:

```text
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload response_1k

nextPas response_1k: 80184 req/s, 12471 ns/op
Go net/http response_1k: 18392 req/s, 54369 ns/op
Rust std-only response_1k: 90185 req/s, 11088 ns/op
```

Fresh no-url calibration row using the same complete-response reader:

```text
benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload no_url

nextPas no_url: 87726 req/s, 11399 ns/op
Go net/http no_url: 18247 req/s, 54802 ns/op
Rust std-only no_url: 94715 req/s, 10557 ns/op
```

结论：本机 1 KiB response row 没有显示 response writer/drain 是当前相对 Rust 的主要
瓶颈。nextPas 与 Rust std-only comparator 已经很接近，并明显快于 Go comparator。

## Harness correctness note

旧 nextPas `bench_server` client 只等到读到约 50 bytes 就计一次成功，这对 hello-world
row 通常够用，但不适合大响应，也可能让旧 rows 的严格对比口径偏弱。本轮改成寻找
response header boundary，再等待 expected body length，后续 server comparison rows
应以这个完整响应读取逻辑为准。

## Direction review

方向没有走偏：本轮没有继续凭感觉优化 parser，而是先修正 benchmark 证据质量，并把
response writer/drain 成本拆出来。当前证据显示 full-chain remaining gap 更可能来自
request dispatch、handler invocation、response serialization 细节或本机噪声，而不是
单纯的大响应 drain。

## Remaining gaps / risks

- 还没有 multi-run / median snapshot，单次本机 row 仍有调度噪声。
- Rust comparator 仍是 std-only microbaseline，不代表 Hyper/Tokio 生态性能。
- 还缺 request dispatch / handler invocation / response writer serialization 的更窄
  micro/full-chain 对照。
- 如果要优化 translated llhttp，下一步仍应先拿 C/Pascal narrowed benchmark 与硬件计数器。
