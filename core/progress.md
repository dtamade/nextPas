# Progress Log: H1 parser trusted header add

## Session

- **Scope:** parser-trusted header insertion fast path for H1 parser.
- **Status:** complete; path-limited commit prepared for this batch.
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser/header materialization production optimization`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP parser/header
  fast-path 相关文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不跑全量测试；只跑 headers/parser/server/benchmark focused gates 和 `bench_h1parser` sanity。

## Completed work

- RED：`test_http_headers` 新增 `THttpHeaders.AddParsed` canonicalization proof，先因 helper 不存在编译失败。
- GREEN：新增 `THttpHeaders.AddParsed` 与 parser-owned concrete `FHeaderStore`。
- `TH1Parser` header-complete callback 改用 `FHeaderStore.AddParsed`，`GetHeaders` 仍暴露 `IHttpHeaders`。
- `bench_h1parser` header-add breakdown row 切到 parser trusted path。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - failed as expected: `Identifier idents no member "AddParsed"`。
- Focused gates:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - `16 total, 16 passed, 0 failed`; heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`; heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`; heaptrc: `0 unfreed memory blocks`
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `9 total, 9 passed, 0 failed`; heaptrc: `0 unfreed memory blocks`
- Benchmark sanity:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - header add row `866.7 ns/op` vs previous `1220.9 ns/op`
  - full adapter 10 headers `3030.8 ns/op` vs previous `3378.2 ns/op`
  - full adapter POST 1KB `1268.4 ns/op` vs previous `1417.2 ns/op`

## Current conclusion

方向没有走偏：上一批定位出 header materialization 是大头，本轮直接削掉重复 validation/normalization
成本，并用 focused tests + server gate 证明 contract 未回退。

## Commit scope

- Only stage this batch's HTTP parser/header benchmark/docs/control files.
- Planned commit message: `perf(http): add trusted h1 header insertion`.

## Next step

- 下一批继续 H1 parser/header materialization：优先看 `AppendSpan` 的 string allocation/copy，或者让
  server policy checks 更多使用 parser/fast snapshot metadata，减少普通请求读取 full header container。
