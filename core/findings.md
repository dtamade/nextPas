# Findings: H1 parser llhttp multi-run evidence tightening

## Scope

本轮是 benchmark/tooling 强化，不改变 public HTTP API，不改变 wire
contract，不手改 generated llhttp，不写 `docs/nextpas.core.http.inbox.md`。

## Implemented decision

`bench_h1parser/run_flag_matrix.sh` 现在支持：

```text
--smoke / full
--perf / --no-perf
--runs N
```

multi-run 语义：

- 每个 Pascal/C variant 只 build 一次，再重复执行 `N` 次。
- 每次输出仍进入 `results.tsv`，新增 `run` 列。
- 聚合输出进入 `summary.tsv`，口径是同 variant / benchmark 的 `median_ns_per_op`。
- `env.txt` 现在也记录 `runs=N`，便于后续引用证据。

## RED / GREEN evidence

RED:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

20 total, 19 passed, 1 failed
H1 parser flag matrix runs summary smoke failed:
unknown argument: --runs
heaptrc: 0 unfreed memory blocks
```

GREEN:

```text
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
make -C tests/nextpas.core.http/test_http_benchmarks clean test

20 total, 20 passed, 0 failed
heaptrc: 0 unfreed memory blocks
```

## Performance evidence

Fresh local filtered summary:

```text
NEXTPAS_BENCH_MAX_ITERS=100000 \
NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' \
NEXTPAS_C_BENCH_FILTER='C raw llhttp: 10 headers' \
LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
benchmarks/nextpas.core.http/bench_h1parser/run_flag_matrix.sh --smoke --no-perf --runs 3

C raw llhttp 10 headers median: 534.1 ns/op
Pascal raw llhttp 10 headers median: 749.1 ns/op
```

Representative per-run rows:

```text
C raw llhttp: 526.7 / 522.6 / 525.7 ns/op
Pascal raw llhttp: 791.9 / 768.1 / 753.9 ns/op
```

结论：`Pascal raw llhttp` 相对 `C raw llhttp` 的代表性差距目前约 `1.40x`。这说明
用户对“llhttp 的 Pascal 翻译移植可能有性能问题”的判断是成立的，但当前证据仍更像
“真实但非唯一瓶颈”，而不是已经足以解释 full-chain 全部剩余差距的单点根因。

## Tooling bug note

首次实现 `summary.tsv` 时，排序后又执行了 `tail -n +2`，导致第一条真实数据行被误丢。
因为排序结果里 `c-default` 恰好排在 `pascal-default` 之前，所以 live 证据暴露出
`summary.tsv` 只剩 Pascal 行。这个聚合 bug 已通过补测后修正。

## Direction review

方向没有走偏：本轮没有直接去手改 generated llhttp，而是先把 raw-gap 证据链做稳。
现在已经可以低成本复跑 Pascal/C narrowed row，后续如果还要进入 generator/codegen
层优化，至少不会再建立在单次噪声结果上。

## Remaining gaps / risks

- multi-run/median 目前只覆盖 `bench_h1parser` flag matrix，还没有扩到
  `run_server_comparison.sh`。
- `perf` 在当前机器仍因 `perf_event_paranoid=3` 不可用，缺硬件计数器。
- 如果要进入 generated llhttp 优化，下一步仍应优先拿 perf-enabled 机器上的
  cycles/instructions/branch-miss 证据。
