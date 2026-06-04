# Task Plan: HTTP header lookup exact fast path

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark/performance 阶段。本轮延续
`llhttp adapter allocation reduction`，但切到 server/adapter 常用的 header lookup：
内部热路径大量使用已小写的 `host`、`content-length`、`connection`、`expect`。

目标是在不改公开 API 的情况下，让 `THttpHeaders.Get/Has` 先做 exact match，只有 exact
未命中且查询名包含大写字母时才 normalize fallback，从而减少小写热路径的 normalization
成本。

要求：

- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 headers / H1 parser / H1 fast / header benchmark focused gates。
- 保持 public case-insensitive lookup 语义。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 增加 uppercase `Has` focused 语义护栏。
- [x] 增加 `Get hit uppercase` benchmark，记录 public fallback tradeoff。
- [x] 记录生产改动前 `bench_headers` baseline。
- [x] 实现 `FindFirst` exact-match fast path。
- [x] 运行 headers / H1 parser / H1 fast focused 验证与 heaptrc。
- [x] 运行 `bench_headers` before/after + confirmation 对照。
- [x] 更新控制文件与 HTTP benchmark 文档。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.headers.pas`
- `tests/nextpas.core.http/test_http_headers/test_http_headers.lpr`
- `benchmarks/nextpas.core.http/bench_headers/bench_headers.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 小写 header lookup 命中时不再先 normalize。
- public uppercase/case-insensitive lookup 继续可用。
- 明确记录 uppercase lookup 变慢这一 tradeoff，后续若 public uppercase-heavy workload 重要，再单独优化。
