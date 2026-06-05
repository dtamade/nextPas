# Task Plan: H1 request-target URL materialization

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 H1 server adapter/materialization 热路径：普通 HTTP request-target
不应每次都走通用 URL parser 的 authority / host / port 解析路径。

本轮不改 generated `src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量测试。

## Checklist

- [x] 复核设计规范、HTTP coverage / benchmark docs、控制文件与 git status。
- [x] 确认 H1 server direct / poll dispatch 都仍用 `TUrl.Parse(FParser.GetUrl)`。
- [x] RED：新增 `TUrl.ParseRequestTarget` focused tests，锁住 origin-form、
  path-only、absolute-form compatibility、asterisk-form、authority-form、
  scheme-like origin-form、empty-input rejection。
- [x] GREEN：实现 `TUrl.ParseRequestTarget`，common origin-form 避开 authority
  parsing 和 `://` 扫描，absolute-form 委托 `TUrl.Parse`。
- [x] 将 H1 server request construction 切到 `TUrl.ParseRequestTarget`。
- [x] 补 H1 server handler-visible URL materialization proof，覆盖
  absolute-form、asterisk-form、authority-form 与 scheme-like origin-form。
- [x] 新增 H1 parser benchmark URL materialization rows，并更新 benchmark smoke marker。
- [x] 更新 README / API coverage / benchmark docs / 控制文件。
- [x] 跑 focused gates 与 diff check。

## Scope

本轮允许修改：

- `src/nextpas.core.http.base.pas`
- `src/nextpas.core.http.impl.h1.pas`
- `tests/nextpas.core.http/test_http_base/test_http_base.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `docs/http/README.md`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

`ParseRequestTarget` 是比继续手碰 Pascal llhttp generated code 更稳的短期收益点。
本机 focused row 显示：

- generic origin-form URL parse: `276.8 ns/op`
- request-target origin-form parse: `232.0 ns/op`

收益约 16.6%，且 H1 server 275-case gate 证明 direct / epoll / poll-driven
server contracts 未被破坏，并直接锁住 handler-visible request-target
materialization。

## Next target

继续沿 adapter/materialization 优先级推进。下一批优先看 body reader
copy/ownership 或 request snapshot URL/cache 之外的剩余 dispatch allocation，
raw Pascal llhttp state-machine gap 仍保留到 perf/codegen 证据充分后处理。
