# Progress Log: HTTP router dispatch benchmark contract

## Session

- **Scope:** HTTP router dispatch benchmark output contract.
- **Status:** focused RED/GREEN completed, `bench_router` handler dispatch row
  landed, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `request dispatch / response serialization cost isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 focused
  `bench_router` live row。

## Completed work

- `test_http_benchmarks` 新增 `bench_router handler dispatch smoke`。
- `bench_router` 新增 `operation=http.router.dispatch` marker。
- `bench_router` 新增 `handler dispatch (match + no-op handler)` row。
- `bench_router` 现有 route-match rows 现在会消费 `FindRoute` 结果，避免 FPC unused
  local variable notes 污染 benchmark 输出。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 router dispatch benchmark 契约和 fresh live evidence。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `23 total, 22 passed, 1 failed`，失败原因是 `bench_router` 缺少
  `operation=http.router.dispatch`，heaptrc `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `23 total, 23 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='handler dispatch' make -C benchmarks/nextpas.core.http/bench_router clean run`
  -> `handler dispatch (match + no-op handler): 508.1 ns/op`, `1968021 ops/s`，
  final build output 没有 FPC `Warning:` / `Note:`。

## Direction review

方向没有走偏：本轮沿 `6/6 benchmark/performance` 把 full-chain server gap 拆到
request dispatch 这一层，且没有改生产 HTTP 行为。当前证据显示普通 router dispatch
不是最明显瓶颈，下一步应继续拆 response writer / serialization / outbound drain。

## Next step

继续 `6/6 benchmark/performance`。下一批建议补 response serialization / H1 writer
benchmark 输出契约，或者整理 `bench_fullchain` 为 normalized output 后再用 focused
gate 锁住。
