# Progress Log: HTTP H1 writer header-line coalescing

## Session

- **Scope:** H1 writer header-line coalescing micro-optimization.
- **Status:** stack-buffer production fast path landed locally, focused gates passed, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `response serialization cost isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP writer/tests/docs/control files。
- 父目录 `../task_plan.md`、`../findings.md`、`../progress.md` 已有无关脏改；
  本轮只更新 `core/task_plan.md`、`core/findings.md`、`core/progress.md`。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_h1writer`、`test_http_benchmarks`
  和两条 focused `bench_h1writer` live rows。

## Completed work

- `test_http_h1writer` 新增 focused RED：验证两个 header line 的 exact wire bytes
  不变，并要求 full-progress writer 下 status line、每个 header line、final CRLF
  分别为单次 write。
- `TH1ResponseWriter.WriteAllHeaders` 新增常见 header line stack-buffer coalescing；
  长 header line fallback 到 heap string。
- 简单字符串拼接版和 heap `SetLength + Move` 版都被 live rows 证明不够好，未保留。
- `docs/http/API_COVERAGE.md` 与 `docs/http/BENCHMARKS.md` 已同步生产优化和 fresh
  local evidence。

## Verification

- RED:
  `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  -> `30 total, 29 passed, 1 failed`，失败为 `expected 4, got 10`，heaptrc
  `0 unfreed memory blocks`。
- Writer gate after kept implementation:
  `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  -> `30 total, 30 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Benchmark gate:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `26 total, 26 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='headers only 200' make -C benchmarks/nextpas.core.http/bench_h1writer clean run`
  -> `headers only 200: 1247.1 ns/op`, `801852 ops/s`。
- Fresh comparison row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='fixed 200 13B' make -C benchmarks/nextpas.core.http/bench_h1writer run`
  -> `fixed 200 13B: 1250.5 ns/op`, `799680 ops/s`。

## Direction review

方向没有走偏：本轮先 RED，再实现；发现拼接版退化后及时止损，最终保留有 contract proof
和 narrowed benchmark proof 的栈缓冲版本。当前收益只声明在 H1 writer narrowed rows，不把
它包装成 server full-chain 结论。

## Next step

继续 `6/6 benchmark/performance`。下一步不要继续盲目拆细 header writer；建议先用
full-chain / narrowed profiler 重新定位瓶颈，再决定是否做 header block 更大粒度合并、
outbound buffer seam 调整，或回到 server/session 调度成本。
