# Progress Log: H1 server 1 KiB response benchmark correlation

## Session

- **Scope:** HTTP server benchmark workload split: 1 KiB response writer/drain path.
- **Status:** focused RED/GREEN completed, fresh `response_1k` comparison row
  captured, no-url calibration row captured, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `H1 server response writer/drain full-chain isolation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/comparator/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和两条 50k/4 comparison：
  `response_1k` 与 no-url calibration。

## Completed work

- `bench_server` 新增 `--workload response_1k`，server 写 1 KiB fixed-length body。
- `bench_server` raw client 改为按 response header boundary + expected body length
  读取完整响应。
- Go comparator 新增同名 workload，并预构造 1 KiB response body。
- Rust comparator 新增同名 workload，并按 expected body length 读取完整响应。
- `run_server_comparison.sh` 新增 `response_1k` 校验和三方参数下传。
- `test_http_benchmarks` 新增 runner-level `response_1k` smoke，覆盖 stdout / report
  以及 nextPas / Go / Rust 三方 output marker。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 benchmark 输出契约、完整响应读取口径与 fresh correlation。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `19 total, 18 passed, 1 failed`，runner 仍拒绝 `response_1k`，heaptrc
  `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `19 total, 19 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh comparison:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload response_1k`
  -> nextPas `80184 req/s`; Go `18392 req/s`; Rust std-only `90185 req/s`。
- Calibration:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload no_url`
  -> nextPas `87726 req/s`; Go `18247 req/s`; Rust std-only `94715 req/s`。

## Direction review

方向没有走偏：本轮先修 benchmark harness correctness，再用 1 KiB response workload
拆 response writer/drain path。当前证据显示 nextPas 在 response_1k row 已接近 Rust
std-only comparator，因此下一步不应优先盲改 response writer，而应继续拆 request
dispatch / handler invocation / serialization 或引入 multi-run median runner。

## Next step

继续 `6/6 benchmark/performance`。下一批建议做 multi-run server comparison runner
或 request-dispatch micro/full-chain 对照，降低噪声后再决定真正的优化点。
