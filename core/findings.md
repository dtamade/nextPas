# Findings: H1 request-target URL materialization

## Scope

本轮是 H1 server adapter/materialization 优化，不改变 wire contract，不手改
generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Root cause

H1 server direct dispatch 与 poll-driven dispatch 在构造 `THttpRequest` 时都使用：

```pascal
TUrl.Parse(FParser.GetUrl)
```

通用 `TUrl.Parse` 必须支持 full URL、userinfo、host、port、IPv6、query、
fragment 等场景。HTTP server 常见 request-target 是 origin-form，例如
`/api/v1?page=2`，只需要拆 path / query / fragment。把普通 request-target
送入通用 parser，会在每个请求分发时支付不必要的 materialization 成本。

## Implemented decision

新增 `TUrl.ParseRequestTarget`：

- 空输入抛 `EHttpError`。
- common origin-form `'/...'` 与 asterisk-form `'*'` 不扫描 `://`，直接拆
  fragment / query / path。
- absolute-form request-target 仍委托 `TUrl.Parse`，避免破坏 proxy-style
  `GET http://host/path HTTP/1.1` 兼容性。
- authority-form request-target 保持旧兼容，不把 `example.com:443` 提升成
  URL host / port，而是作为 `Path` 暴露给 handler。
- scheme-like origin-form path，例如 `/http://example.com/path?q=1`，保持为
  origin-form path，不被通用 URL parser 误拆成 scheme/authority。
- H1 server direct 和 poll-driven request construction 都改用
  `TUrl.ParseRequestTarget(FParser.GetUrl)`。

## Performance evidence

Focused local row:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='url parse' \
make -C benchmarks/nextpas.core.http/bench_h1parser clean run

adapter cost: url parse generic origin-form = 276.8 ns/op
adapter cost: url parse request-target origin-form = 232.0 ns/op
```

This is about a 16.6% reduction for this materialization sub-step.

## Verification evidence

RED proof:

```text
make -C tests/nextpas.core.http/test_http_base clean test
test_http_base.lpr(210,16) Error: Identifier idents no member "ParseRequestTarget"
```

GREEN focused gates:

```text
make -C tests/nextpas.core.http/test_http_base clean test
22 total, 22 passed, 0 failed
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

用户关于 Pascal-translated llhttp raw gap 的怀疑仍成立；上一轮已经证明代表性
10-header raw row 约 `1.46x` 慢于 C llhttp。但本轮没有为了追 raw gap 手改
generated state machine，而是继续削 adapter/server 侧已可证明的热路径成本。
这是当前更稳、更可维护的短期性能路线。

## Subagent review

只读 `gpt-5.5 xhigh` 子代理 `Popper` 审查后未发现 Critical；Important 反馈是
提交前应补齐 asterisk-form / authority-form public API proof，以及
handler-visible request-target URL proof。本轮已采纳并验证。

## Remaining gaps / risks

- `ParseRequestTarget` 仍返回 `TUrl`，因此 path/query/fragment 字符串拆分仍会有
  managed-string materialization；下一步如果继续追 server hot path，可研究
  request snapshot 持有 raw target span 或 lazy URL projection。
- 这批没有声明 full server throughput 排名改善；只锁定 URL materialization
  sub-step 与 server contract 不回退。
- Pascal llhttp raw state-machine gap 仍需要 perf/codegen 证据，不应靠手工改
  generated file 解决。
