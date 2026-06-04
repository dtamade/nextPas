# Progress Log: HTTP header lookup exact fast path

## Session

- **Scope:** `THttpHeaders.Get/Has` lowercase exact-match fast path + lookup benchmark evidence。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `server ingress/header lookup reduction`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮只 path-limited 处理 HTTP 相关文件。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `../findings.md`
  - `../progress.md`
  - `../task_plan.md`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- `test_http_headers` 增加 uppercase `Has` 语义护栏，确保 public case-insensitive lookup 不回退。
- `bench_headers` 增加 `Get hit uppercase (5 headers, last)`，用于记录 fallback tradeoff。
- `THttpHeaders.FindFirst` 现在先扫描 exact key；只有 exact 未命中且查询名包含大写时才
  normalize 后重扫。

## Verification

- Behavior guard:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - `13 total, 13 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Direct parser/fast gates:
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `18 total, 18 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark evidence:
  - baseline: `make -C benchmarks/nextpas.core.http/bench_headers clean run`
  - after: `make -C benchmarks/nextpas.core.http/bench_headers clean run`
  - confirmation: `make -C benchmarks/nextpas.core.http/bench_headers run`
  - before / confirmation-after:
    - `Set+Get 5 headers`: `1404.5` -> `928.0 ns/op`
    - `Set+Get 15 headers`: `3420.0` -> `2665.6 ns/op`
    - `Add 15 headers`: `2064.0` -> `1775.8 ns/op`
    - `Get miss (3 headers)`: `58.8` -> `55.6 ns/op`
    - `Get hit (5 headers, last)`: `68.6` -> `46.6 ns/op`
    - `Get hit uppercase (5 headers, last)`: `122.8` -> `149.7 ns/op`
    - `Has (3 headers)`: `53.3` -> `25.1 ns/op`
    - `Clone 10 headers`: `752.3` -> `723.9 ns/op`

## Next step

- 继续减少 server ingress 重复 header work：优先考虑 request metadata cache 或 `GetAll`/Expect
  parsing 的 targeted optimization。
- 如果要继续扩 benchmark，下一步应把 header lookup 变化投射到 `bench_h1parser` 或 server
  comparison，而不是只看 header microbench。
