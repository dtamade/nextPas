# Task Plan: HTTP H1 writer serialization benchmark contract

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已经把 request dispatch 从 server full-chain row 中拆出，本轮继续拆
response serialization 成本，先让 H1 writer 具备可测试、可记录的稳定 benchmark
输出契约。

本轮不改 public HTTP API，不改 server/client 生产逻辑，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] RED：新增 `bench_h1writer response serialization smoke`，先看到
  `bench_h1writer` 入口不存在。
- [x] GREEN：新增 `bench_h1writer`，输出稳定 `operation=http.h1writer.serialize`
  marker 和 `fixed 200 13B` row。
- [x] 跑 focused benchmark gate，锁住 `bench_h1writer` 输出契约与 heaptrc 无泄漏。
- [x] 跑 fresh H1 writer live row，记录 narrowed serialization 成本。
- [x] 更新 API coverage / README / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_h1writer/Makefile`
- `benchmarks/nextpas.core.http/bench_h1writer/bench_h1writer.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Fresh local `bench_h1writer` serialization row:

- command: `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='fixed 200 13B' make -C benchmarks/nextpas.core.http/bench_h1writer clean run`
- row: `fixed 200 13B`
- result: `1441.1 ns/op`, `693895 ops/s`

这条 row 测的是 `TH1ResponseWriter` 构造、固定 `200 OK` header 序列化、以及 13B
body 写入固定内存 writer；不包含 request parsing、router dispatch、middleware、
socket drain 或 backpressure。它用于继续拆解 server full-chain comparison 的成本来源。

## Next target

继续 `6/6 benchmark/performance`。下一批建议把 `bench_fullchain` 整理成 normalized
output，或补 outbound buffer / drain-side microbenchmark，再决定是否进入生产优化。
