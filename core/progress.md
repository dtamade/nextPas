# Progress Log: H1 parser callback-cost diagnostics

## Session

- **Scope:** `bench_h1parser` raw pipeline + no-op callback diagnostic rows。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser bottleneck attribution`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP benchmark/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `API_COVERAGE.md`：没有 public API 变化。

## Completed work

- `bench_h1parser` 新增 `raw llhttp: pipeline pause-only (10 reqs)`。
- `bench_h1parser` 新增 no-op callback section：
  simple GET / 10 headers / POST 1KB / pipeline。
- no-op callbacks 只计数，不做 URL/header/body materialization，用于拆分 callback dispatch 和 adapter 成本。
- paused pipeline loop 已抽成 helper，避免 benchmark 代码重复。

## Verification

- Benchmark:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - confirmation rows:
    - `raw llhttp: 10 headers`: `823.7 ns/op`
    - `noop cb: 10 headers`: `806.1 ns/op`
    - `llhttp adapter: 10 headers`: `3380.4 ns/op`
    - `raw llhttp: POST 1KB body`: `489.4 ns/op`
    - `noop cb: POST 1KB body`: `454.1 ns/op`
    - `llhttp adapter: POST 1KB body`: `1401.3 ns/op`
    - `raw llhttp: pipeline pause-only`: `2170.1 ns/op`
    - `noop cb: pipeline`: `2163.7 ns/op`
    - `llhttp adapter: pipeline`: `6205.7 ns/op`

## Current conclusion

本轮方向没有走偏：新诊断 rows 支持继续优化 adapter materialization，而不是先重写 Pascal translated
llhttp。严格的 C llhttp parity 仍需 comparator，但当前 nextPas stack 内的最高收益点仍是 header/body/string/
metadata materialization。

## Next step

- 下一批优先做 `THttpHeaders.Add` normalize/validate 热点拆分，或 parser/server request metadata cache。
- 若要进一步回答翻译本体问题，补 C llhttp raw/no-op comparator；否则继续压已知 adapter 成本。
