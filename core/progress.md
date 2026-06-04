# Progress Log: HTTP parser header reuse fast path

## Session

- **Scope:** `IHttpHeaders.Clear` public contract + `TH1Parser.Reset` header container reuse。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser adapter allocation reduction`

## Current state

- shared checkout 仍有无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP parser/headers/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 上一批 `a380b760 bench(http): isolate raw llhttp parser cost` 已证明当前应优先优化 adapter materialization。

## Completed work

- `IHttpHeaders` 新增 `Clear`。
- `THttpHeaders.Clear` 清理 visible entries 并保留 container capacity 以便复用。
- `test_http_headers` 增加 `Clear resets and allows reuse` focused contract。
- `TH1Parser.Reset` 从重建 `NewHttpHeaders` 改为 `FHeaders.Clear`。
- `test_http_h1parser` 的 `Reset and reparse` 增强 header guard，确保 Reset 后不串旧 `Host`。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - failure: `Identifier idents no member "Clear"`
- Focused tests:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - `14 total, 14 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - allocation count in this target dropped from previous `1423` blocks to `1404` blocks
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `18 total, 18 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark:
  - baseline: `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - after: `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - confirmation: `make -C benchmarks/nextpas.core.http/bench_h1parser run`
  - adapter confirmation:
    - `simple GET`: `1101.7` -> `641.8 ns/op`
    - `10 headers`: `3808.5` -> `3284.4 ns/op`
    - `POST 1KB body`: `1848.6` -> `1457.6 ns/op`
    - `pipeline 10 reqs`: `11253.6` -> `6201.2 ns/op`

## Current conclusion

本轮方向正确：减少 parser Reset 的 per-request header object allocation，直接投射到 adapter benchmark，
尤其是 repeated parse / pipeline 场景。Reset 后旧 `GetHeaders` 引用不再应被当快照使用；需要快照时
调用方应使用 `Clone`。

## Next step

- 继续 adapter materialization：优先评估 body buffer/span 和 header callback string growth。
- 如果继续改公开 API，仍按 RED -> focused tests -> heaptrc -> benchmark 的节奏推进。
- 正式 Go/Rust parity benchmark 继续后置；当前先把 nextPas 自身热路径成本压下来。
