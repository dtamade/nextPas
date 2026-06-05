# Task Plan: H1 server forced-adapter benchmark correlation

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 forced-adapter full-chain isolation：在 `no_url` 与 `url_path` 之后，
新增 `adapter_no_url` workload。该 workload 保持 no-URL handler，但在请求里带
`Connection: keep-alive`，让 nextPas 明确绕开 H1 fast parser，进入 llhttp adapter
path。

本轮不改 public HTTP API，不改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP coverage / benchmark docs、控制文件与 git status。
- [x] 确认 fast path 条件：`HasConnection` 会让 `TryUseFastRequestParser` 返回
  false。
- [x] RED：新增 `adapter_no_url` runner smoke，先看到 runner 只接受
  `no_url|url_path` 而失败。
- [x] GREEN：nextPas `bench_server`、Go comparator、Rust comparator 与
  `run_server_comparison.sh` 都支持 `--workload adapter_no_url`。
- [x] 跑 focused benchmark gate，锁住 no-url / url-path / adapter-no-url smoke。
- [x] 跑 fresh 50k/4 `adapter_no_url` comparison，记录 nextPas / Go / Rust 对照。
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

Fresh 50k/4 `adapter_no_url` row:

- nextPas: `78828 req/s`, `12685 ns/op`
- Go `net/http`: `17294 req/s`, `57822 ns/op`
- Rust std-only: `95806 req/s`, `10437 ns/op`

这个结果说明：forced-adapter no-URL workload 下，nextPas 仍明显快于 Go comparator，
仍慢于 Rust std-only comparator，但没有出现“离开 fast path 后 full-chain 崩塌”的证据。
Pascal translated llhttp 的 raw gap 仍是真实优化 track；只是当前 server full-chain 差距
不能只归因于 fast path 或 URL projection。

## Next target

继续 `6/6 benchmark/performance`。下一批优先拆更窄的 full-chain 成本桶：
parser adapter materialization、response writer/drain、runtime/socket handoff、
request dispatch。若要继续碰 generated llhttp，应先补 perf-counter 证据或 generator
级方案，而不是手改翻译产物。
