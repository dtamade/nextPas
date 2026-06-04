# Task Plan: HTTP header GetAll miss fast path

## Goal

继续推进 `HttpServer 完成` 主线中的 benchmark/performance 阶段。本轮继续减少 server
ingress/header lookup work，聚焦 `THttpHeaders.GetAll` 的 missing path。

正常请求通常没有 `Expect`，也没有 `Transfer-Encoding`；但 server/parser 会在 headers
complete 后查询这些集合。旧 `GetAll` 即使 miss 也会先分配 `FCount` 大小的 result array，
再缩回 0。本轮目标是让 exact miss 直接返回 nil，只有查询名含大写时才 normalize fallback。

要求：

- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 headers / H1 parser / H1 fast / header/parser benchmark focused gates。
- 保持 public `GetAll` case-insensitive 语义。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 无关脏文件边界。
- [x] 读取 `docs/design-conventions.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 跑 `bench_h1parser`，确认上一轮 header lookup 优化有 parser 层投射。
- [x] 增加 `GetAll miss (5 headers)` benchmark。
- [x] 记录生产改动前 `bench_headers` baseline。
- [x] 实现 `GetAll` exact miss fast path。
- [x] 运行 headers / H1 parser / H1 fast focused 验证与 heaptrc。
- [x] 运行 `bench_headers` before/after + confirmation 对照。
- [x] 运行 `bench_h1parser` 投射对照。
- [x] 更新控制文件与 HTTP benchmark 文档。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `src/nextpas.core.http.headers.pas`
- `benchmarks/nextpas.core.http/bench_headers/bench_headers.lpr`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- `GetAll('expect')` / `GetAll('transfer-encoding')` missing path 不再分配临时 result array。
- public mixed/uppercase `GetAll` 命中继续由 existing focused tests 覆盖。
- 为下一步 request metadata cache 或 Expect parsing 优化提供更低成本基础。
