# Progress Log: H1 server no-URL benchmark correlation

## Session

- **Scope:** HTTP server benchmark workload marker and full-chain correlation.
- **Status:** focused RED/GREEN, fresh comparison row, docs, and control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 server full-chain correlation`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/comparator/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 50k/4 comparison。

## Completed work

- 确认 `bench_server` handler 不读取 `AReq.Url`，当前 keep-alive comparison 已经是
  no-URL workload。
- `bench_server`、Go comparator、Rust comparator 输出新增 `workload=no_url`。
- `test_http_benchmarks` 现在会验证三方 benchmark/comparison/snapshot 都包含
  `workload=no_url`。
- 跑 fresh `50000 / 4` server comparison 并记录 nextPas / Go / Rust no-URL row。
- `docs/http/API_COVERAGE.md` 与 `docs/http/BENCHMARKS.md` 已同步 benchmark
  输出契约与 fresh correlation。

## Verification

- RED:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `5 failed` because `workload=no_url` was missing from server benchmark outputs;
  heaptrc `0 unfreed memory blocks`.
- GREEN:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `13 total, 13 passed, 0 failed`, heaptrc `0 unfreed memory blocks`.
- Fresh comparison:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4`
  -> nextPas `77958 req/s`; Go `18871 req/s`; Rust std-only `98422 req/s`.

## Direction review

方向没有走偏：本轮把 benchmark workload 语义固定为 `no_url`，并证明 lazy
request-target projection 的微基准收益尚未形成稳定 full-chain 吞吐优势。当前下一步
不应宣称追平 Rust，而应继续找 no-URL full-chain 的剩余瓶颈。

## Next step

继续 `6/6 benchmark/performance`。下一批建议补 URL-touch / router-touch server
workload，或对 no-URL workload 做更细分 profile，定位 socket/runtime、response
writer、header materialization、request dispatch 哪个子层仍在拖慢。
