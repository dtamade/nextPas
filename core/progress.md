# Progress Log: HTTP security chunked raw-wire coverage batch 5

## Session

- **Scope:** 给 `test_http_security` 补 chunked ingress 的 raw-wire security proof。
- **Status:** completed

## Notes

- `test_http_security` 新增 direct proof：
  - chunked `MaxBodySize` rejects before terminal chunk
  - chunked oversize trailer still uses `MaxHeaderSize`
- 两条新测试首次运行直接通过，说明当前真相是 coverage gap，不是生产 bug。
- 本轮未改 `src/` 生产代码。

## Fresh verification

- `make -C tests/nextpas.core.http/test_http_security clean test`

- 结果：`57/57 passed`，heaptrc `0 unfreed memory blocks`。
