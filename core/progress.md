# Progress Log: HTTP runnable examples and README truth pass

## Session

- **Scope:** land runnable HTTP server/client examples and align README with real public API boundaries.
- **Status:** completed

## Notes

- 本轮没有修改生产实现单元；只新增 examples，并修正文档描述。
- `http_hello_server` 证明了 `NewRouter` + `Handle(...)` + `PathParam` + `QueryParam` + `NewHttpServer` 的最小 runnable path。
- `http_get_client` 证明了 `NewHttpClient` + `Get(...)` + body read + header iteration 的最小 runnable path。
- changed-surface 验证已完成：
  - `make -C examples/nextpas.core.http/http_hello_server clean build`
  - `make -C examples/nextpas.core.http/http_get_client clean build`
  - 本地 smoke：启动 `hello_http_server` 后运行 `http_get_client`，默认 URL 返回 `200` 且 body 为 `hello=world / page=1 / path=/hello/world`
