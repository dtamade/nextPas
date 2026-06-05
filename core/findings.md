# Findings: H1 benchmark row filter and flag matrix

## Scope

本轮是 benchmark/profiling seam，不改变 HTTP public API、不改变 wire contract、不写
`docs/nextpas.core.http.inbox.md`。目标是让 Pascal translated llhttp raw-gap 后续
FPC flag-matrix / C comparator / `perf stat` 可以只跑目标 row，减少重复 benchmark 成本。

## RED evidence

新增 focused smoke 后先跑：

```sh
NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp \
  make -C tests/nextpas.core.http/test_http_benchmarks clean test
```

失败点：

```text
FAIL: H1 parser benchmark filter env
bench_filter=raw llhttp: 10 headers marker missing
```

`bench_h1parser` 仍跑完整 benchmark，证明 row filter seam 不存在。随后新增
flag-matrix smoke，再次 RED：

```text
FAIL: H1 parser flag matrix smoke
Executable not found: ".../run_flag_matrix.sh"
```

这证明可复现 flag-matrix runner 尚不存在。

## Implemented change

- `TBenchRunner` 新增 `NEXTPAS_BENCH_FILTER`，按 benchmark name 做 case-insensitive substring filter，并在 summary 输出 `bench_filter=...`。
- C llhttp comparator 增加同名 filter，保持 Pascal/C focused row 对称。
- `test_http_benchmarks` 增加 Pascal filter、C filter、H1 flag-matrix smoke。
- 新增 `bench_h1parser/run_flag_matrix.sh`：
  - `--smoke` / `--perf` / `--no-perf`
  - 支持 `LLHTTP_ROOT` / `NEXTPAS_LLHTTP_ROOT`
  - 支持 `NEXTPAS_BENCH_MAX_ITERS` / `NEXTPAS_BENCH_FILTER`
  - 输出 `results.tsv`、`env.txt`、logs、可选 `perf/*.txt`
  - 所有输出都在 `build/projects/nextpas.core.http/bench_h1parser/flag_matrix/...`
- Pascal raw/no-op helper 把 `PAnsiChar(ARequest)` 和 `Length(ARequest)` 缓存到循环外，减少 Pascal/C raw 对比中的 benchmark wrapper 噪声。

## Verification

- Benchmark focused gate:
  - `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `12 total, 12 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Focused Pascal raw row:
  - `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - `bench_filter=raw llhttp: 10 headers`
  - `raw llhttp: 10 headers (~400B): 749.7 ns/op`
- Focused C raw row:
  - `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='C raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser/compare_c clean run LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp`
  - `bench_filter=C raw llhttp: 10 headers`
  - `C raw llhttp: 10 headers (~400B): 523.0 ns/op`
- FPC CPU/FPU flag trial:
  - `NEXTPAS_BENCH_MAX_ITERS=100000 NEXTPAS_BENCH_FILTER='raw llhttp: 10 headers' make -C benchmarks/nextpas.core.http/bench_h1parser clean run EXTRA_FLAGS='-CpCOREAVX2 -CfAVX2'`
  - `raw llhttp: 10 headers (~400B): 759.6 ns/op`

## Current conclusion

方向没有走偏：本轮没有把时间花在全量测试或手改 generated llhttp，而是补齐后续 raw-gap
专项的最小可复现工具。初步 A/B 显示 `-CpCOREAVX2 -CfAVX2` 没有改善 raw 10-header row；
下一步应看 `perf stat/record` 或 generated Pascal codegen 形态。

## Remaining gaps / risks

- `run_flag_matrix.sh` 是 benchmark tooling；正式性能结论仍需要更高 `NEXTPAS_BENCH_MAX_ITERS`
  和稳定机器环境。
- 不要并行运行多个共享 `bench_h1parser` build root 的 `clean run`；本轮已经观察到并行 clean 会导致
  C comparator 输出目录被删或 `Text file busy`。
- 最不应该做的是直接 patch `nextpas.core.http.impl.h1.llhttp.pas` 的 generated state machine、
  record layout、`cdecl` 或 `PACKRECORDS C`。先 profile，再决定是否改生成器或 translation seam。
