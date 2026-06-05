# Task Plan: H1 flag-matrix perf fallback

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已补 `NEXTPAS_BENCH_FILTER` 与 flag-matrix runner。本轮验证 `--perf` 路径，
发现当前系统 `perf_event_paranoid=3` 会拒绝普通用户 perf events，因此先补 graceful
fallback：请求 perf 时先探测权限，不能用时仍跑 benchmark，并在 `env.txt` 记录
`perf_requested=1` / `perf_usable=0`。

本轮不改 HTTP public API、不改 wire contract、不写 `docs/nextpas.core.http.inbox.md`。

## Checklist

- [x] 复核控制文件、HTTP benchmark docs、git status。
- [x] 运行 `run_flag_matrix.sh --smoke --perf`，确认当前环境 perf 受限。
- [x] 实现 perf usability preflight，避免 `perf stat` 权限失败中断 benchmark。
- [x] 更新 `env.txt` marker：`perf_requested` / `perf_usable`。
- [x] 新增 `test_http_benchmarks` perf graceful smoke。
- [x] 跑 `test_http_benchmarks` focused gate + heaptrc。
- [x] 更新 docs/control 证据。
- [x] 跑 `git diff --check`。
- [ ] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `benchmarks/nextpas.core.http/bench_h1parser/compare_c/README.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

当前机器的 `perf_event_paranoid=3`，不能直接采集 cycles/branches/cache-misses。
脚本必须把 perf 作为可选增强，而不是 benchmark smoke 的硬依赖。下一步若要得到真实
branch/cache 指标，需要在允许 perf 的环境运行，或调整系统权限。

## Intended outcome

- `run_flag_matrix.sh --perf` 在 perf 不可用时仍输出 `results.tsv/env.txt`。
- `test_http_benchmarks` 直接锁住 perf graceful fallback。
- 文档明确当前环境边界和下一步可执行命令。
