# Progress Log: HTTP server performance fast path

## Session

- **Scope:** H1 server ingress fast path + lazy RemoteAddr + focused performance evidence。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 server ingress fast path`

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

- `h1.fast` 现在精确匹配 method，非法同长度 method 不再误判。
- `h1.fast` 对任意 `Transfer-Encoding`、重复 `Content-Length`、body 不完整直接 fallback。
- H1 server ingress 现在保守尝试 fast parser：只命中 HTTP/1.1、Host 存在、无 Connection/Expect/TE、无 body 的完整请求。
- `THttpRequest.RemoteAddr` 支持从 `TNetAddress` lazy rendering，handler 不读取时不再每请求生成字符串。
- 清理 HTTP 相关 CRLF constant compiler notes，避免 benchmark harness 输出被本轮改动污染。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_message clean test`
  - 初次失败：`Identifier idents no member "SetRemoteNetAddr"`
- Focused gates:
  - `make -C tests/nextpas.core.http/test_http_message clean test`
  - `14 total, 14 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `18 total, 18 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `5 total, 5 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark evidence:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - fast simple GET: `691.3 ns/op`; llhttp simple GET: `1111.4 ns/op`
  - `benchmarks/nextpas.core.http/run_server_comparison.sh --requests 50000 --threads 4`
  - nextPas: `completed=50000`, `ns/op=12397`, `req/s=80660`
  - Rust std-only: `completed=50000`, `ns/op=10067`, `req/s=99324`

## Next step

- 继续性能路线时，优先做 `TH1Parser` adapter / `THttpHeaders` 分配优化：headers capacity/count，
  以及 headers-complete 阶段缓存 Host、Expect、Content-Length、keep-alive 判定。
