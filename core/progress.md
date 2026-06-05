# Progress Log: H1 benchmark row filter and flag matrix

## Session

- **Scope:** H1 benchmark row filtering and flag-matrix runner for Pascal llhttp raw-gap profiling.
- **Status:** complete; path-limited commit prepared for this batch.
- **Roadmap Position:** `6/6 benchmark/performance` -> `Pascal llhttp raw-gap profiling seam`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP benchmark/tooling/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不跑全量测试；只跑 `test_http_benchmarks` focused gate 和 filtered H1/C raw rows。
- 子代理 `Galileo` 已给出只读建议：先补 flag-matrix/profiling seam，不要手改 generated llhttp state machine。

## Completed work

- RED：`test_http_benchmarks` 新增 `NEXTPAS_BENCH_FILTER` smoke，先因 marker 缺失失败。
- GREEN：`TBenchRunner` 与 C llhttp comparator 都支持 `NEXTPAS_BENCH_FILTER`。
- RED：flag-matrix smoke 先因 `run_flag_matrix.sh` 不存在失败。
- GREEN：新增 `run_flag_matrix.sh`，输出 `results.tsv/env.txt/logs/perf` 到 `build/.../flag_matrix`。
- `test_http_benchmarks` 直接锁住 Pascal filter、C filter、flag-matrix smoke。
- `bench_h1parser` raw/no-op helper 缓存 request pointer/length，减少 wrapper 噪声。

## Verification

- Focused gate:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `12 total, 12 passed, 0 failed`; heaptrc: `0 unfreed memory blocks`
- Filtered benchmark sanity:
  - `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - Pascal raw 10 headers `749.7 ns/op`
  - `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='C raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp`
  - C raw 10 headers `523.0 ns/op`
  - `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser clean run EXTRA_FLAGS='-CpCOREAVX2 -CfAVX2'`
  - Pascal raw 10 headers with CPU/FPU flags `759.6 ns/op`

## Current conclusion

方向没有走偏：这批主要提升后续工作效率和证据质量。简单 CPU/FPU target flags 没有缩小 raw gap；
下一步应使用 `run_flag_matrix.sh --perf` 或独立 `perf record` 去看 branch/cache/call 热点。

## Commit scope

- Only stage this batch's HTTP benchmark/tooling/docs/control files.
- Planned commit message: `bench(http): add h1 parser row filter`

## Next step

- 下一批运行 `run_flag_matrix.sh --perf` 或 `perf stat/record`，确认 raw gap 是 branch/goto 状态机、
  cdecl helper/callback trampoline，还是 FPC generated code layout。
- 如果 profile 指向 generated state machine，不直接手改 `nextpas.core.http.impl.h1.llhttp.pas`，
  而应设计 translation/generator seam。
