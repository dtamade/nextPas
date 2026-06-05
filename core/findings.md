# Findings: H1 flag-matrix perf fallback

## Scope

本轮是 benchmark/profiling tooling 修正，不改变 HTTP public API、不改变 wire contract、不写
`docs/nextpas.core.http.inbox.md`。目标是让 `run_flag_matrix.sh --perf` 在当前机器
perf 权限受限时仍可运行 benchmark，并把权限状态写入输出。

## RED evidence

运行：

```sh
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
NEXTPAS_BENCH_MAX_ITERS=2000 \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --smoke --perf
```

失败：

```text
exit=255
perf_event_paranoid setting is 3
Access to performance monitoring and observability operations is limited.
```

这证明 `--perf` 不能作为硬依赖；当前用户权限下无法采集硬件 perf events。

## Implemented change

- `run_flag_matrix.sh` 在请求 `--perf` 时先执行 `perf stat -e cycles -- true` 做权限探测。
- perf 不可用时不调用 `perf stat` 包裹 benchmark，改为直接运行 benchmark。
- `env.txt` 从 `perf_enabled` 改为更精确的：
  - `perf_requested=0/1`
  - `perf_usable=0/1`
- `test_http_benchmarks` 新增 `H1 parser flag matrix perf graceful smoke`，直接锁住 `--perf` 在受限环境下仍退出 0、仍生成 `results.tsv/env.txt`。

## Verification

- Focused gate:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `13 total, 13 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Current perf environment:
  - `/proc/sys/kernel/perf_event_paranoid` -> `3`
- Flag-matrix smoke env after `--perf`:
  - `perf_requested=1`
  - `perf_usable=0`
  - Pascal smoke row present in `results.tsv`
  - C smoke row present in `results.tsv` when `NEXTPAS_LLHTTP_ROOT` is configured

## Current conclusion

方向没有走偏：本轮没有在受限机器上硬追 perf 数据，而是修复 tooling，使后续在可用环境里能采集
perf，同时本机仍可生成 timing matrix。当前无法给出 branch/cache/cycles 结论；这不是代码阻塞，
是系统权限边界。

## Remaining gaps / risks

- 真实 `cycles/instructions/branches/branch-misses/cache-misses` 仍需在 `perf_event_paranoid <= 1`
  或有 `CAP_PERFMON` / `CAP_SYS_PTRACE` / `CAP_SYS_ADMIN` 的环境运行。
- 下一批可增加 `perf_summary.tsv` 解析，但需要先在 perf 可用环境确认 perf output 形态。
- 不要因为当前权限不足转向手改 generated llhttp；raw-gap 仍应先拿到 profile 证据。
