# Progress Log: H1 parser llhttp multi-run evidence tightening

## Session

- **Scope:** H1 parser raw Pascal-vs-C llhttp multi-run benchmark runner.
- **Status:** focused RED/GREEN completed, `--runs` + `summary.tsv` landed,
  aggregation bug fixed, fresh 3-run filtered summary captured, docs/control
  files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `H1 parser Pascal-vs-C raw-gap evidence stabilization`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 focused
  `run_flag_matrix.sh --runs 3` live row。

## Completed work

- `run_flag_matrix.sh` 新增 `--runs N`，支持每个 Pascal/C variant 单次 build、多次 run。
- runner 现在会写逐次 `results.tsv`、聚合 `summary.tsv` 与 `env.txt`。
- `test_http_benchmarks` 新增 `H1 parser flag matrix runs summary smoke`，
  先锁 `unknown argument: --runs` RED，再锁 summary 契约 GREEN。
- 发现并修正 `summary.tsv` 聚合 bug：C variant 不再被排序+跳头逻辑误丢。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  与 `bench_h1parser/compare_c/README.md` 已同步 multi-run / summary 契约和 fresh
  raw-gap evidence。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `20 total, 19 passed, 1 failed`，`run_flag_matrix.sh` 仍拒绝 `--runs`，heaptrc
  `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `20 total, 20 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --smoke --no-perf --runs 3`
  -> `summary.tsv`:
  C `534.1 ns/op`; Pascal `749.1 ns/op`。

## Direction review

方向没有走偏：这轮先把 llhttp raw-gap 证据从单次结果升级成 multi-run 中位数工具。
当前结论是 Pascal-translated llhttp 仍慢于 C，但程度约 `1.40x`，暂时仍不足以支撑
“直接改 generated llhttp 就能显著拉平 full-chain”的判断。

## Next step

继续 `6/6 benchmark/performance`。下一批建议把 multi-run / median 能力扩到
`run_server_comparison.sh`，或者直接补 request dispatch / response serialization
的 micro/full-chain 对照，再决定要不要进入 llhttp generator/codegen 优化。
