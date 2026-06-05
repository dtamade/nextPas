# Progress Log: H1 server URL-path benchmark correlation

## Session

- **Scope:** HTTP server benchmark workload split: `no_url` vs `url_path`.
- **Status:** focused RED/GREEN completed, fresh `url_path` comparison row
  captured, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `H1 server full-chain workload split`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP benchmark/comparator/test/docs/control files。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑 `test_http_benchmarks` 和一条 50k/4
  `url_path` comparison。

## Completed work

- `bench_server` 新增 `--workload no_url|url_path`，并在 `url_path` 下读取
  `AReq.Url.Path`。
- Go comparator 新增同名 workload 参数，`url_path` 下读取 `request.URL.Path`。
- Rust comparator 新增同名 workload 参数，并修正为一次读取当前 request frame 后直接
  path-check，不再等待第二个 request。
- `run_server_comparison.sh` 新增 `--workload` 校验和三方参数下传。
- `test_http_benchmarks` 新增 nextPas / Go / Rust / runner 的 `url_path` smoke。
- `docs/http/API_COVERAGE.md`、`docs/http/BENCHMARKS.md`、`docs/http/README.md`
  已同步 benchmark 输出契约与 fresh correlation。

## Verification

- Focused gate:
  `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  -> `17 total, 17 passed, 0 failed`, heaptrc `0 unfreed memory blocks`。
- Fresh comparison:
  `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4 --workload url_path`
  -> nextPas `79527 req/s`; Go `19019 req/s`; Rust std-only `113158 req/s`。

## Direction review

方向没有走偏：本轮把 `url_path` workload 作为可复现 benchmark contract 固定下来，
并用三方同形对照证明当前 URL-touch 成本不是主要瓶颈。Pascal translated llhttp 仍是
真实优化 track，但本轮证据不足以支持直接手改 generated state machine。

## Next step

继续 `6/6 benchmark/performance`。下一批建议补 forced-adapter / llhttp-path
server workload，让 full-chain 明确绕开 H1 fast parser，或者用 C/Pascal llhttp
filtered benchmark + perf counters 先定位 generated parser 的真实差距来源。
