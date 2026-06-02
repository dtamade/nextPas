# nextpas.core.http Inbox

最近更新：2026-06-03

## 当前批次

- chunked trailer 契约边界已收紧并落地
- `test_http_h1parser` / `test_http_server` 先用 RED 证明 trailer 字段会污染普通 `Headers`
- parser 现已隔离 trailer 字段：保留初始 `Trailer:` 声明头，但不再把实际 trailer 项混进常规请求头
- 本轮包含生产修复：`nextpas.core.http.impl.h1.parser` 现在在 trailer 阶段忽略对普通 `Headers` 的写入

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `nextpas.core.http.impl.h1.pas` 继续作为默认 H1 transport owner。
- internal registry 当前内建 `hvHttp10` / `hvHttp11` -> H1，client/server 默认版本都是 `hvHttp11`。
- `nextpas.core.http.NewHttpClient` / `NewHttpServer` 仍然支持显式注入 `IHttpTransport` / `IHttpServerTransport`；显式注入优先于 registry 默认解析。
- `http.impl.h1.chunked`、client 复用语义、hijack ownership 三条 H1 correctness 基线仍然保持成立。
- `impl.h1.parser` 现在同时有 request-side chunked decode / invalid size / missing chunk-data CRLF / truncation / CL-TE conflict / trailer isolation focused proof。
- `THttpServer` 现在有 inbound chunked request body 解码、跨 chunk 累加 size-limit enforcement、raw-wire malformed chunk rejection、CL-TE conflict rejection、以及 trailer 不污染请求头 focused proof。
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

- 下一步优先补 trailer 后续边界：malformed trailer、oversize trailer 是否需要更强的 parser/server proof，以及 trailer 是否最终需要显式 public API。
- 当前阶段先保持“ignore trailer fields, preserve Trailer declaration header”的窄契约，不急着扩公开 API。
- 后续如果扩协议层，直接在已落地的 registry 上接 H2/H3，而不是重新把默认选择散回 facade/factory。
