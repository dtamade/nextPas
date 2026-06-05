# Task Plan: H1 parser llhttp multi-run evidence tightening

## Goal

继续推进 `nextpas.core.http` 总路线图的 `6/6 benchmark/performance` 阶段。
本轮聚焦 `Pascal raw llhttp vs C llhttp` 的证据稳定性，而不是继续单次跑分。
目标是把现有 `bench_h1parser/run_flag_matrix.sh` 提升为可重复 multi-run runner，
让 narrowed raw-gap 分析直接产出逐次结果和中位数汇总。

本轮不改 public HTTP API，不改 server/client 生产逻辑，不手改 generated
`src/nextpas.core.http.impl.h1.llhttp.pas`，不写
`docs/nextpas.core.http.inbox.md`，不跑全量 HTTP 测试。

## Checklist

- [x] 复核设计规范、HTTP coverage / benchmark docs、控制文件与 git status。
- [x] RED：新增 `run_flag_matrix.sh --runs 2` summary smoke，先看到 runner
  直接报 `unknown argument: --runs`。
- [x] GREEN：`run_flag_matrix.sh` 支持 `--runs N`，并输出逐次 `results.tsv`、
  聚合 `summary.tsv` 和 `env.txt`。
- [x] 修正 `summary.tsv` 聚合 bug：当 Pascal/C 两个 variant 都存在时，不再误丢
  排序后的第一条数据行。
- [x] 跑 focused benchmark gate，锁住 multi-run summary 契约与 heaptrc 无泄漏。
- [x] 跑 fresh filtered `--runs 3` live row，固定 Pascal/C raw llhttp 中位数。
- [x] 更新 API coverage / README / benchmark docs / 控制文件。
- [ ] 跑 diff check 并 path-limited commit。

## Scope

本轮允许修改：

- `benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh`
- `benchmarks/nextpas.core.http/bench_h1parser/compare_c/README.md`
- `tests/nextpas.core.http/test_http_benchmarks/test_http_benchmarks.lpr`
- `docs/http/API_COVERAGE.md`
- `docs/http/BENCHMARKS.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Current conclusion

Fresh filtered `--runs 3` summary:

- C raw llhttp 10 headers median: `534.1 ns/op`
- Pascal raw llhttp 10 headers median: `749.1 ns/op`

这个结果把 raw-gap 重检从单次行提升成了 multi-run 中位数证据。当前代表性差距约为
`1.40x`，说明 Pascal 翻译态 llhttp 确实慢于 C，但还没有大到足以单独解释
此前 full-chain 中 nextPas 相对 Rust 的全部剩余差距。

## Next target

继续 `6/6 benchmark/performance`。下一批优先把 multi-run / median 思路扩到
server comparison runner，或者直接拆 request dispatch / response serialization
的更窄 micro/full-chain 对照，再决定是否值得进入 generated llhttp 的 generator /
codegen 级优化。
