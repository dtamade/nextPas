# Task Plan: HTTP llhttp raw translation performance triage

## Goal

继续推进 `HttpServer 完成` 主线中的 `6/6 benchmark/performance` 阶段。用户指出
“llhttp 的 Pascal 翻译移植可能有性能问题”，本轮不凭感觉判断，先把 H1 parser benchmark
拆成三层：

- raw translated llhttp：无 callback / 无 high-level object materialization，只测翻译状态机本体。
- llhttp adapter：当前 `IH1Parser` 包装层，包含 URL/header/body 组装与 transfer-coding validation。
- fast path：当前保守普通请求 fast parser。

目标是确定下一刀应该优化翻译状态机、adapter allocation，还是 server ingress fast path。

## Checklist

- [x] 复核 `docs/design-conventions.md`、HTTP coverage/control 文件和 `git status`。
- [x] 收尾并提交上一批 `GetAll` miss allocation 优化。
- [x] 检查 `llhttp` 翻译单元、`IH1Parser` adapter 和 `bench_h1parser` 结构。
- [x] 给 `bench_h1parser` 增加 raw translated llhttp no-callback benchmark。
- [x] 运行 `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`。
- [x] 更新 benchmark 文档与控制文件。
- [x] 跑最小 focused verification。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 明确 raw translated llhttp 本体和 adapter 的真实差距。
- 避免误把性能问题归因到 Pascal 翻译移植本身。
- 为下一批 adapter allocation / metadata cache / parser fast path 的取舍提供证据。
