# Progress Log: HTTP request transfer-coding contract hardening batch 8

## Session

- **Scope:** 收紧 request-side `Transfer-Encoding` 语义，拒绝 unsupported transfer-coding。
- **Status:** completed

## Notes

- `src/nextpas.core.http.impl.h1.parser.pas` 现在会把
  `Transfer-Encoding: gzip, chunked` 这类 unsupported request coding
  直接标记为 `pekUnsupportedTransferCoding`，不再误当成普通 chunked request。
- `src/nextpas.core.http.impl.h1.pas` 现在只把
  `pekUnsupportedTransferCoding` 分流成 `501 Not Implemented`；
  `chunked` 非最终 coding 等 malformed framing 仍保持 `400 Bad Request`。
- `src/nextpas.core.http.base.pas` 现在公开
  `HTTP_STATUS_NOT_IMPLEMENTED = 501`，并锁定状态文本 `Not Implemented`。
- `test_http_h1parser`、`test_http_security`、`test_http_contract`
  已分别锁定 parser 分类、raw-wire server status、以及 public status text。

## Fresh verification

- `make -C tests/nextpas.core.http/test_http_h1parser clean test`
- `make -C tests/nextpas.core.http/test_http_security clean test`
- `make -C tests/nextpas.core.http/test_http_contract clean test`

- 上述命令已作为本轮 changed-surface focused 验证入口；结果见本轮收尾报告。
