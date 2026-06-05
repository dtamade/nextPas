# Task Plan: HTTP H1 outbound drain benchmark contract

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已经拆出 H1 writer fixed response serialization，本轮继续拆 internal
outbound buffer write/drain 成本，让 H1 outbound buffer 具备可测试、可记录的
benchmark 输出契约。

本轮不改 public HTTP API，不改 server/client 生产逻辑，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] RED：新增 `bench_h1outbound drain smoke`，先看到 `bench_h1outbound`
  入口不存在。
- [x] GREEN：新增 `bench_h1outbound`，输出稳定 `operation=http.h1outbound.drain`
  marker 和 `buffer write+drain 1KB` row。
- [x] 清理 `bench_h1outbound` FPC note，避免 benchmark 输出被 `Note:` 污染。
- [x] 跑 focused benchmark gate，锁住 `bench_h1outbound` 输出契约与 heaptrc 无泄漏。
- [x] 跑 fresh H1 outbound live row，记录 narrowed write/drain 成本。
- [x] 更新 API coverage / README / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_h1outbound/Makefile`
- `benchmarks/nextpas.core.http/bench_h1outbound/bench_h1outbound.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Fresh local `bench_h1outbound` drain row:

- command: `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='buffer write+drain 1KB' make -C benchmarks/nextpas.core.http/bench_h1outbound clean run`
- row: `buffer write+drain 1KB`
- result: `303.0 ns/op`, `3300665 ops/s`

这条 row 测的是 `NewH1OutboundBuffer`、1 KiB buffer write、以及 `DrainAllTo`
固定内存 writer；不包含 response writer serialization、真实 socket I/O、readiness
wake、write deadline 或 backpressure。它用于继续拆解 server full-chain comparison
的成本来源。

## Next target

继续 `6/6 benchmark/performance`。下一批建议把 `bench_fullchain` 整理成 normalized
output，或针对 H1 writer allocation/header materialization 做生产优化前的更细拆分。
