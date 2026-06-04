# Progress Log: non-101 informational response contract

## Session

- **Scope:** 补齐 H1 response-side non-`101` informational response contract：
  `103 Early Hints` 可先发，后续仍可发送 final `200 OK` 与 body。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `request-side runtime truth`
  -> `response-side informational response contract`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../.claude/worktrees/*`
  - `../.worktrees/*`
  - `../compiler/tests/*`

## Completed work

- 新增 `HTTP_STATUS_EARLY_HINTS = 103`，并让 `HttpStatusText(103)` 返回
  `Early Hints`。
- `nextpas.core.http` facade 现在 re-export `HTTP_STATUS_EARLY_HINTS`。
- `TH1ResponseWriter.WriteHeader` 现在把非 `101` 的 `1xx` 当作 interim
  informational response：立即写出，但不提交 final response。
- `test_http_h1writer` 新增 RED/GREEN proof：`103 Early Hints` 后仍可 final
  `200 OK` + body。
- `test_http_server` 新增 threaded / epoll live proof：wire order 保持
  `103 -> 200 -> body`。
- `test_http_contract` 新增 facade status constant proof。

## Verification

- RED:
  - `make -C tests/nextpas.core.http/test_http_h1writer test`
  - `28/29 passed, 1 failed`
  - failure: `response status must not include a body`
- GREEN:
  - `make -C tests/nextpas.core.http/test_http_h1writer test`
  - `29/29 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server test`
  - `274/274 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_contract test`
  - `29/29 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 本轮提交后，继续 `HttpServer 完成` 主线。
- 下一刀优先选择仍有公开 contract 意义的 response-side 或 backend execution seam；
  benchmark 继续后置，不做全量测试扫射。
