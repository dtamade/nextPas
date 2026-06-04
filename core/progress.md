# Progress Log: Header name normalization fast path

## Session

- **Scope:** `THttpHeaders` lowercase name validation/normalization fast path。
- **Status:** verified
- **Roadmap Position:** `6/6 benchmark/performance` -> `H1 parser adapter materialization`

## Current state

- shared checkout 仍有大量无关 dirty/untracked 文件；本轮只 path-limited 处理 HTTP headers/test/docs/control 文件。
- 本轮没有写 `docs/nextpas.core.http.inbox.md`。
- 本轮不改 `API_COVERAGE.md`：没有 public API 变化。

## Completed work

- `test_http_headers` 增加 invalid name/value validation guard。
- `THttpHeaders` 新增 combined `ValidateNameAndNeedsNormalize`。
- `Add` / `Set_` 在 lowercase valid name 下避免额外 `Normalize` scan/copy。
- `Del` 使用 `NormalizeIfNeeded`，lowercase delete 避免额外 copy。

## Verification

- Guard:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - pre-production guard passed with old implementation.
- Focused tests:
  - `make -C tests/nextpas.core.http/test_http_headers clean test`
  - `15 total, 15 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `89 total, 89 passed, 0 failed`
  - heaptrc: `0 unfreed memory blocks`
- Benchmarks:
  - baseline `make -C benchmarks/nextpas.core.http/bench_headers clean run`
  - after `make -C benchmarks/nextpas.core.http/bench_headers clean run`
  - confirmation `make -C benchmarks/nextpas.core.http/bench_headers run`
  - `Set+Get 5 headers`: `828.2 -> 784.3 ns/op`
  - `Set+Get 15 headers`: `2665.1 -> 2516.8 ns/op`
  - `Add 15 headers`: `1783.5 -> 1635.8 ns/op`
  - projection `make -C benchmarks/nextpas.core.http/bench_h1parser clean run`
  - `llhttp adapter 10 headers`: `3324.8 ns/op`

## Current conclusion

方向正确：headers lowercase hot path 成本下降，public validation/case-insensitive contract 保持。完整 H1 parser
收益较小，说明下一步应继续向 parser/server metadata cache 或 callback string materialization 推进。

## Next step

- 优先设计并实现 request metadata cache，避免 server hot path 多次从 headers 中重新解析
  `Content-Length` / `Transfer-Encoding` / `Expect` / `Connection`。
- 或先给 parser callback field/value append 做更细 stage benchmark，避免在不确定热点上盲改。
