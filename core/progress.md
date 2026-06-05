# Progress Log: H1 fast parser Content-Length hot-path trim

## Session

- **Scope:** H1 fast parser `Content-Length` duplicate lookup removal.
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 fast parser hot path`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP
  fast parser、focused test、benchmark docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `docs/http/API_COVERAGE.md`：没有 public API 变化。
- 本轮不跑全量测试；只跑 fast parser / server focused gates 和相关 microbench。

## Completed work

- 复核当前 `bench_h1parser`，确认 standalone fast parser rows 已落后于 adapter rows。
- 做过不提交实验：server 禁用 fast path 后 `bench_server` 从 `86066 req/s`
  降到 `82888 req/s`，因此撤销该方向。
- 新增 invalid `Content-Length` fast fallback focused test。
- `FastParseRequest` 现在在 header scan 中直接 parse/cache `Content-Length`，不再
  scan 后调用 `Headers.Get('Content-Length')`。
- 保持 duplicate `Content-Length`、invalid `Content-Length`、incomplete body 均 fallback。

## Verification

- Focused fast parser gate:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `19 total, 19 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Parser benchmark:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - before -> after fast rows:
    - simple GET: `856.4 -> 754.9 ns/op`
    - 10 headers: `3679.0 -> 3429.8 ns/op`
    - POST 1KB: `1500.2 -> 1374.2 ns/op`
    - pipeline: `8685.5 -> 7581.2 ns/op`
- Server benchmark sanity:
  - baseline before experiment: `86066 req/s`
  - disabled fast path experiment: `82888 req/s`
  - after optimized fast parser, immediate clean/second runs: `74197 req/s` / `85182 req/s`
  - conclusion: server rows are noisy; no server throughput claim this batch.
- Focused server gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Current conclusion

方向没有走偏：没有把 “fast path 慢” 粗暴处理成禁用，而是用 benchmark 证明禁用 server
fast path 不是净收益，然后删除 fast parser 内部确定存在的重复 lookup。parser rows
改善明确，server full-chain 仍需要更强 runner 与更大结构优化来证明。

## Remaining work before commit

- 更新 `docs/http/BENCHMARKS.md`。
- 跑 `git diff --check`。
- path-limited commit。

## Next step

- 下一批应进入 lazy header snapshot / server policy flags / adapter materialization 三者之一。
  最高收益候选是 fast parser lazy headers：普通 handler 不读 headers 时不 eager 构造完整
  `IHttpHeaders`，这会直接攻击当前 fast path 最大成本。
