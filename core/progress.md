# Progress Log: HTTP header GetAll miss fast path

## Session

- **Scope:** `THttpHeaders.GetAll` missing-path allocation reduction + parser projection evidence。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `server ingress/header lookup reduction`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮只 path-limited 处理 HTTP 相关文件。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `../findings.md`
  - `../progress.md`
  - `../task_plan.md`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- `bench_headers` 增加 `GetAll miss (5 headers)`，直接覆盖 normal request 缺失 `Expect` 的查询模式。
- `THttpHeaders.GetAll` 现在先 exact count；lowercase exact miss 直接返回 nil，不再分配 result array。
- 只有查询名含大写时才进入 normalize fallback，保留 public case-insensitive `GetAll` 语义。

## Verification

- Behavior guard:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - `13 total, 13 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Direct parser/fast gates:
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `18 total, 18 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark evidence:
  - `make -C benchmarks/nextpas.core.http/bench_headers clean run`
  - `make -C benchmarks/nextpas.core.http/bench_headers run`
  - `GetAll miss (5 headers)`: `136.9` -> `60.6 ns/op`
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - llhttp projection:
    - `simple GET`: `1203.7` -> `1094.1 ns/op`
    - `10 headers`: `4061.6` -> `3905.8 ns/op`
    - `POST 1KB body`: `1922.5` -> `1867.3 ns/op`
    - `pipeline 10 reqs`: `10602.0` -> `10096.6 ns/op`

## Next step

- 下一刀不要继续微调 `THttpHeaders` 基础 scan；更高收益应转向 request metadata cache 或
  `Expect` token parsing 的 targeted optimization。
- 做 metadata cache 前，先加 focused tests 锁住 duplicate `Expect`、unsupported `Expect`、no-body
  no-`100 Continue`、declared oversize under `Expect` 等语义，避免性能缓存破坏 security contract。
