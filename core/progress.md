# Progress Log: H1 flag-matrix perf fallback

## Session

- **Scope:** graceful fallback for H1 flag-matrix `--perf` mode.
- **Status:** complete; path-limited commit prepared for this batch.
- **Roadmap Position:** `6/6 benchmark/performance` -> `Pascal llhttp raw-gap perf evidence`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP benchmark/tooling/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不跑全量测试；只跑 `test_http_benchmarks` focused gate 和 `run_flag_matrix.sh --smoke --perf`。

## Completed work

- RED：`run_flag_matrix.sh --smoke --perf` 在当前系统因 `perf_event_paranoid=3` 退出 `255`。
- GREEN：脚本新增 perf preflight，无法使用 perf 时仍直接运行 benchmark。
- `env.txt` 改为记录 `perf_requested` 与 `perf_usable`。
- `test_http_benchmarks` 增加 perf graceful smoke，证明 `--perf` 不再因权限不足中断。

## Verification

- Focused gate:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `13 total, 13 passed, 0 failed`; heaptrc: `0 unfreed memory blocks`
- Current system:
  - `/proc/sys/kernel/perf_event_paranoid` = `3`
- Flag-matrix smoke output after `--perf`:
  - `perf_requested=1`
  - `perf_usable=0`
  - `results.tsv` includes `pascal-default` and configured `c-default` rows.

## Current conclusion

方向没有走偏：本轮把 profiling 工具从“perf 权限可用才工作”改成“perf 可选增强”。这让 CI/普通开发机能继续跑 benchmark smoke，同时保留在专用机器上采集 perf 指标的路径。

## Commit scope

- Only stage this batch's HTTP benchmark/tooling/docs/control files.
- Planned commit message: `bench(http): tolerate unavailable perf events`

## Next step

- 在允许 perf 的环境运行：
  - `LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --perf`
- 如果获得 perf files，再补 `perf_summary.tsv` 解析，比较 Pascal/C 的 cycles/instructions/branch-miss/cache-miss。
