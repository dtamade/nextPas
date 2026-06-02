# nextpas.core.http Inbox

最近更新：2026-06-03

## 当前批次

- raw-wire malformed chunked request focused coverage 已扩充完成
- `test_http_h1parser` 已补齐 missing chunk-data CRLF proof，并继续保持 invalid chunk-size / truncated EOF proof
- `test_http_server` 已补齐 invalid chunk-size -> `400`、truncated EOF -> `400` 或安全关闭、且异常 chunk 不进入 handler 的 proof
- 本轮是覆盖扩充批次，不是生产修复批次；现有实现直接通过新增 focused tests

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `nextpas.core.http.impl.h1.pas` 继续作为默认 H1 transport owner。
- internal registry 当前内建 `hvHttp10` / `hvHttp11` -> H1，client/server 默认版本都是 `hvHttp11`。
- `nextpas.core.http.NewHttpClient` / `NewHttpServer` 仍然支持显式注入 `IHttpTransport` / `IHttpServerTransport`；显式注入优先于 registry 默认解析。
- `http.impl.h1.chunked`、client 复用语义、hijack ownership 三条 H1 correctness 基线仍然保持成立。
- `impl.h1.parser` 现在同时有 request-side chunked decode / invalid size / missing chunk-data CRLF / truncation focused proof。
- `THttpServer` 现在有 inbound chunked request body 解码、跨 chunk 累加 size-limit enforcement、以及 raw-wire malformed chunk rejection focused proof。
- registry 目前保持内部实现边界；在 H2/H3 真正进入实现前，不急着把它抬成 facade API。
- benchmark 继续后置，先补 correctness 与契约边界。

## 路线图

1. 接管与基线
2. 公开契约审计
3. H1 正确性加固
4. Server/Client 集成加固
5. 文档与示例
6. Benchmark 与优化

## 下一步

- `test_http_security` 仍以 broad safe-handling 为主；下一步可收紧 chunk-specific cases，例如 `Content-Length + Transfer-Encoding` 冲突、chunk extension/trailer malformed 语义。
- 后续如果扩协议层，直接在已落地的 registry 上接 H2/H3，而不是重新把默认选择散回 facade/factory。
