# Progress Log: H1 server forced-adapter benchmark correlation

## Session

- **Scope:** HTTP server benchmark workload split: forced-adapter no-URL path.
- **Status:** focused RED/GREEN completed, fresh `adapter_no_url` comparison row
  captured, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `H1 server full-chain forced-adapter isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/comparator/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 50k/4
  `adapter_no_url` comparison。

## Completed work

- `bench_server` 新增 `--workload adapter_no_url`，client 发送带
  `Connection: keep-alive` 的 no-URL request。
- Go comparator 新增同名 workload，并通过 `client.Do` 设置 request header。
- Rust comparator 新增同名 workload，并发送带 `Connection: keep-alive` 的 raw request。
- `run_server_comparison.sh` 新增 `adapter_no_url` 校验和三方参数下传。
- `test_http_benchmarks` 新增 runner-level `adapter_no_url` smoke，覆盖 stdout / report
  以及 nextPas / Go / Rust 三方 output marker。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 benchmark 输出契约与 fresh correlation。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `18 total, 17 passed, 1 failed`，runner 仍拒绝 `adapter_no_url`，heaptrc
  `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `18 total, 18 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh comparison:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload adapter_no_url`
  -> nextPas `78828 req/s`; Go `17294 req/s`; Rust std-only `95806 req/s`。

## Direction review

方向没有走偏：本轮把 forced-adapter full-chain workload 固定为可复现 benchmark
contract，避免把性能差距直接归因于 fast path 或 URL projection。当前证据显示
nextPas adapter path 没有明显拖垮 full-chain throughput；但 Pascal translated llhttp
raw gap 仍应保留为后续 generator/codegen 级优化 track。

## Next step

继续 `6/6 benchmark/performance`。下一批建议拆 full-chain 子成本：response
writer/drain、socket/runtime handoff、adapter materialization、request dispatch。
如果继续研究 llhttp translation，应先补 perf-counter 或 generator-level 方案，避免
手改 generated state machine。
