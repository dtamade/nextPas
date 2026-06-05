# Progress Log: H1 fast parser lazy headers

## Session

- **Scope:** H1 fast parser lazy headers and server fast snapshot materialization trim.
- **Status:** verified, ready for path-limited commit.
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser/server fast path`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP fast
  parser/server/test/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `docs/http/API_COVERAGE.md`：没有 public facade API 变化。
- 本轮不跑全量测试；只跑 fast parser/server focused gates 和局部 benchmark sanity。

## Completed work

- 子代理只读审查 Pascal translated llhttp 性能疑点，结论是 raw gap 真实但当前不宜手改大状态机。
- 本地复跑 Pascal / C llhttp comparator，确认 C raw 在代表性行约 `1.4x-1.6x` 快。
- 新增 `test_http_h1fast` invalid header name/value fallback RED。
- `FastParseRequest` 改为 scan-time header validation + lazy `IHttpHeaders`。
- server fast snapshot 路径避免通过 `GetHeaders` 做 policy/keep-alive/Host 判断，从而避免普通
  no-header-access handler 强制物化 headers。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - failed as expected on invalid header name/value fallback.
- Focused fast parser gate:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `22 total, 22 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Focused server gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark sanity:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - fast rows: simple GET `349.9 ns/op`, 10 headers `1351.5 ns/op`,
    POST 1KB `628.9 ns/op`, pipeline `3526.5 ns/op`
  - `make -C benchmarks/nextpas.core.http/bench_server clean run`: `87356 req/s`

## Current conclusion

方向没有走偏：针对性能追 Go/Rust 的目标，本轮优先优化更确定、更安全的
adapter/materialization 成本，而不是贸然手改 Pascal llhttp 大状态机。fast parser microbench
收益明确；server full-chain 仍有噪声，不能夸大。

## Remaining work before commit

- 确认只 stage 本轮 HTTP/core 控制文件。
- path-limited commit。

## Next step

- 下一批优先修 benchmark 可信度：提高/参数化 `TBenchRunner` 与 C comparator 的 `MAX_ITERS`，
  让 sub-microsecond parser rows 达到更稳定采样。
- 然后继续 adapter materialization：评估 fast path raw header block 是否还能避免一次复制，或在
  llhttp adapter 侧减少 request metadata/header string materialization。
