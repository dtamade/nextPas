# Task Plan: H1 server URL-path benchmark correlation

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 full-chain workload split：在已标清 `no_url` workload 之后，
新增 `url_path` workload，让 nextPas / Go / Rust 三方 comparator 都能在同一
keep-alive 形态下触碰 request path，并用 fresh 对照判断 URL 投影与 parser
路径是否是当前 server 吞吐瓶颈。

本轮不改 public HTTP API，不改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP coverage / benchmark docs、控制文件与 git status。
- [x] RED：新增 `url_path` benchmark smoke，先看到 comparator / runner 缺少
  `--workload url_path` 支持或测试 helper 仍硬编码 `workload=no_url`。
- [x] GREEN：nextPas `bench_server`、Go comparator、Rust comparator 与
  `run_server_comparison.sh` 都支持 `--workload no_url|url_path`。
- [x] 修正 Rust comparator：同一 request frame 内完成 path 判断，不再读第二个
  request 后才响应。
- [x] 跑 focused benchmark gate，锁住 no-url 与 url-path 两组 smoke。
- [x] 跑 fresh 50k/4 `url_path` comparison，记录 nextPas / Go / Rust 对照。
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

Fresh 50k/4 `url_path` row:

- nextPas: `79527 req/s`, `12574 ns/op`
- Go `net/http`: `19019 req/s`, `52576 ns/op`
- Rust std-only: `113158 req/s`, `8837 ns/op`

这个结果说明：nextPas 在 URL-touch workload 下仍明显快于 Go comparator，但仍慢于
Rust std-only comparator。因为该 workload 仍符合当前 H1 fast path，且只在 handler
读取 `Req.Url.Path` 时触发 lazy URL materialization，所以它不能证明 Pascal 翻译版
llhttp 是当前 full-chain 瓶颈。

## Next target

继续 `6/6 benchmark/performance`。下一批优先做 forced-adapter / llhttp-path
workload，或直接补 C llhttp vs Pascal translated llhttp 的更窄 perf-counter 证据；
目标是把差距拆成 parser codegen、adapter materialization、socket/runtime、
response writer、request dispatch 几个可行动的成本桶。
