# Task Plan: HTTP benchmark runner max iterations

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批确认 Pascal translated llhttp 相比 C llhttp 有 raw gap，但旧 benchmark runner
只有 `MAX_ITERS = 1000`，短路径数据容易被计时噪声放大。本轮先修 benchmark 证据质量：
Pascal `TBenchRunner` 与 C llhttp comparator 使用同一个可配置 max-iterations 约定。

本轮不改公开 HTTP facade API，不改 wire contract，不写
`docs/nextpas.core.http.inbox.md`。

## Checklist

- [x] 复核设计规范、HTTP coverage/benchmark/control 文件、git status。
- [x] 新增 focused RED：Pascal H1 parser benchmark 与 C llhttp comparator 都应输出
  `bench_max_iters=2000` when `NEXTPAS_BENCH_MAX_ITERS=2000`。
- [x] `TBenchRunner` 默认 max iterations 从 `1000` 提高到 `100000`。
- [x] `TBenchRunner` 支持 `NEXTPAS_BENCH_MAX_ITERS`，非法/过小值回退默认。
- [x] C llhttp comparator 支持同名 env，并输出 effective `bench_max_iters`。
- [x] 跑 `test_http_benchmarks` focused gate + heaptrc。
- [x] 跑默认 `bench_h1parser` sanity。
- [x] 跑默认 C llhttp comparator sanity。
- [x] 跑 `git diff --check`。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.bench.pas`
- `benchmarks/nextpas.core.http/bench_h1parser/compare_c/bench_llhttp_c.c`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

默认 `100000` 是当前效率/可信度平衡点：比旧 `1000` 提高 100 倍，明显减少短 parser
rows 的计时噪声；正式跨工具链 snapshot 仍可用 `NEXTPAS_BENCH_MAX_ITERS=1000000`
或更高值。

## Intended outcome

- benchmark 数据更可靠，能继续支撑 Pascal/C llhttp 与 adapter/materialization 决策。
- focused benchmark smoke 不变慢：测试使用 env 覆盖为 `2000`。
- 为下一步 parser adapter materialization 优化提供更可信基线。
