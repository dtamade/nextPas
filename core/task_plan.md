# Task Plan: H1 lazy request-target projection

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 H1 server adapter/materialization：server dispatch 不应在 handler
尚未读取 `Req.Url` / `Req.QueryParam` 时就解析 request-target URL。

本轮不改 generated `src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP coverage / benchmark docs、控制文件与 git status。
- [x] 复核 Pascal-translated llhttp raw gap 证据：代表性 raw row 仍约 `1.46x`
  慢于 C llhttp，但 adapter/materialization 仍是更大的当前成本。
- [x] RED：新增 `THttpRequest.CreateFromRequestTarget` focused test，先看到
  缺少 constructor 的编译失败。
- [x] GREEN：实现 lazy request-target projection，`Url` / `QueryParam` 首次访问
  时才调用 `TUrl.ParseRequestTarget`。
- [x] 将 H1 server direct / poll-driven request construction 切到
  `THttpRequest.CreateFromRequestTarget`。
- [x] 新增 H1 parser benchmark request-create rows，并更新 benchmark smoke marker。
- [x] 更新 API coverage / benchmark docs / 控制文件。
- [x] 跑 focused gates 与 diff check。

## Scope

本轮允许修改：

- `src/nextpas.core.http.message.pas`
- `src/nextpas.core.http.impl.h1.pas`
- `tests/nextpas.core.http/test_http_message/test_http_message.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Lazy request-target projection 是当前比手改 generated llhttp 更稳的短期收益点。
本机 focused row 显示：

- eager URL parse request create: `557.1 ns/op`
- lazy target request create: `293.9 ns/op`

收益只适用于不读取 `Req.Url` / `Req.QueryParam` 的路径；router / middleware /
static 等读取 URL path 的路径仍会按需 materialize，保持现有 public behavior。

## Next target

继续 `6/6 benchmark/performance`。下一批优先做 request/handler dispatch 剩余
allocation 与 full-chain correlation；Pascal-translated llhttp raw gap 保留为
generator/codegen/perf-counter 专项，等 perf-enabled 机器或更强 codegen 证据后再动。
