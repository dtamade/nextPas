# Task Plan: H1 parser adapter materialization breakdown

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
当前证据显示 Pascal translated llhttp raw 本体相比 C llhttp 有真实 gap，但 full
`IH1Parser` 更大的成本在 adapter/materialization。本轮不手改巨型 llhttp 状态机，
先把 adapter 成本拆成可重复 benchmark rows：span string append、header container add、
body copy。目标是让下一步优化直接打到最大成本来源。

本轮不改公开 HTTP facade API，不改 wire contract，不写
`docs/nextpas.core.http.inbox.md`。

## Checklist

- [x] 复核设计规范、HTTP coverage/benchmark/control 文件、git status。
- [x] 启动只读子代理审查 Pascal llhttp raw gap 与 adapter 成本边界。
- [x] 新增 focused RED：`bench_h1parser` smoke 必须包含 adapter materialization breakdown rows。
- [x] 在 `bench_h1parser` 新增 span append / header add / body copy 拆分 rows。
- [x] 跑 `test_http_benchmarks` focused gate + heaptrc。
- [x] 跑默认 `bench_h1parser` sanity，记录 breakdown rows。
- [x] 更新 `docs/http/BENCHMARKS.md` 的性能证据。
- [x] 跑 `git diff --check`。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

当前最佳路径不是手工改 Pascal llhttp 巨型翻译状态机，而是先量化 adapter
materialization。若 breakdown 证明 header container / string append 是大头，下一批再做
lazy/span-backed/metadata-specific 优化；若 raw gap 继续稳定，再单开 codegen/profile 轨道。

## Intended outcome

- benchmark 输出能直接回答 adapter 慢在哪里。
- 下一批性能优化可以用 focused row 判断收益，不再凭 full adapter 单行猜测。
- 正确性/接口契约不变。
