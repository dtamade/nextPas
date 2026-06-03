# Progress Log: http malformed transfer-coding focused expansion

## Session

- **Scope:** 补齐 `Transfer-Encoding: chunked, gzip` 这条
  malformed transfer-coding 在 parser / server 两层的 focused proof，
  继续收口 malformed chunked request security 矩阵。
- **Status:** ready-to-commit

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 当前 batch 没有生产代码改动；这是一轮 focused coverage expansion。

## Completed work

- 审阅现有控制文件与 coverage 矩阵，确认 `chunked, gzip` 这条仍缺 focused parser/server 证据。
- 在 `tests/nextpas.core.http/test_http_h1parser` 落地：
  - `Transfer-Encoding: chunked, gzip` -> parser error
  - `ErrorKind = pekMalformed`
- 在 `tests/nextpas.core.http/test_http_server` 落地：
  - `Transfer-Encoding: chunked, gzip` -> explicit `400`
  - handler 不落地
- 在 `docs/http/API_COVERAGE.md` 固定这条契约证据。
- 同步刷新：
  - `task_plan.md`
  - `findings.md`
  - `progress.md`

## Verification

- `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `83/83 passed`
  - heaptrc：`0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `113/113 passed`
  - heaptrc：`0 unfreed memory blocks`

## Next step

- 不再继续机械堆相邻 malformed EOF 用例。
- 下一批先重新审一遍 parser / server / security 三层差集，只挑真正还没对齐的 case。
- 如果 chunk correctness 主线暂时没有真实缺口，就转回 keep-alive request-tail 契约决策，或者继续 H1 poll-driven phase 2 的设计收口。
