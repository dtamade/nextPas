# Task Plan: H1 parser callback-cost diagnostics

## Goal

继续推进 `HttpServer 完成` 主线中的 `6/6 benchmark/performance` 阶段。本轮直接回应
“Pascal translated llhttp 可能有性能问题”的风险：在不引入 C comparator、不改生产行为的前提下，
先把当前 Pascal translated llhttp 的成本拆得更细。

现有 `bench_h1parser` 已有 raw no-callback rows 和 full `IH1Parser` adapter rows，但还缺两块关键信息：

- pipeline/reset 场景下裸状态机 + message-complete pause 的成本。
- 注册 URL/header/body callbacks 但不做字符串、headers、body materialization 时的成本。

目标是补足这两类诊断 rows，用最小 benchmark 改动判断当前瓶颈到底更接近状态机/callback dispatch，
还是 adapter materialization。

## Checklist

- [x] 复核 `docs/design-conventions.md`、HTTP coverage/control 文件和 `git status`。
- [x] 检查 `bench_h1parser` 与现有 benchmark smoke 覆盖。
- [x] 新增 `raw llhttp: pipeline pause-only (10 reqs)`。
- [x] 新增 `translated llhttp with no-op callbacks` section：
  simple GET / 10 headers / POST 1KB / pipeline。
- [x] 提取 paused pipeline helper，避免 benchmark 代码重复。
- [x] 运行 `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`。
- [x] 更新 benchmark/control 文档。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 给出更强证据：如果 no-op callback rows 仍明显低于 adapter rows，则当前优化重点继续放在
  URL/header/body materialization、header container、metadata cache。
- 保留 C llhttp comparator 作为后续严格证明项，而不是在证据不足时先重写 translated llhttp。
