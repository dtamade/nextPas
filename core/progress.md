# Progress Log: HTTP server backend contract surfacing batch 6

## Session

- **Scope:** 把 `HttpServer` runtime backend seam 正式公开进 `THttpServerOptions`。
- **Status:** completed

## Notes

- `src/nextpas.core.http.base.pas` 现在公开 re-export
  `TTcpServerBackend` 与 `TCP_SERVER_BACKEND_*` 常量，并为
  `THttpServerOptions` 新增 `Backend`。
- `src/nextpas.core.http.server.pas` 现在把 `THttpServerOptions.Backend`
  下沉到 `nextpas.core.net.server` foundation。
- `test_http_base` 现在锁定默认 backend。
- `test_http_contract` 现在直接证明：显式 backend 选择不会被 HTTP facade 静默吞掉。

## Fresh verification

- `make -C tests/nextpas.core.http/test_http_base clean test`
- `make -C tests/nextpas.core.http/test_http_contract clean test`
- `make -C tests/nextpas.core.http/test_http_registry clean test`
- `make -C tests/nextpas.core.http/test_http_server clean test`

- 上述命令均已通过，且 heaptrc 均为 `0 unfreed memory blocks`。
