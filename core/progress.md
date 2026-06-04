# Progress Log: HTTP headers allocation fast path

## Session

- **Scope:** `THttpHeaders` capacity/count optimization + focused header benchmark evidence。
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

- `bench_headers` 新增 `Add 15 headers` 场景，直接覆盖 parser adapter 常用追加路径。
- `test_http_headers` 新增 compaction 语义护栏：删除、`Set_` 去重、再追加后，`Count`、
  `GetAll`、`ForEach`、`Clone` 只暴露有效条目并保持可见顺序。
- `THttpHeaders` 改为 `FCount + EnsureCapacity`：
  - `Add` 几何扩容，不再每个 header `SetLength + 1`。
  - `Set_` / `Del` 不再收缩容量，只清理有效尾部的 managed strings。
  - `FindFirst`、`GetAll`、`ForEach`、`Clone` 都只扫描 `FCount`。

## Verification

- Behavior guard:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - `13 total, 13 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Direct parser/fast gates:
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `88 total, 88 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1fast clean test`
  - `18 total, 18 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmark evidence:
  - `make -C benchmarks/nextpas.core.http/bench_headers clean run`
  - before / after:
    - `Set+Get 5 headers`: `1235.6` -> `924.2 ns/op`
    - `Set+Get 15 headers`: `3233.0` -> `2712.2 ns/op`
    - `Add 15 headers`: `2424.4` -> `1832.8 ns/op`
    - `Get miss (3 headers)`: `58.1` -> `53.9 ns/op`
    - `Get hit (5 headers, last)`: `64.7` -> `61.6 ns/op`
    - `Has (3 headers)`: `49.7` -> `46.0 ns/op`
    - `Clone 10 headers`: `725.9` -> `732.4 ns/op`

## Next step

- 继续 `TH1Parser` adapter allocation reduction：优先审计 URL/header span `SetString`
  与 header lookup normalization，考虑在 headers-complete 阶段缓存 Host、Expect、
  Content-Length、keep-alive 判定。
- 若下一轮证据仍指向 llhttp 状态机本体，再开子代理做 Pascal llhttp port 的 state-machine
  指令路径、branch layout、callback ABI 和 string boundary 深审。
