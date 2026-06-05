# Task Plan: HTTP full-chain benchmark output contract

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
上一批已经拆出 H1 outbound buffer write/drain 成本，本轮把旧的
`bench_fullchain` 整理成可过滤、可机器断言的 normalized output，让完整
request-response keep-alive 路径也能进入 `test_http_benchmarks` focused gate。

本轮不改 public HTTP API，不改 server/client 生产逻辑，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP docs/control files 与 git status，确认共享 checkout 脏文件边界。
- [x] RED：新增 `bench_fullchain plaintext smoke`，先看到旧 full-chain 输出缺少
  `operation=http.fullchain.keepalive`。
- [x] GREEN：让 `bench_fullchain` 支持 `NEXTPAS_BENCH_MAX_ITERS` 和
  `NEXTPAS_BENCH_FILTER`。
- [x] GREEN：输出稳定 `operation=http.fullchain.keepalive`、
  `workload=plaintext`、`iterations`、`completed`、`elapsed_ns`、`ns/op`、
  `req/s` 与 `bench_filter` marker。
- [x] 跑 focused benchmark gate，锁住 `bench_fullchain` 输出契约与 heaptrc 无泄漏。
- [x] 跑 fresh plaintext live row，记录 full-chain keep-alive 成本。
- [x] 更新 API coverage / README / benchmark docs / 控制文件。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_fullchain/bench_fullchain.lpr`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Fresh local `bench_fullchain` plaintext row:

- command: `NEXTPAS_BENCH_MAX_ITERS=1000 NEXTPAS_BENCH_FILTER=plaintext make -C benchmarks/nextpas.core.http/bench_fullchain clean run`
- row: `workload=plaintext`
- result: `completed=1000`, `elapsed_ns=127167209`, `127167.2 ns/op`, `7864 req/s`

这条 row 测的是真实 `THttpServer`、单 TCP keep-alive 连接、request write、
server parse/dispatch/serialize/write、client read complete response 的完整路径。
它不代表多连接并发吞吐，也不代表 Go/Rust ecosystem 的正式对照。

本次 `clean run` 重新编译依赖时出现 2 条既有 FPC `Note:`：
`nextpas.core.text.format.pas(61,5)` 和
`nextpas.core.http.impl.h1.parser.pas(643,3)`，没有 FPC `Warning:`。

## Next target

继续 `6/6 benchmark/performance`。下一批建议基于已经固定的 full-chain row，
拆 H1 writer allocation / header materialization 成本，或者做一次小规模多 run
server comparison 复核当前优化优先级；不要先做 broad benchmark sweep。
