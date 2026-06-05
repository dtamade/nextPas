# Findings: H1 request metadata cache

## Scope

本轮是 H1 parser/server request metadata 性能切片，不改变 public facade API、不改变 wire
contract、不写 `docs/nextpas.core.http.inbox.md`，也不碰 generated llhttp state machine。

## RED evidence

先在 `test_http_h1parser` 增加 request metadata focused contract：

```text
make -C tests/nextpas.core.http/test_http_h1parser clean test
```

失败点：

```text
Identifier not found "TH1RequestMetadata"
Identifier idents no member "GetRequestMetadata"
```

这证明 parser 当前没有可复用的 request metadata 摘要，server 只能继续 scattered header lookup /
token parse。

## Implemented change

- `nextpas.core.http.impl.h1.parser` 新增内部 `TH1RequestMetadata` record 与
  `IH1Parser.GetRequestMetadata`。
- `TH1Parser` 在 request headers-complete 阶段构建一次 metadata：
  - Host presence
  - Transfer-Encoding presence
  - Content-Length presence/value
  - request declares body
  - Expect `100-continue` / unsupported member
  - Connection close / keep-alive hints
- 原 `ValidateRequestTransferEncoding` 逻辑并入 metadata build，继续保留 unsupported coding
  -> `pekUnsupportedTransferCoding` 和 malformed transfer-coding -> `pekMalformed`。
- `TH1ServerConnectionState` 的 header policy、`100-continue`、dispatch keep-alive / Host
  判断改为读取 parser metadata。
- `TH1FastRequestSnapshot` 提供 accepted fast-path 的常量 metadata，不触发 lazy headers
  materialization。
- `TFastParseResult` 新增 `HasContentLength`，避免 fast snapshot metadata 把 “无
  Content-Length” 误标为 `Content-Length: 0`。
- benchmark 新增同场对比：
  - `adapter cost: request metadata legacy expect+cl`
  - `adapter cost: request metadata cached expect+cl`

## Verification

- H1 fast focused gate:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `22 total, 22 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Parser focused gate:
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `91 total, 91 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Server focused gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark rows:
  - `NEXTPAS_BENCH_FILTER='request metadata' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - legacy repeated scan: `1320.7 ns/op`
  - cached metadata read: `6.1 ns/op`
- Benchmark smoke:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `13 total, 13 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Current conclusion

方向没有走偏：这一批没有盲目手改 Pascal-translated llhttp，也没有扩大到 headers 容器 mutation
invalidation。性能收益来自把 H1 request policy/dispatch 所需 metadata 在 parser 内一次构建，
再由 server 复用。

## Remaining gaps / risks

- `Connection` request-side keep-alive 仍保留旧的精确字符串语义；如果要改成 RFC token /
  case-insensitive 语义，必须作为 correctness 行为修复单独 RED/GREEN。
- 本轮 benchmark 证明 metadata lookup/cache 本身的成本差异；正式 server throughput 对照仍应
  留到 benchmark 总结轮与 Go/Rust/Hyper 对照一起做。
- Pascal raw llhttp vs C llhttp 的 `1.4x-1.5x` gap 仍未关闭；需要 perf 可用环境里的
  cycles/branch/cache 证据后再判断是否动生成翻译策略。
