# Progress Log: H1 request metadata cache

## Session

- **Scope:** H1 parser/server request metadata cache.
- **Status:** implementation and focused validation complete; final diff check and commit pending.
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser/server metadata materialization`.

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP H1
  parser/server/benchmark/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮没有跑全量测试；只跑 h1fast/parser/server/benchmark focused gates。

## Completed work

- RED：`test_http_h1parser` 新增 request metadata contract，先失败于缺少
  `TH1RequestMetadata` / `GetRequestMetadata`。
- GREEN：`IH1Parser` 内部扩展 `GetRequestMetadata`，`TH1Parser` 在 headers-complete 阶段
  一次构建 Host / Content-Length / Transfer-Encoding / Expect / Connection 摘要。
- server header policy、`100-continue`、dispatch keep-alive / Host 判断改为读 metadata cache。
- fast request snapshot 补 accepted fast-path 常量 metadata，避免触发 lazy headers materialization。
- fast parser result 补 `HasContentLength`，避免 snapshot metadata 混淆无 CL 与 CL=0。
- H1 parser benchmark 增加 legacy repeated scan vs cached metadata rows，并由
  `test_http_benchmarks` smoke 锁住 marker。

## Verification

- `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `22 total, 22 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `91 total, 91 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- `NEXTPAS_BENCH_FILTER='request metadata' make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - legacy repeated scan: `1320.7 ns/op`
  - cached metadata read: `6.1 ns/op`
- `NEXTPAS_LLHTTP_ROOT=/home/dtamade/projects/fafafa.ccore/third_party/llhttp make -C tests/nextpas.core.http/test_http_benchmarks clean test`
  - `13 total, 13 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Current conclusion

这轮仍在总路线图 `6/6 benchmark/performance`，方向是正确的：优先消除 H1 adapter/server
materialization 热点，而不是在没有 perf counters 的机器上盲改 generated llhttp。

## Commit scope

- Only stage this batch's HTTP H1 parser/server/benchmark/docs/control files.
- Planned commit message: `perf(http): cache h1 request metadata`

## Next step

- 下一批继续 H1 adapter materialization：优先看 callback string materialization / URL path
  allocation / parser body storage 是否还能用 focused row 拆出来。
- raw Pascal llhttp gap 仍待 perf 可用环境运行 flag-matrix 后再处理。
