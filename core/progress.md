# Progress Log: HTTP server runtime foundation implementation batch 2

## Session

- **Scope:** 继续收口 threaded foundation 的稳定性，并补平 HTTP transport contract 边角。
- **Status:** completed

## Notes

- `nextpas.core.net.server.threaded` 现在会隔离单连接 handler 异常。
- detached worker 和 inline fallback 都不再让异常打穿 accept loop。
- `test_net_server` 新增 focused proof：
  - handler exception after first connection does not stop accept loop
- `nextpas.core.http.intf` / `nextpas.core.http` 现在 re-export
  `TTcpServerConnOwnership` 与对应常量。
- `test_http_contract` / `test_http_registry` 现在可去掉
  `nextpas.core.net.server` 依赖，直接证明 facade/intf 自包含。

## Fresh verification

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
- `make -C tests/nextpas.core.http/test_http_server clean test`
- `make -C tests/nextpas.core.http/test_http_contract clean test`
- `make -C tests/nextpas.core.http/test_http_registry clean test`

- 上述命令均通过，且 heaptrc 均为 `0 unfreed memory blocks`。
