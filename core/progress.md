# Progress Log: HTTP server comparison median snapshot

## Session

- **Scope:** multi-workload server comparison median snapshot.
- **Status:** four workload `--runs 3` evidence captured, docs/control files updated.
- **Roadmap Position:** `6/6 benchmark/performance` ->
  `server comparison calibration and next-seam selection`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理
  HTTP docs/control files。
- 父目录 `../task_plan.md`、`../findings.md`、`../progress.md` 已有无关脏改；
  本轮只更新 `core/task_plan.md`、`core/findings.md`、`core/progress.md`。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量 HTTP 测试；只跑四条 focused live comparison rows。

## Completed work

- `no_url --runs 3`: nextPas median `10405 ns/op`, Rust std-only `9051 ns/op`,
  Go `47688 ns/op`。
- `adapter_no_url --runs 3`: nextPas median `12280 ns/op`, Rust std-only
  `8140 ns/op`, Go `48857 ns/op`。
- `url_path --runs 3`: nextPas median `10133 ns/op`, Rust std-only `7391 ns/op`,
  Go `47782 ns/op`。
- `response_1k --runs 3`: nextPas median `9896 ns/op`, Rust std-only
  `9408 ns/op`, Go `50560 ns/op`。
- `docs/http/BENCHMARKS.md` 与 `docs/http/API_COVERAGE.md` 已同步 snapshot 和下一批方向。

## Verification

- `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload no_url --runs 3`
  -> summary nextPas `10405 ns/op`, `96098 req/s`; Rust `9051 ns/op`, `110479 req/s`; Go `47688 ns/op`, `20969 req/s`。
- `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload adapter_no_url --runs 3`
  -> summary nextPas `12280 ns/op`, `81433 req/s`; Rust `8140 ns/op`, `122845 req/s`; Go `48857 ns/op`, `20467 req/s`。
- `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload url_path --runs 3`
  -> summary nextPas `10133 ns/op`, `98685 req/s`; Rust `7391 ns/op`, `135291 req/s`; Go `47782 ns/op`, `20928 req/s`。
- `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 20000 --threads 4 --workload response_1k --runs 3`
  -> summary nextPas `9896 ns/op`, `101044 req/s`; Rust `9408 ns/op`, `106285 req/s`; Go `50560 ns/op`, `19778 req/s`。

## Direction review

方向没有走偏：当前要追 Rust/Go，不应只看单一 row。median snapshot 显示 nextPas 已显著快于
Go `net/http`，接近 Rust std-only 的 `response_1k`，但 adapter path 与 URL path 仍明显落后。

## Next step

继续 `6/6 benchmark/performance`。下一批建议聚焦 `adapter_no_url`：先用 H1 parser /
server adapter narrowed benchmark 锁住当前 llhttp adapter path 成本，再做最小 RED/GREEN 优化。
