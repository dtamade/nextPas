# Progress Log: HTTP router public convenience methods

## Session

- **Scope:** promote router convenience methods into `IHttpRouter` and align examples/docs with the public facade path.
- **Status:** completed

## Notes

- 生产改动只有一处公开契约调整：`src/nextpas.core.http.intf.pas`
  为 `IHttpRouter` 新增 `Get/Post/Put/Delete`。
- focused changed-surface 验证已完成：
  - `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `make -C tests/nextpas.core.http/test_http_router clean test`
  - `make -C examples/nextpas.core.http/http_hello_server clean build`
  - `make -C examples/nextpas.core.http/http_get_client clean build`
- heaptrc 证据：
  - `test_http_contract`：`0 unfreed memory blocks`
  - `test_http_router`：`0 unfreed memory blocks`
