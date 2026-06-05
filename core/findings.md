# Findings: H1 parser direct header span insertion

## Scope

本轮是 H1 parser/header materialization 窄优化：新增 concrete
`THttpHeaders.AddParsedSpans`，让 `TH1Parser` 在同一 `Execute` 内完整收到
header field/value 的常见路径直接从 llhttp callback span 插入 parser-owned header
store。它不改变 `IHttpHeaders` interface、不改变 HTTP facade、不改变 wire contract。

## RED evidence

新增 focused test 后先跑：

```sh
make -C tests/nextpas.core.http/test_http_headers clean test
```

失败点：

```text
test_http_headers.lpr(290,10) Error: Identifier idents no member "AddParsedSpans"
test_http_headers.lpr(292,10) Error: Identifier idents no member "AddParsedSpans"
test_http_headers.lpr(294,10) Error: Identifier idents no member "AddParsedSpans"
```

这证明新增 parser-trusted span helper 尚不存在。

## Implemented change

- `THttpHeaders.AddParsedSpans`：用于 parser-validated spans，直接构造 canonical lowercase name，并拷贝 value span。
- `TH1Parser` 新增 current header span capture：common unsplit callback path 暂存指针/长度，`on_header_value_complete` 直接调用 `AddParsedSpans`。
- split 或跨 buffer header callback 在 `Execute` 返回前会物化到 `FCurrentField/FCurrentValue`，继续走原 `AddParsed` fallback，避免 callback buffer 生命周期风险。
- trailer fields 仍不污染普通 headers，late trailer byte accounting 保持不变。
- `bench_h1parser` 新增 `adapter cost: header span add 10 headers` row，用于解释 direct-span helper 的最终 string copy 成本。

## Verification

- Headers RED:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - failed as expected: `Identifier idents no member "AddParsedSpans"`
- Headers focused GREEN:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - `17 total, 17 passed, 0 failed`
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

Pascal parser/adapter:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser clean run
```

Evidence:

- `bench_max_iters=100000`
- raw translated llhttp 10 headers: `785.4 ns/op`
- raw translated llhttp POST 1KB: `431.7 ns/op`
- raw translated llhttp pipeline: `2104.6 ns/op`
- adapter span append 10 headers: `787.0 ns/op`
- adapter header add 10 headers: `752.9 ns/op`
- adapter header span add 10 headers: `1293.0 ns/op`
- full llhttp adapter 10 headers: `2808.4 ns/op`
- full llhttp adapter POST 1KB: `1199.0 ns/op`
- full llhttp adapter pipeline 10 reqs: `5553.6 ns/op`

C llhttp comparator:

```sh
make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run \
  LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp
```

Evidence:

- `bench_max_iters=100000`
- C raw llhttp 10 headers: `532.2 ns/op`
- C raw llhttp POST 1KB: `275.3 ns/op`
- C raw llhttp pipeline: `1464.6 ns/op`
- C no-op callback 10 headers: `548.7 ns/op`
- C no-op callback POST 1KB: `280.3 ns/op`
- C no-op callback pipeline: `1431.4 ns/op`

## Current conclusion

用户怀疑成立一半：Pascal translated llhttp raw path 确实落后 C llhttp，代表性行大约
`1.4x-1.5x`。但它不是当前最大头；full adapter 10-header path 仍是 raw Pascal 状态机的
约 `3.6x`。本轮 direct span insertion 让 full adapter 10 headers 从上一批的
`3030.8 ns/op` 降到 `2808.4 ns/op`，POST 1KB 从 `1268.4 ns/op` 降到 `1199.0 ns/op`。

`adapter cost: header span add` 单独看比 `AddParsed(string)` 慢，是因为该 row 把最终
name/value string copy 计入 helper；parser full path 仍受益，因为它消除了中间
`FCurrentField/FCurrentValue` string allocation/copy。

## Remaining gaps / risks

- `AddParsedSpans` 是 trusted helper，调用方必须只用于 parser-validated spans；外部输入仍必须走 public `Add`/`Set_` validation。
- Direct span path 只在同一 `Execute` 内完成 header 时使用；split/cross-buffer 回退是安全前提，不能去掉。
- Pascal translated llhttp raw gap 应进入下一批 FPC/profile/codegen 专项，不应手改巨大 generated state machine。
- 下一批更高收益方向：减少 URL/header lookup materialization 或给 server request metadata 做更强 lazy/cache。
