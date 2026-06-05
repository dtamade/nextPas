# Task Plan: H1 benchmark row filter for raw-gap profiling

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已确认 Pascal translated llhttp raw path 相比 C llhttp 有约 `1.4x-1.5x`
差距。本轮不盲改 generated state machine，而是先补一个可复现、低成本的 benchmark
filter seam，让后续 FPC flag-matrix、C comparator 和 `perf stat/record` 能只跑目标 row。

本轮不改 HTTP public API、不改 wire contract、不写 `docs/nextpas.core.http.inbox.md`。

## Checklist

- [x] 复核设计规范、HTTP coverage/benchmark/control 文件、git status。
- [x] 确认 `bench_h1parser` / C comparator 已有 `EXTRA_FLAGS` / `EXTRA_CFLAGS`，但缺少 row filter。
- [x] 新增 focused RED：`NEXTPAS_BENCH_FILTER=raw llhttp: 10 headers` 应只跑匹配 row 并输出 `bench_filter` marker。
- [x] 实现 Pascal `TBenchRunner` 的 `NEXTPAS_BENCH_FILTER` case-insensitive substring filter。
- [x] 实现 C llhttp comparator 的同名 filter，保持 Pascal/C 对称。
- [x] 新增 `test_http_benchmarks` smoke 覆盖 Pascal benchmark filter 与 C comparator filter。
- [x] 跑 `test_http_benchmarks` focused gate + heaptrc。
- [x] 用 filter 做 raw Pascal/C 10-header sanity capture。
- [x] 用 filter 做 FPC CPU/FPU flag A/B 试探。
- [x] 更新 `docs/http/BENCHMARKS.md` 与 comparator README。
- [x] 更新 `findings.md` / `progress.md`。
- [x] 跑 `git diff --check`。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.bench.pas`
- `benchmarks/nextpas.core.http/bench_h1parser/compare_c/bench_llhttp_c.c`
- `benchmarks/nextpas.core.http/bench_h1parser/compare_c/README.md`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

方向没有走偏：本轮直接回应效率问题，避免后续每次 raw-gap A/B 都跑完整 H1 parser
benchmark。初步 filtered sanity 显示 `-CpCOREAVX2 -CfAVX2` 对 raw llhttp 10-header row
没有可见收益，下一批应进入 `perf stat/record` 或 FPC/codegen 形态分析，而不是继续盲试 flags。

## Intended outcome

- 后续可用 `NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers'` 快速跑 Pascal raw row。
- 后续可用 `NEXTPAS_BENCH_FILTER='C raw llhttp: 10 headers'` 快速跑 C comparator row。
- benchmark smoke 直接锁住 filter marker 和 unrelated row 被跳过，避免回归。
