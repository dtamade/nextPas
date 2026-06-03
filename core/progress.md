# Progress Log: HTTP body reader hot-path copy removal

## Session

- **Scope:** remove one full body copy from the H1 parser -> server/client hot path by exposing parser-owned body reader views.
- **Status:** completed

## Notes

- 生产改动：
  - `src/nextpas.core.http.impl.h1.parser.pas`
  - `src/nextpas.core.http.impl.h1.pas`
- focused changed-surface 验证已完成：
  - `make -C tests/nextpas.core.http/test_http_h1parser clean test`
  - `make -C tests/nextpas.core.http/test_http_client clean test`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
- heaptrc 证据：
  - `test_http_h1parser`：`0 unfreed memory blocks`
  - `test_http_client`：`0 unfreed memory blocks`
  - `test_http_server`：`0 unfreed memory blocks`
