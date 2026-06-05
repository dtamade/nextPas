# Task Plan: C llhttp comparator proof track

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
用户指出 Pascal translated llhttp 可能存在性能问题；本轮不再停留在栈内
raw/no-op/adapter 推断，而是新增 same-payload C llhttp comparator，直接对照
Pascal 翻译版 state machine 与 C llhttp `9.4.1` 的本机吞吐差距。

本轮不改公开 API，不改生产 HTTP 语义，不写 inbox。工作性质是 benchmark/test/docs
证据补齐。

## Checklist

- [x] 复核 `docs/design-conventions.md`、HTTP coverage/control 文件和 `git status`。
- [x] 保留 RED 证据：`bench_h1parser/compare_c` 入口不存在时 `make ... run` 失败。
- [x] 新增 `bench_h1parser/compare_c` C llhttp comparator，不 vendor llhttp。
- [x] 给父级 `bench_h1parser` Makefile 增加 `run-c` 代理目标。
- [x] 给 `test_http_benchmarks` 增加 missing `LLHTTP_ROOT` diagnostic smoke。
- [x] 给 `test_http_benchmarks` 增加 `NEXTPAS_LLHTTP_ROOT` opt-in C comparator smoke。
- [x] 本机用 llhttp `9.4.1` 跑 C comparator 与 Pascal comparator，记录方向性对照。
- [x] 更新 `findings.md`、`progress.md`、`docs/http/BENCHMARKS.md`。
- [x] 跑聚焦验证：`diff --check`、Pascal bench、C bench、benchmark smoke + heaptrc。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/bench_h1parser/Makefile`
- `benchmarks/nextpas.core.http/bench_h1parser/compare_c/*`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

本机对照显示 C llhttp 在 10 headers、POST、pipeline 与 no-op callback rows 上通常快于
Pascal translated llhttp，差距约 `1.4x-1.6x`；raw simple GET 这类极短输入噪声敏感，
不能单独当成 parity 结论。这说明 Pascal 翻译版性能确实需要进入优化路线；但 nextPas
完整 `IH1Parser` adapter 相比 raw state machine 的差距仍更大，当前最高收益点仍是
adapter/materialization、header/body storage、server hot path 与后续 zero-copy 路线。

## Intended outcome

- 用户关于 “Pascal llhttp 翻译移植可能慢” 的问题有可复跑 C comparator 证据。
- 后续优化路线不再凭感觉二选一：先量化 C/Pascal state machine 差距，再继续削减
  adapter/server 额外成本。
