# Task Plan: H1 parser direct header span insertion

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
用户指出 Pascal 翻译版 llhttp 本体可能有性能问题；本轮先用 fresh Pascal/C
benchmark 复核 raw gap，同时继续削减当前更大的 H1 adapter/header materialization 成本。

本轮只做 concrete parser/internal helper，不改 `IHttpHeaders` interface，不改
`nextpas.core.http` facade，不改 wire contract，不写 `docs/nextpas.core.http.inbox.md`。

## Checklist

- [x] 复核设计规范、HTTP coverage/benchmark/control 文件、git status。
- [x] 复用历史子代理只读审计：raw Pascal llhttp 有真实差距，但 adapter/materialization 仍是更大瓶颈。
- [x] 新增 focused RED：concrete `THttpHeaders.AddParsedSpans` 应 canonicalize parser-validated spans。
- [x] 实现 `THttpHeaders.AddParsedSpans`，直接从 parser span 构造 canonical lowercase name/value。
- [x] `TH1Parser` 对同一 `Execute` 内完整 header field/value 走 direct span insertion。
- [x] `TH1Parser` 对 split/cross-buffer header callbacks 自动物化回 string fallback，避免悬空指针。
- [x] 新增 `bench_h1parser` header span insertion breakdown row。
- [x] 跑 `test_http_headers` focused RED/GREEN + heaptrc。
- [x] 跑 `test_http_h1parser` focused gate + heaptrc。
- [x] 跑 `test_http_server` focused gate + heaptrc。
- [x] 跑 `test_http_benchmarks` focused benchmark smoke + heaptrc。
- [x] 跑 Pascal `bench_h1parser` sanity，记录 adapter/raw 数据。
- [x] 跑 C llhttp comparator sanity，记录 Pascal raw vs C raw 数据。
- [x] 更新 `docs/http/BENCHMARKS.md` 与 `docs/http/API_COVERAGE.md`。
- [x] 跑 `git diff --check`。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.headers.pas`
- `src/nextpas.core.http.impl.h1.parser.pas`
- `tests/nextpas.core.http/test_http_headers/test_http_headers.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `docs/http/BENCHMARKS.md`
- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

方向没有走偏：fresh comparator 继续显示 Pascal translated llhttp raw path 相比 C
llhttp 有约 `1.4x-1.5x` 差距，这应进入后续 FPC/codegen/profile 专项；但当前 full
adapter 仍比 raw 状态机慢得更多。本轮先消掉 common header path 的中间 field/value
string materialization，属于更确定、更低风险的收益点。

## Intended outcome

- H1 parser 保持 header canonical lookup、duplicate header、trailer isolation、split callback 语义。
- common unsplit header callback path 少一次中间 field/value string allocation/copy。
- benchmark 能同时展示 raw Pascal/C gap 与 adapter direct-span insertion 成本。
