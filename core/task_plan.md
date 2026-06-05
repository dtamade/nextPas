# Task Plan: H1 parser trusted header add

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批 adapter breakdown 已证明 body copy 不是当前瓶颈，10-header full adapter 的主要成本在
header string materialization 与 `THttpHeaders.Add`。本轮做一个窄生产优化：
H1 parser 对 llhttp 已验证过的 header 使用 concrete `THttpHeaders.AddParsed`，避免重复
name/value validation，并把 header name 规范化保持为 lowercase。

本轮不改 `IHttpHeaders` interface，不改 `nextpas.core.http` facade，不改 wire contract，不写
`docs/nextpas.core.http.inbox.md`。

## Checklist

- [x] 复核设计规范、HTTP coverage/benchmark/control 文件、git status。
- [x] 新增 focused RED：concrete `THttpHeaders.AddParsed` 应 canonicalize parser-validated headers。
- [x] 实现 `THttpHeaders.AddParsed` 与 single-pass parsed-name lowercase。
- [x] `TH1Parser` 持有 concrete parser-owned header store，并在 header-complete 回调使用 `AddParsed`。
- [x] 更新 `bench_h1parser` header-add breakdown row 使用 parser trusted path。
- [x] 跑 `test_http_headers` focused gate + heaptrc。
- [x] 跑 `test_http_h1parser` focused gate + heaptrc。
- [x] 跑 `test_http_server` focused gate + heaptrc。
- [x] 跑 `test_http_benchmarks` focused benchmark smoke + heaptrc。
- [x] 跑 `bench_h1parser` sanity，记录性能证据。
- [x] 更新 `docs/http/BENCHMARKS.md` 与 `docs/http/API_COVERAGE.md`。
- [x] 跑 `git diff --check`。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.headers.pas`
- `src/nextpas.core.http.impl.h1.parser.pas`
- `tests/nextpas.core.http/test_http_headers/test_http_headers.lpr`
- `benchmarks/nextpas.core.http/bench_h1parser/bench_h1parser.lpr`
- `docs/http/BENCHMARKS.md`
- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

方向正确：本轮不是盲改 Pascal llhttp 状态机，而是削减已被 benchmark 证明的大头
header materialization。当前 measured result 已显示 header-add breakdown row 明显下降，并带动
full `IH1Parser` 10-header / POST / pipeline rows 改善。

## Intended outcome

- H1 parser 保持原有 header canonical lookup、duplicate header、malformed header 拒绝契约。
- 日常 server/public contract gate 不回退。
- parser adapter header-add 成本下降，并为下一批继续减少 string span materialization 做铺垫。
