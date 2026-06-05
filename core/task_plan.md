# Task Plan: H1 server 1 KiB response benchmark correlation

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 response writer/drain + socket 成本拆分：在 `no_url`、`url_path`、
`adapter_no_url` 之后，新增 `response_1k` workload。该 workload 保持 request
路径为 `/`，但 server 写 1 KiB fixed-length body，用于观察响应写出和完整读取成本。

本轮同时修正 benchmark harness：nextPas raw client 不再只读响应前缀，而是按
`header_end + expected_body_len` 读完整响应再计数。

本轮不改 public HTTP API，不改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP coverage / benchmark docs、控制文件与 git status。
- [x] RED：新增 `response_1k` runner smoke，先看到 runner 只接受
  `no_url|url_path|adapter_no_url` 而失败。
- [x] GREEN：nextPas `bench_server`、Go comparator、Rust comparator 与
  `run_server_comparison.sh` 都支持 `--workload response_1k`。
- [x] 修正 nextPas raw client：按 response header boundary + expected body length
  读取完整响应。
- [x] 跑 focused benchmark gate，锁住 no-url / url-path / adapter-no-url /
  response-1k smoke。
- [x] 跑 fresh 50k/4 `response_1k` comparison，并补一条完整响应读取后的 no-url
  calibration row。
- [x] 更新 API coverage / README / benchmark docs / 控制文件。
- [ ] 跑 diff check 并 path-limited commit。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_server/bench_http_server.lpr`
- `benchmarks/nextpas.core.http/compare_go/main.go`
- `benchmarks/nextpas.core.http/compare_rust/main.rs`
- `benchmarks/nextpas.core.http/run_server_comparison.sh`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Fresh 50k/4 `response_1k` row:

- nextPas: `80184 req/s`, `12471 ns/op`
- Go `net/http`: `18392 req/s`, `54369 ns/op`
- Rust std-only: `90185 req/s`, `11088 ns/op`

Fresh 50k/4 no-url calibration row with complete-response reader:

- nextPas: `87726 req/s`, `11399 ns/op`
- Go `net/http`: `18247 req/s`, `54802 ns/op`
- Rust std-only: `94715 req/s`, `10557 ns/op`

这个结果说明：当前 1 KiB response writer/drain path 没有暴露明显的 Rust 级差距；
nextPas 在本机 response_1k / no_url rows 中已经接近 Rust std-only comparator，并继续
明显快于 Go comparator。

## Next target

继续 `6/6 benchmark/performance`。下一批优先拆 request dispatch / handler
invocation / response writer serialization 的更窄 micro/full-chain 组合，或者加稳定
multi-run snapshot runner，减少单次本机噪声后再决定优化方向。
