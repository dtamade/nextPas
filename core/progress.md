# Progress Log: HTTP full-chain benchmark output contract

## Session

- **Scope:** HTTP full-chain keep-alive benchmark normalized output contract.
- **Status:** focused RED/GREEN completed, `bench_fullchain` plaintext row locked
  by `test_http_benchmarks`, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `request dispatch / response serialization / full-chain cost isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/test/docs/control files。
- 父目录 `../task_plan.md`、`../findings.md`、`../progress.md` 已有无关脏改；
  本轮只更新 `core/task_plan.md`、`core/findings.md`、`core/progress.md`。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 focused
  `bench_fullchain` live row。

## Completed work

- `test_http_benchmarks` 新增 `bench_fullchain plaintext smoke`。
- `bench_fullchain` 新增 `NEXTPAS_BENCH_MAX_ITERS` 和 `NEXTPAS_BENCH_FILTER`
  支持。
- `bench_fullchain` 输出 `operation=http.fullchain.keepalive` marker。
- `bench_fullchain` 新增 normalized row marker：`workload`、`iterations`、
  `completed`、`elapsed_ns`、`ns/op`、`req/s`。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 full-chain benchmark 契约和 fresh live evidence。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 25 passed, 1 failed`，失败原因是旧 `bench_fullchain` 输出缺少
  `operation=http.fullchain.keepalive`，heaptrc `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 26 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `NEXTPAS_BENCH_MAX_ITERS=1000 NEXTPAS_BENCH_FILTER=plaintext make -C benchmarks/nextpas.core.http/bench_fullchain clean run`
  -> `workload=plaintext`, `completed=1000`, `elapsed_ns=127167209`,
  `127167.2 ns/op`, `7864 req/s`。该 clean build 没有 FPC `Warning:`，
  但有 2 条既有 FPC `Note:`，分别来自 `nextpas.core.text.format` 和 llhttp inline。

## Direction review

方向没有走偏：本轮继续把 HTTP server performance 归因从大而粗的 full-chain
comparison 拆成可测试 benchmark 契约，没有改生产 HTTP 逻辑。full-chain row 已经可
被测试锁住，后续可以更高效地对比 narrowed rows 和真实端到端成本。

## Next step

继续 `6/6 benchmark/performance`。下一批建议围绕 H1 writer allocation / header
materialization 做更细拆分，或用已有 comparison runner 做一次小规模 multi-run
sanity；不要先跑全量测试或 broad benchmark sweep。
