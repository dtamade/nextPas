# Task Plan: HTTP parser header reuse fast path

## Goal

继续推进 `HttpServer 完成` 主线中的 `6/6 benchmark/performance` 阶段。上一批已经证明
raw translated llhttp 状态机不是当前主要瓶颈，`IH1Parser` adapter materialization 才是更高收益
区域。本轮聚焦 per-request header allocation：`TH1Parser.Reset` 旧实现每次都会创建新的
`IHttpHeaders` 对象。

目标是在保持 headers public contract 可测试的前提下，为 `IHttpHeaders` 增加 `Clear`，并让
`TH1Parser.Reset` 复用内部 header container，降低 repeated parse / keep-alive / benchmark 路径
的分配与对象构造成本。

## Checklist

- [x] 复核 `docs/design-conventions.md`、HTTP coverage/control 文件和 `git status`。
- [x] 检查 `IHttpHeaders` / `THttpHeaders` 当前公开契约和 tests。
- [x] 运行当前 `bench_h1parser` baseline。
- [x] RED：新增 `IHttpHeaders.Clear` focused test，并确认缺失接口会失败。
- [x] GREEN：实现 `IHttpHeaders.Clear` / `THttpHeaders.Clear`。
- [x] 让 `TH1Parser.Reset` 复用 headers container。
- [x] 增强 `Reset and reparse` parser guard，确认 Reset 后不串旧 header。
- [x] 运行 headers / H1 parser / H1 fast focused tests + heaptrc。
- [x] 运行 `bench_h1parser` after + confirmation。
- [x] 更新 API coverage、benchmark 文档和控制文件。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.intf.pas`
- `src/nextpas.core.http.headers.pas`
- `src/nextpas.core.http.impl.h1.parser.pas`
- `tests/nextpas.core.http/test_http_headers/test_http_headers.lpr`
- `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- `IHttpHeaders.Clear` 成为可复用 container 的明确 public contract。
- parser Reset 不再为每个请求重新分配 headers object。
- H1 parser benchmark 对 adapter allocation reduction 有明确投射证据。
