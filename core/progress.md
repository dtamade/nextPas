# Progress Log: HTTP parser span append fast path

## Session

- **Scope:** `TH1Parser` URL/header span append optimization + split callback proof。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `llhttp adapter allocation reduction`

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

- `test_http_h1parser` 新增 split callback 语义护栏，覆盖 URL、header field、header value
  跨多个 `Execute` 调用的累积。
- `TH1Parser` 新增 `AppendSpan` helper：
  - 首段直接 `SetString` 到目标字段。
  - 后续分片用 `SetLength + Move` 追加。
  - 移除 URL/header callback 里的临时 `LChunk` 和字符串拼接。

## Verification

- Behavior guard:
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Differential parser gate:
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `18 total, 18 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark evidence:
  - baseline: `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - after: `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - confirmation: `make -C benchmarks/nextpas.core.http/bench_h1parser run`
  - llhttp before / confirmation-after:
    - `simple GET`: `1298.0` -> `1208.7 ns/op`
    - `10 headers`: `4704.7` -> `3952.9 ns/op`
    - `POST 1KB body`: `2136.6` -> `1926.7 ns/op`
    - `pipeline 10 reqs`: `11400.4` -> `10668.5 ns/op`

## Next step

- 继续 `llhttp adapter allocation reduction`，但不要继续微调 `AppendSpan` helper；下一刀应看
  server ingress 重复 header lookup / normalization，或 body-heavy request 的 `TBytes` 增长策略。
- 如果后续 benchmark 指向 llhttp state-machine/callback ABI 本体，再开 `gpt-5.5 xhigh` 子代理
  做只读深审。
