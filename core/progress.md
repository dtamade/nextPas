# Progress Log: HTTP llhttp raw translation performance triage

## Session

- **Scope:** `bench_h1parser` raw translated llhttp no-callback split + bottleneck classification。
- **Status:** in verification
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser/server ingress bottleneck isolation`

## Current state

- 上一批 `GetAll` miss allocation 优化已提交：
  - `2ee8e216 perf(http): avoid GetAll miss allocation`
- shared checkout 仍有无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP benchmark/docs/control 文件。
- 本轮没有改生产 parser/server 逻辑。

## Completed work

- `bench_h1parser` 新增 raw translated llhttp no-callback benchmark rows：
  - simple GET
  - 10 headers
  - POST 1KB body
- 对比 raw translated llhttp、`IH1Parser` adapter 和 fast path 三层成本。

## Verification

- Benchmark:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - raw translated llhttp:
    - `simple GET`: `425.3 ns/op`
    - `10 headers`: `822.1 ns/op`
    - `POST 1KB body`: `456.2 ns/op`
  - `IH1Parser` adapter:
    - `simple GET`: `1138.6 ns/op`
    - `10 headers`: `3813.1 ns/op`
    - `POST 1KB body`: `1853.6 ns/op`
    - `pipeline 10 reqs`: `9924.9 ns/op`
  - fast path:
    - `simple GET`: `843.0 ns/op`
    - `10 headers`: `3467.6 ns/op`
    - `POST 1KB body`: `1474.5 ns/op`
    - `pipeline 10 reqs`: `8464.3 ns/op`
- Correctness/leak guard:
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Current conclusion

本轮证据显示 raw translated llhttp 状态机不是当前主要瓶颈；adapter 完整解析成本约为 raw
状态机的 `2.68x` 到 `4.64x`。下一批更高收益应优先减少 adapter materialization / per-request
allocation，而不是先重写 llhttp Pascal 翻译。

## Next step

- 优先做 `IH1Parser.Reset` / `IHttpHeaders` reuse 方向的 RED/benchmark proof。
- 如果需要改公开 headers API（例如 `Clear` / capacity reuse），必须先补 focused unit tests 和 heaptrc。
- 正式 benchmark 轮再补 C llhttp / Go / Rust 更完整对照；当前先继续 correctness-safe 的 adapter 降本。
