# Progress Log: H1 fast parser policy flags

## Session

- **Scope:** H1 fast parser policy flags and server fast-path lookup trim.
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 server fast path`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP
  fast parser/server fast-path/test/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `docs/http/API_COVERAGE.md`：没有 public facade API 变化。
- 本轮不跑全量测试；只跑 fast parser/server focused gates 和局部 benchmark sanity。

## Completed work

- 新增 `test_http_h1fast` policy flags focused test。
- 观察 RED：`TFastParseResult` 缺少 `HasHost` / `HasConnection` / `HasExpect` /
  `HasTransferEncoding` 字段。
- `TFastParseResult` 现在暴露这些 scan-time policy flags。
- `FastParseRequest` 在 header scan 中直接设置 policy flags。
- `TryUseFastRequestParser` 改用 flags 判断是否可走 server fast path，删除 4 次
  `Headers.Get(...)` lookup。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - failed as expected with missing `HasHost` / `HasConnection` / `HasExpect` /
    `HasTransferEncoding` fields.
- Focused fast parser gate:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `20 total, 20 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Focused server gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark sanity:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - fast rows: simple GET `757.2 ns/op`, 10 headers `3554.1 ns/op`, POST 1KB `1394.2 ns/op`, pipeline `7821.6 ns/op`
  - `make -C benchmarks/nextpas.core.http/bench_server clean run`: `96699 req/s`
  - immediate second `bench_http_server --requests 20000 --threads 4`: `86312 req/s`

## Current conclusion

方向没有走偏：本轮继续削 server hot-path 上确定存在的重复 header lookup。语义由
fast parser与 server focused gates 锁住，heaptrc 无泄漏。server benchmark 仍有噪声，
不把本轮写成稳定 full-chain 吞吐提升。

## Remaining work before commit

- 更新 `docs/http/BENCHMARKS.md`。
- 跑 `git diff --check`。
- path-limited commit。

## Next step

- 下一批进入 lazy headers / policy snapshot：普通 fast-path request 的 handler 如果不读
  headers，应避免 eager 构造完整 `IHttpHeaders`。这是当前最直接的更大收益点。
