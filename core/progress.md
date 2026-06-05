# Progress Log: HTTP server comparison multi-run evidence tightening

## Session

- **Scope:** HTTP server nextPas / Go / Rust full-chain comparison runner.
- **Status:** focused RED/GREEN completed, `run_server_comparison.sh --runs`
  landed, snapshot `--runs` passthrough landed, fresh 50k/4 no-URL 3-run summary
  captured, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `HTTP server full-chain multi-run comparison stabilization`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 focused
  `run_server_comparison.sh --runs 3` live row。

## Completed work

- `run_server_comparison.sh` 新增 `--runs N`，支持三方 comparator 单次 build、多次 run。
- runner 现在保留逐轮 `run=N` raw output，并追加 median `summary_impl` 行。
- `capture_server_comparison_snapshot.sh` 新增 `--runs N` 参数透传和 Markdown 元数据。
- `test_http_benchmarks` 新增 runner/snapshot 两条 multi-run smoke。
- 发现并修正 runner summary 解析 bug：不再假设 `impl=` 与 `ns/op=` 在同一行。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 server comparison multi-run / summary 契约和 fresh full-chain evidence。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `21 total, 20 passed, 1 failed`，`run_server_comparison.sh` 仍拒绝 `--runs`，heaptrc
  `0 unfreed memory blocks`。
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `22 total, 22 passed, 0 failed`，heaptrc `0 unfreed memory blocks`。
- Fresh live row:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload no_url --runs 3`
  -> summary:
  nextPas `11431 ns/op`, `87476 req/s`; Go `55017 ns/op`, `18176 req/s`; Rust
  `9885 ns/op`, `101153 req/s`。

## Direction review

方向没有走偏：这轮把 server comparison 的单次噪声问题收口成工具能力。
当前 full-chain no-URL 中位数显示 nextPas 仍明显快于 Go，并约 `1.16x` 慢于 Rust
std-only comparator；下一步应拆更窄成本，而不是继续用单次 full-chain row 下结论。

## Next step

继续 `6/6 benchmark/performance`。下一批建议补 request dispatch / response
serialization 的 micro/full-chain 对照，或添加 Hyper/Tokio Rust comparator，避免
std-only comparator 被误读成整个 Rust 生态基线。
