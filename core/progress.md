# Progress Log: H1 lazy request-target projection

## Session

- **Scope:** H1 server request-target lazy projection optimization.
- **Status:** focused RED/GREEN, benchmark row, docs, and verification completed.
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 adapter/server materialization`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP lazy request-target 相关源码、测试、benchmark 与文档。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑受影响的 focused gates。

## Completed work

- `THttpRequest` 新增 `CreateFromRequestTarget`，保存 raw request-target。
- `THttpRequest.GetUrl` / `QueryParam` 首次访问时才调用
  `TUrl.ParseRequestTarget`。
- 现有 `THttpRequest.Create` / `NewRequest` / `NewGetRequest` eager 行为保持。
- H1 server direct / poll-driven request construction 改为
  `THttpRequest.CreateFromRequestTarget(FParser.GetUrl, ...)`。
- `test_http_message` 新增 lazy request-target focused proof。
- `bench_h1parser` 新增 request-create eager/lazy rows，并更新
  `test_http_benchmarks` marker。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md` 已同步本轮 contract 与
  性能证据。

## Verification

- RED:
  `make -C tests/nextpas.core.http/test_http_message clean test`
  -> failed with `Identifier idents no member "CreateFromRequestTarget"`.
- `make -C tests/nextpas.core.http/test_http_message clean test`
  -> `15 total, 15 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='request create' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  -> eager URL parse request create `557.1 ns/op`; lazy target request create
  `293.9 ns/op`.
- `make -C tests/nextpas.core.http/test_http_server clean test`
  -> `275 total, 275 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `13 total, 13 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.

## Direction review

方向没有走偏：本轮承认 Pascal-translated llhttp raw gap 是真实性能轨道，但没有在
缺少 perf/codegen 证据时手改 generated state machine。当前更高 ROI 的改动仍是
削 adapter/server materialization；lazy projection 对 simple handler dispatch
直接减少 URL parse 成本，同时 server 275-case gate 证明 handler-visible URL 语义
没有回退。

## Next step

继续 `6/6 benchmark/performance`。下一批建议做 full-chain correlation：增加或复用
不读取 `Req.Url` 的 server benchmark row，确认 lazy projection 在真实 request/response
链路里是否能穿透到 req/s；同时保留 Pascal llhttp raw-gap 为 perf-enabled 机器上的
generator/codegen 专项。
