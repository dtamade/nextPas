# Findings: HTTP body reader hot-path copy removal

## What changed

- `IH1Parser` 现在新增：
  - `GetBodySize`
  - `NewBodyReader`
- parser 内部 body 从 `string` 改为 `TBytes` 持有。
- H1 server/client 不再走：
  - `GetBody -> string`
  - `StrToBytes`
  - `CreateBytesStreamFrom`
  这条额外复制路径。

## Performance direction

- 这轮还没有把 request body 变成真正的 socket-backed streaming body。
- 但已经先把“解析完成后再做一次整块复制”的热路径成本去掉一层。
- 这是向更现代 transport-owned body seam 过渡的安全切片，不会先把公开 `IHttpRequest.Body` 契约打碎。

## TDD evidence

- RED 已验证：
  `test_http_h1parser` 编译报 `GetBodySize` / `NewBodyReader` 缺失。
- GREEN 已验证：
  新增 focused proof：
  - `Request body reader view`
  - `Response body reader view`
  且 `test_http_h1parser` / `test_http_client` / `test_http_server` 全通过。
