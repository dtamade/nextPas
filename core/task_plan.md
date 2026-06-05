# Task Plan: H1 request metadata cache

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 H1 parser/server 的 request metadata materialization：同一请求在 parser headers-complete、
server header policy、`100-continue` 判定、dispatch keep-alive / Host 判定之间不应重复执行
`Get/GetAll/Trim/LowerCase/TryStrToInt64`。

本轮不改 HTTP public facade API、不改 wire contract、不写 `docs/nextpas.core.http.inbox.md`，
也不碰 generated `nextpas.core.http.impl.h1.llhttp.pas`。

## Checklist

- [x] 复核设计规范、HTTP coverage、benchmark docs、控制文件与 git status。
- [x] RED：在 `test_http_h1parser` 增加 request metadata focused contract，确认缺少
      `TH1RequestMetadata` / `GetRequestMetadata` 时编译失败。
- [x] 在 H1 parser 内构建 request metadata cache，并把 server header policy /
      `100-continue` / dispatch keep-alive / Host 判断切到缓存。
- [x] 给 H1 fast parser 增加 `HasContentLength` 标志，避免 fast snapshot metadata 混淆
      “无 Content-Length”和“Content-Length: 0”。
- [x] 保留旧 request keep-alive 的精确字符串语义，不混入 behavior 修复。
- [x] 增加 H1 parser benchmark metadata rows：legacy repeated scan vs cached metadata。
- [x] 更新 `test_http_benchmarks` smoke marker。
- [x] 跑 focused parser/server/benchmark gates + heaptrc。
- [x] 更新 docs/control 证据。
- [ ] 跑 `git diff --check`。
- [ ] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.impl.h1.parser.pas`
- `src/nextpas.core.http.impl.h1.pas`
- `src/nextpas.core.http.impl.h1.fast.pas`
- `tests/nextpas.core.http/test_http_h1fast/test_http_h1fast.lpr`
- `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Pascal-translated llhttp raw gap 仍是长期性能轨道，但当前更大的短期收益在 adapter/server
metadata materialization。本轮把 H1 request-side metadata 从 scattered repeated lookup
收束成 parser 内一次构建、server 复用，避免每个请求在 policy/continue/dispatch 阶段重复解析。

## Intended outcome

- request metadata focused tests 证明 Host、Content-Length、Expect、Transfer-Encoding、
  Connection 摘要正确。
- server whole-run / poll-driven focused gate 保持 274-case wire contract 不回退。
- benchmark 同场输出 legacy repeated scan 与 cached metadata 的差异。
