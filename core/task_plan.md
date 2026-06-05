# Task Plan: HTTP router dispatch benchmark contract

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦把 request dispatch 成本从 server full-chain row 中拆出来，先让
`bench_router` 具备可测试、可记录的稳定输出契约。

本轮不改 public HTTP API，不改 server/client 生产逻辑，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] RED：新增 `bench_router handler dispatch smoke`，先看到 `bench_router`
  缺少 `operation=http.router.dispatch` marker。
- [x] GREEN：`bench_router` 新增 `handler dispatch (match + no-op handler)`
  row，并输出稳定 `operation=http.router.dispatch`。
- [x] 清理 `bench_router` 既有 unused local variable notes，避免 benchmark 输出被 FPC
  `Note:` 污染。
- [x] 跑 focused benchmark gate，锁住 `bench_router` 输出契约与 heaptrc 无泄漏。
- [x] 跑 fresh router dispatch live row，记录 narrowed dispatch 成本。
- [x] 更新 API coverage / README / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_router/bench_router.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Fresh local `bench_router` dispatch row:

- command: `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='handler dispatch' make -C benchmarks/nextpas.core.http/bench_router clean run`
- row: `handler dispatch (match + no-op handler)`
- result: `508.1 ns/op`, `1968021 ops/s`

这条 row 测的是 `THttpRouter.ServeHTTP` 对静态 route 的 match + no-op handler
调用，不包含 socket I/O、H1 parse、response serialization、middleware 或
URL/query materialization。它用于把 request dispatch 成本从 server full-chain
comparison 中拆出来。

## Next target

继续 `6/6 benchmark/performance`。下一批建议补 response serialization / writer
microbenchmark 输出契约，或把 `bench_fullchain` 整理成同样可测试的 normalized output，
再决定优化重心。
