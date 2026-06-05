# Findings: H1 parser trusted header add

## Scope

本轮是窄生产优化：新增 concrete `THttpHeaders.AddParsed`，让 `TH1Parser` 对 llhttp 已验证的
header 走 parser-trusted insertion path。它不改变 `IHttpHeaders` interface、不改变 HTTP facade、
不改变 wire contract。

## RED evidence

新增 focused test 后先跑：

```sh
make -C tests/nextpas.core.http/test_http_headers clean test
```

失败点：

```text
test_http_headers.lpr(...): Error: Identifier idents no member "AddParsed"
```

这证明新增 parser-trusted concrete helper 尚不存在。

## Implemented change

- `THttpHeaders.AddParsed`：用于 parser-validated header，保持 duplicate entries，存储 canonical lowercase name。
- `THttpHeaders.NormalizeParsedName`：single-pass lowercase，避免 public `Add` 的 validation + normalization 双路径成本。
- `TH1Parser` 现在持有 parser-owned concrete `FHeaderStore: THttpHeaders`，`GetHeaders` 仍返回 `IHttpHeaders`。
- header callback complete 时用 `FHeaderStore.AddParsed`；trailer fields 仍不污染普通 headers。
- `bench_h1parser` 的 `adapter cost: header add 10 headers` row 改为测 parser trusted header-add path。

## Verification

- Headers focused gate:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - `16 total, 16 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- H1 parser focused gate:
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Server focused gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark smoke:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `9 total, 9 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Benchmark sanity

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

Evidence:

- `bench_max_iters=100000`
- adapter header add 10 headers: `866.7 ns/op` vs previous `1220.9 ns/op`
- full llhttp adapter 10 headers: `3030.8 ns/op` vs previous `3378.2 ns/op`
- full llhttp adapter POST 1KB: `1268.4 ns/op` vs previous `1417.2 ns/op`
- full llhttp adapter pipeline 10 reqs: `6007.6 ns/op` vs previous `6254.6 ns/op`
- body copy remains tiny: `31.5 ns/op`

## Current conclusion

方向没有走偏：本轮优化命中上一批证据指出的 header materialization 大头，并保持 parser/server
contract 绿色。Pascal translated llhttp raw gap 仍保留为后续 profile/codegen 专项；下一批最优方向
继续减少 header string span append 或把普通 server fast path 的 header access 进一步 lazy 化。

## Remaining gaps / risks

- `AddParsed` 是 trusted helper，调用方必须只用于 parser-validated header；public `Add`/`Set_`
  仍负责外部输入 validation。
- `AppendSpan` string materialization 仍约 `787.7 ns/op`，是下一批更大的剩余 adapter 成本。
- 本轮 benchmark 是本机 microbench，不声明永久 server throughput 排名。
