# Progress Log: http facade helper boundary audit

## Session

- **Scope:** 收口 `nextpas.core.http` facade 对 static / websocket helper 的公开边界。
- **Status:** verified
- **Roadmap Position:** `3/6 H1 正确性加固` -> `public surface tightening` -> `facade helper boundary audit`

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做 path-limited 变更。
- 与本轮无关但仍然脏的典型路径包括：
  - `tests/nextpas.core.async/test_async_stress/test_async_stress.lpr`
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`
  - `docs/plans/*.md`
  - `../compiler/tests/*`

## Completed work

- [tests/nextpas.core.http/test_http_static/test_http_static.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_static/test_http_static.lpr)
  已切到经由 `nextpas.core.http` facade 消费 `ServeFile` / `ServeDir`。
- [tests/nextpas.core.http/test_http_websocket/test_http_websocket.lpr](/home/dtamade/projects/nextPas/core/tests/nextpas.core.http/test_http_websocket/test_http_websocket.lpr)
  已切到经由 `nextpas.core.http` facade 消费 `UpgradeWebSocket`、`IWebSocket`、`TWebSocket*` 与 `wsOp*`。
- [src/nextpas.core.http.pas](/home/dtamade/projects/nextPas/core/src/nextpas.core.http.pas)
  新增 static / websocket helper 的最小 facade 转发与 alias/constant re-export。
- [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  已同步 facade helper 边界收口结果，并下调原 helper-boundary gap。

## Verification

- `make -C tests/nextpas.core.http/test_http_static clean test`
  - `9/9 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_websocket clean test`
  - `8/8 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 下一刀不该继续机械补 facade 烟雾，而应回到主线判断：
  - H1 correctness/security 是否还存在单点高价值缺口
  - 若只剩低价值同型补 case，就该准备本阶段收口与路线图换挡
