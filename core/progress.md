# Progress Log: HTTP server runtime foundation implementation batch 1

## Session

- **Scope:** 落地 `nextpas.core.net.server` 第一批实现，并完成 HTTP server 迁移。
- **Status:** completed

## Notes

- 新增 `nextpas.core.net.server` skeleton 与 threaded backend。
- `THttpServer` 现在通过 `ITcpServer` 运行；HTTP transport 不再私有 accept loop。
- 补上 detached / hijack ownership seam，修复 handler 接管连接后仍被 runtime
  自动关闭的回归。
- focused coverage 现在包含：
  - `test_net_server` 的 detached connection proof
  - `test_http_contract` 的 `IHttpServerTransport.ServeConn` ownership shape
  - `test_http_server` 的 hijack ownership regression
  - `test_http_websocket` 的 coalesced first-frame hijack proof

## Fresh verification

- `make -C tests/nextpas.core.net.server/test_net_server clean test`
- `make -C tests/nextpas.core.http/test_http_contract clean test`
- `make -C tests/nextpas.core.http/test_http_registry clean test`
- `make -C tests/nextpas.core.http/test_http_server clean test`
- `make -C tests/nextpas.core.http/test_http_websocket clean test`

- 上述命令均通过，且 heaptrc 均为 `0 unfreed memory blocks`。
