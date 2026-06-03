# Progress Log: HTTP no-body response contract hardening batch 9

## Session

- **Scope:** 收紧 response-side no-body status contract，修正 `204/304` 的 bodyless framing 语义。
- **Status:** completed

## Notes

- `src/nextpas.core.http.impl.h1.writer.pas` 现在新增
  `FNoBodyAllowed` 与 `ResponseMustNotHaveBody`，统一收口
  `1xx` / `204` / `304` no-body status 判断。
- `WriteHeader` 现在不会再给 no-body status 自动注入
  `Transfer-Encoding: chunked`。
- `Write` 现在会拒绝 no-body status 下的 body write，避免错误 response framing
  从 helper 层继续向下扩散。
- `test_http_h1writer` 现在直接证明：
  `204/304` 不注入 chunked，`204` 后续 body write 会抛 `EHttpError`。
- `test_http_server` 现在直接证明：
  `204/304` raw-wire 响应不带 chunked header、不带强制 `Content-Length`，
  也不写 terminal chunk。

## Fresh verification

- `make -C tests/nextpas.core.http/test_http_h1writer clean test`
  - `18/18 passed`
  - heaptrc: `0 unfreed memory blocks`
- `make -C tests/nextpas.core.http/test_http_server clean test`
  - `85/85 passed`
  - heaptrc: `0 unfreed memory blocks`

- 上述命令就是本轮 changed-surface focused 验证入口；结果已在本文件固化。
