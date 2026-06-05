# Findings: H1 lazy request-target projection

## Scope

本轮是 H1 server adapter/materialization 优化，不改变 wire contract，不手改
generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Root cause

上一批已经把 H1 server dispatch 从通用 `TUrl.Parse` 降到
`TUrl.ParseRequestTarget`，但 direct / poll-driven dispatch 仍在构造
`THttpRequest` 前同步解析 request-target。

这意味着即使 handler 只写一个固定响应、完全不读取 `Req.Url` 或
`Req.QueryParam`，每个请求仍会支付 URL path/query/fragment materialization
成本。对 router / middleware / static 等需要 `Req.Url.Path` 的路径，这个成本
仍然必要；对 simple handler 则可以延迟。

## Implemented decision

新增 `THttpRequest.CreateFromRequestTarget`：

- 现有 `THttpRequest.Create` 保持 eager `TUrl` 行为，用于 public request factory
  和已经 materialized 的调用方。
- `CreateFromRequestTarget` 保存 raw request-target，并把 `FUrlParsed` 标记为
  false。
- `GetUrl` 与 `QueryParam` 通过 `EnsureUrlParsed` 首次调用
  `TUrl.ParseRequestTarget`。
- H1 server direct / poll-driven request construction 改为传 raw
  `FParser.GetUrl`，不再在 dispatch 阶段解析 URL。

## Performance evidence

Focused local row:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='request create' \
make -C benchmarks/nextpas.core.http/bench_h1parser clean run

adapter cost: request create eager url parse = 557.1 ns/op
adapter cost: request create lazy target = 293.9 ns/op
```

这是 request creation/materialization 子步骤的约 `47.2%` 降低。该数字不等同于
full server throughput 改善；router 或 handler 读取 URL 时仍会按需解析。

## Verification evidence

RED proof:

```text
make -C tests/nextpas.core.http/test_http_message clean test
test_http_message.lpr(190,24) Error: Identifier idents no member "CreateFromRequestTarget"
```

GREEN focused gates:

```text
make -C tests/nextpas.core.http/test_http_message clean test
15 total, 15 passed, 0 failed
heaptrc: 0 unfreed memory blocks

make -C tests/nextpas.core.http/test_http_server clean test
275 total, 275 passed, 0 failed
heaptrc: 0 unfreed memory blocks

NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
13 total, 13 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Direction review

用户关于 Pascal-translated llhttp raw gap 的怀疑成立：当前文档中的 fresh filtered
evidence 仍显示 10-header raw row 约 `1.46x` 慢于 C llhttp。不过这轮继续不手改
generated llhttp，因为现有证据同时显示 adapter/materialization 成本仍更大、更安全、
更容易通过 public contract tests 锁住。

## Remaining gaps / risks

- Lazy projection 只优化不读 URL 的路径；router-heavy 应用仍会触发 URL parse。
- `THttpRequest` 仍以 managed string 保存 raw request-target；更激进的 span/slice
  设计需要重新审视 lifetime 与 public `TUrl` 值语义，不适合本轮顺手做。
- Pascal llhttp raw-gap 需要 perf-enabled 机器上的 cycles/instructions/branch data，
  或 generator/codegen 证据；不应靠手工 patch generated state machine。
