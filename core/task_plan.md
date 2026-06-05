# Task Plan: H1 server no-URL benchmark correlation

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 full-chain correlation：明确当前 `bench_server` keep-alive comparison
是 handler 不读取 request URL 的 `no_url` workload，并用 fresh Go/Rust 对照判断
上一批 lazy request-target projection 是否穿透到真实 server req/s。

本轮不改 generated `src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP coverage / benchmark docs、控制文件与 git status。
- [x] 确认当前 `bench_server` handler 本身不读取 `AReq.Url`，实际已经是 no-URL
  workload，只是输出未标注。
- [x] RED：benchmark smoke 要求 `workload=no_url`，先看到 nextPas/Go/Rust/server
  comparison/snapshot 5 个 smoke case 因缺 marker 失败。
- [x] GREEN：nextPas `bench_server`、Go comparator、Rust comparator 都输出
  `workload=no_url`。
- [x] 跑 fresh 50k/4 comparison，记录 no-URL full-chain correlation。
- [x] 更新 API coverage / benchmark docs / 控制文件。
- [ ] 跑 diff check 并 path-limited commit。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_server/bench_http_server.lpr`
- `benchmarks/nextpas.core.http/compare_go/main.go`
- `benchmarks/nextpas.core.http/compare_rust/main.rs`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

现有 server comparison 是 no-URL workload。fresh 50k/4 row：

- nextPas: `77958 req/s`
- Go `net/http`: `18871 req/s`
- Rust std-only: `98422 req/s`

这说明 lazy request-target projection 的微基准收益尚未稳定体现为 full-chain
吞吐收益；下一步要继续定位 server/runtime/adapter 其它成本，而不是宣称已经追平。

## Next target

继续 `6/6 benchmark/performance`。下一批优先增加 URL-touch/router-touch workload
或对 no-URL workload 做更细 profile，分离 socket/runtime、response writer、
header materialization、request dispatch 的真实成本。
