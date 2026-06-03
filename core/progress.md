# Progress Log: HTTP router head/patch/options convenience methods

## Session

- **Scope:** publish `Head/Patch/Options` on `IHttpRouter` / `THttpRouter` and align docs with the public router surface.
- **Status:** completed

## Notes

- 生产改动：
  - `src/nextpas.core.http.intf.pas`
  - `src/nextpas.core.http.router.pas`
- focused changed-surface 验证已完成：
  - `make -C tests/nextpas.core.http/test_http_contract clean test`
  - `make -C tests/nextpas.core.http/test_http_router clean test`
  - `make -C examples/nextpas.core.http/http_hello_server clean build`
  - `make -C examples/nextpas.core.http/http_get_client clean build`
- heaptrc 证据：
  - `test_http_contract`：`0 unfreed memory blocks`
  - `test_http_router`：`0 unfreed memory blocks`
