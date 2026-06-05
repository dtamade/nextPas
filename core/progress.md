# Progress Log: H1 request-target URL materialization

## Session

- **Scope:** H1 server request-target URL materialization optimization.
- **Status:** focused RED/GREEN, benchmark row, docs, and verification completed.
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 adapter/server materialization`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP URL materialization 相关源码、测试、benchmark 与文档。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量测试；只跑受影响的 focused gates。

## Completed work

- 新增 `TUrl.ParseRequestTarget`，用于 HTTP request-target 解析。
- H1 server direct / poll-driven request construction 改用
  `TUrl.ParseRequestTarget(FParser.GetUrl)`。
- `test_http_base` 新增 origin-form、path-only、absolute-form compatibility、
  asterisk-form、authority-form、scheme-like origin-form、empty-input rejection
  focused tests。
- `test_http_server` 新增 handler-visible request-target URL materialization
  proof，覆盖 absolute-form、asterisk-form、authority-form 与 scheme-like
  origin-form。
- `bench_h1parser` 新增 URL materialization rows，并更新
  `test_http_benchmarks` marker。
- `docs/http/README.md`、`docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`
  已同步新 public API 与性能证据。
- 只读 `gpt-5.5 xhigh` 子代理 `Popper` 提交前审查无 Critical；Important
  反馈已补测试并验证。

## Verification

- RED:
  `make -C tests/nextpas.core.http/test_http_base clean test`
  -> failed with `Identifier idents no member "ParseRequestTarget"`.
- `make -C tests/nextpas.core.http/test_http_base clean test`
  -> `22 total, 22 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='url parse' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  -> generic origin-form `276.8 ns/op`; request-target origin-form `232.0 ns/op`.
- `make -C tests/nextpas.core.http/test_http_server clean test`
  -> `275 total, 275 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `13 total, 13 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.

## Direction review

方向没有走偏：本轮没有试图用手改 generated Pascal llhttp 解决 raw gap，而是按
性能路线优先削 adapter/materialization。`ParseRequestTarget` 对普通 server
origin-form request-target 的子步骤有明确 benchmark 收益，同时保持 absolute-form
兼容，并用 server 275-case gate 锁住 handler-visible URL materialization。

## Next step

继续 `6/6 benchmark/performance` 的 H1 adapter/server materialization 轨道。
下一批优先评估 body reader copy/ownership 或 request snapshot/lazy URL projection；
Pascal-translated llhttp raw state-machine gap 继续等待 perf/codegen 证据。
