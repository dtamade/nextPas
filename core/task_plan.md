# Task Plan: HTTP server performance fast path

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark/performance 阶段。用户要求性能追平
Go/Rust，并指出 Pascal llhttp 翻译可能存在 hot-path 性能问题。本轮先做一刀有证据的
server ingress 优化：把已有 H1 fast parser 安全接入普通 HTTP/1.1 no-body 请求路径，
同时保持 malformed / chunked / Expect / body / connection-policy 请求回退 llhttp。

要求：

- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 fast/parser/server/benchmark focused gates。
- 先证明 correctness 和 heaptrc，再记录性能结果。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、HTTP docs、coverage、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 用 `bench_h1parser` 证明 llhttp adapter 与 fast path 存在约 1.4x 差距。
- [x] 加固 `h1.fast` 的 fallback 边界：非法同长度 method、任意 transfer-coding、重复 Content-Length、body 不完整。
- [x] 接入保守 server ingress fast path：只命中 HTTP/1.1、Host 存在、无 Connection/Expect/TE、无 body 的完整请求。
- [x] `RemoteAddr` 改为 lazy string rendering，避免 handler 不读时每请求字符串化。
- [x] 运行 focused 验证与 benchmark 对照。
- [x] 更新控制文件与 HTTP benchmark / architecture / coverage 文档。
- [ ] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.impl.h1.pas`
- `src/nextpas.core.http.impl.h1.fast.pas`
- `src/nextpas.core.http.impl.h1.writer.pas`
- `src/nextpas.core.http.message.pas`
- `tests/nextpas.core.http/test_http_h1fast/test_http_h1fast.lpr`
- `tests/nextpas.core.http/test_http_message/test_http_message.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/ARCHITECTURE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 普通 keep-alive GET ingress 不再默认走 llhttp adapter 分配路径。
- H1 malformed/chunked/body/Expect/connection 边界仍由 llhttp 与既有 server safety contract 兜底。
- nextPas server keep-alive QPS 明显缩小与 Rust std-only comparator 的差距。
