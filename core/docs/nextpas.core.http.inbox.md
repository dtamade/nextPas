# nextpas.core.http Inbox

最近更新：2026-06-03

## 当前批次

- chunk-specific security policy proof 已进一步收紧
- `test_http_security` 现在明确锁定 `Content-Length + Transfer-Encoding: chunked` 冲突返回 `400`，并补齐 malformed chunk extension -> `400`
- `test_http_h1parser` 现在明确锁定 `CL -> TE` / `TE -> CL` 两种顺序的 framing conflict 都是 parser error
- `test_http_server` 现在明确锁定 `CL -> TE` / `TE -> CL` 两种顺序都返回 `400`，且不会进入 handler
- 本轮是覆盖扩充批次，不是生产修复批次；现有实现直接通过新增 focused tests

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `nextpas.core.http.impl.h1.pas` 继续作为默认 H1 transport owner。
- internal registry 当前内建 `hvHttp10` / `hvHttp11` -> H1，client/server 默认版本都是 `hvHttp11`。
- `nextpas.core.http.NewHttpClient` / `NewHttpServer` 仍然支持显式注入 `IHttpTransport` / `IHttpServerTransport`；显式注入优先于 registry 默认解析。
- `http.impl.h1.chunked`、client 复用语义、hijack ownership 三条 H1 correctness 基线仍然保持成立。
- `impl.h1.parser` 现在同时有 request-side chunked decode / invalid size / missing chunk-data CRLF / truncation / CL-TE conflict focused proof。
- `THttpServer` 现在有 inbound chunked request body 解码、跨 chunk 累加 size-limit enforcement、raw-wire malformed chunk rejection、以及 CL-TE conflict rejection focused proof。
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

- 下一步优先审 `trailer` 的契约边界：当前实现大概率会把 trailer 字段混进普通 `Headers`，需要用 RED 先确认，再决定是 reject、ignore，还是补独立 trailer API。
- malformed chunk extension 现在已有 security proof；后续如继续补 chunk 语义，优先考虑 trailer pollution / malformed trailer，而不是再堆普通 extension 兼容 case。
- 后续如果扩协议层，直接在已落地的 registry 上接 H2/H3，而不是重新把默认选择散回 facade/factory。
