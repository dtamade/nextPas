# Progress Log: H1 server header-policy one-shot evaluation

## Session

- **Scope:** H1 server headers-complete policy evaluation and body-ingress benchmark signal.
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 server hot path` -> `metadata/materialization cost`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP server/benchmark/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `API_COVERAGE.md`：没有 public API 变化。
- 子代理只读审视已完成；没有修改工作区。

## Completed work

- 重新跑 `bench_h1parser`，确认 raw/no-op/adapter 分层仍显示当前栈内瓶颈在 adapter/server materialization。
- `bench_fullchain` 新增 `/sink` 16KB POST body 场景，用来观察多 read-loop body ingress。
- 修复 `AdvancePollRequestParse` 中 `case LReadResult of` 缺失结束符，恢复 server/fullchain 构建。
- 新增 `HeaderPolicyErrorStatus`，把 headers-stage policy 收口成 shared helper。
- threaded `Run` 与 poll/epoll `AdvancePollRequestParse` 均在 headers 首次完成时执行 host/expect/declared-CL/header-size 判定。
- body-size progress、trailer-size progress、parser error progress 仍保留在 read loop 内。

## Verification

- Diagnostic parser benchmark:
  - `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - raw/no-op rows remain close; adapter rows remain materially slower.
- Full-chain benchmark baseline:
  - initial `make -C benchmarks/nextpas.core.http/bench_fullchain clean run` exposed existing compile blocker at `src/nextpas.core.http.impl.h1.pas:1807`.
  - after syntax fix / before one-shot policy: 16KB sink `998 ms`, `5005 req/s`.
- Full-chain benchmark confirmation:
  - `make -C benchmarks/nextpas.core.http/bench_fullchain clean run`
  - 16KB sink `910 ms`, `5488 req/s`.
- Focused server gate:
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `274 total, 274 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Focused security gate:
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `242 total, 242 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`

## Current conclusion

方向没有走偏：本轮没有把性能问题泛化成大重构，而是先修复 server/fullchain 构建阻塞，再把明确重复的
headers-stage checks 移到一次性执行点。语义由 threaded/epoll server focused gate 覆盖，16KB body
sink row 显示该优化对多 read-loop request body 有方向性收益。

Pascal translated llhttp 仍不能直接下 parity 结论；下一批应落 C llhttp comparator，补齐用户指出的核心证据缺口。

## Next step

- 下一批优先实现 `bench_h1parser/compare_c` same-payload C llhttp comparator，固定 llhttp `9.4.1` 并镜像 raw/no-op/pipeline rows。
- comparator 完成后再决定是否继续深入 parser adapter metadata cache、body reader zero-copy snapshot 或 header insert internal fast path。
