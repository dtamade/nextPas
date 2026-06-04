# Progress Log: http server options demo smoke

## Session

- **Scope:** 给 `examples/nextpas.core.http/http_server_options_demo`
  新增 focused runnable smoke，锁定 build/run/documented endpoint/oversize
  rejection 这条示例契约。
- **Status:** committed

## Current state

- shared checkout 仍有大量无关 modified / untracked 文件；本轮继续只做
  path-limited 变更。
- 与本轮无关但位于 HTTP 范围内的脏文件仍有：
  - `tests/nextpas.core.http/test_http_client/test_http_client.lpr`

## Completed work

- 新增 `tests/nextpas.core.http/test_http_examples/`：
  - `Makefile`
  - `test_http_examples.lpr`
- smoke 现在会：
  - 从测试内对 example 执行 `make build`
  - 启动外部 example binary 并等待 ready marker
  - 用 `IHttpClient` 验证 `/health`
  - 用 `IHttpClient` 验证 `/hello/world`
  - 用 `IHttpClient` 验证 `POST /echo`
  - 验证 oversize body 被 `413` 拒绝，且不是 handler 自己回包
- 在 [docs/http/API_COVERAGE.md](/home/dtamade/projects/nextPas/core/docs/http/API_COVERAGE.md)
  补充了 example smoke 证据入口。

## Verification

- `make -C tests/nextpas.core.http/test_http_examples clean test`
  - `2/2 passed`
  - heaptrc: `0 unfreed memory blocks`

## Next step

- 若继续留在 HTTP，下一刀最自然的是：
  - 决定是否给 `http_server_options_demo` 再补 Linux-only `epoll` CLI 分支 smoke
  - 或转去更高收益的 server foundation 设计/driver 路线，而不是继续膨胀 chunk 相邻 malformed 子类
