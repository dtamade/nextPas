# Task Plan: HTTP parser span append fast path

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark/performance 阶段。本轮延续
`TH1Parser` adapter allocation reduction：在不改公开 API、不改 llhttp 状态机的前提下，
减少 URL/header field/header value 回调把 span 搬进 Pascal string 时的临时分配。

当前判断：性能问题仍更像 adapter managed allocation / copy 成本，而不是 llhttp Pascal
状态机本体。先落一刀小而可证的 adapter 优化，再继续判断是否需要更深的 llhttp port 审计。

要求：

- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 H1 parser / H1 fast / parser benchmark focused gates。
- split callback 行为必须有 focused proof，heaptrc 必须为 `0 unfreed memory blocks`。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、HTTP coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 增加 split URL/header/value callback focused 语义护栏。
- [x] 记录生产改动前 `bench_h1parser` baseline。
- [x] 优化 parser 回调 span append：首段直接 `SetString`，后续分片 `SetLength + Move`。
- [x] 运行 H1 parser / H1 fast focused 验证与 heaptrc。
- [x] 运行 `bench_h1parser` before/after 对照。
- [x] 更新控制文件与 HTTP benchmark 文档。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.impl.h1.parser.pas`
- `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 常见单段 URL/header callback 不再先分配临时 `LChunk` 再做字符串拼接。
- 跨 `Execute` 分片的 URL/header field/header value 仍能正确累积。
- 为下一步继续减少 header lookup normalization / server ingress 重复扫描提供更干净的 adapter 基线。
