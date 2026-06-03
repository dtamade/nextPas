# Progress Log: HTTP server correctness hardening batch 3

## Session

- **Scope:** 收紧 `HttpServer` public contract 与 body-limit/hijack 边界语义。
- **Status:** completed

## Notes

- `THttpServer` 现在 fail-fast 拒绝 `nil` handler。
- `TH1` chunked ingress 现在在 body 越过 `MaxBodySize` 时立即 `413`，不再等待
  terminal chunk。
- `test_http_server` 现在有 direct proof：
  - chunked request over limit rejects before terminal chunk
  - hijack exception does not write 500 or close handler connection
- `test_http_contract` 现在锁定：
  - `HttpServer rejects nil handler`
- `test_net_server` 现在再补两条 foundation proof：
  - threaded server shutdown with wildcard listen
  - threaded server shutdown with empty listen addr

## Fresh verification

- `timeout 30s make -C tests/nextpas.core.net.server/test_net_server clean test`
- `make -C tests/nextpas.core.http/test_http_contract clean test`
- `make -C tests/nextpas.core.http/test_http_server clean test`
- `make -C tests/nextpas.core.http/test_http_registry clean test`

- 上述命令均通过，且 heaptrc 均为 `0 unfreed memory blocks`。
