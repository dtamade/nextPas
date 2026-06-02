# nextpas.core.http Inbox

最近更新：2026-06-03

## 当前批次

- chunked trailer 契约边界已收紧并落地
- `test_http_h1parser` / `test_http_server` 先用 RED 证明 trailer 字段会污染普通 `Headers`
- parser 现已隔离 trailer 字段：保留初始 `Trailer:` 声明头，但不再把实际 trailer 项混进常规请求头
- 本轮包含生产修复：`nextpas.core.http.impl.h1.parser` 现在在 trailer 阶段忽略对普通 `Headers` 的写入
- 本轮继续包含生产修复：chunked trailer 即使在后续 read 才到达，也会继续受 `MaxHeaderSize` 约束；超限时 server 返回 `431` 或安全关闭，且不进入 handler
- 本轮再补 malformed trailer security proof：非法 trailer field-name 与 trailer section EOF 截断，都已在 parser/server/security 三层得到 focused proof
- 这轮没有新增生产修复；现有 parser/H1 transport 已能安全拒绝上述 malformed trailer 输入
- 本轮新增生产修复：对“客户端 half-close 后暴露出的部分 chunked/trailer 请求 EOF 截断”，H1 server 现在会先 `Finish` parser，再统一走显式 `400`，不再只是静默关闭
- 本轮继续补 partial-request EOF 覆盖：`Content-Length` request body EOF 截断 现在也在 parser/server/security 三层有 focused proof
- 这轮没有新增生产修复；`Content-Length` request EOF case 是上一轮 EOF 修复顺带覆盖到的 current truth 收口
- 本轮继续补 partial-request EOF 覆盖：`incomplete request-line` / `incomplete headers` EOF 现在也在 parser/server/security 三层有 focused proof
- 这轮没有新增生产修复；这两类 case 也是上一轮 EOF 修复顺带覆盖到的 current truth 收口
- 本轮继续补 malformed request 收口：`duplicate Content-Length` 现在也在 parser/server/security 三层有 focused proof，并已从旧的“拒绝或关闭”口径收紧成显式 `400`
- 这轮没有新增生产修复；当前 parser/H1 transport 已经会拒绝 duplicate `Content-Length`
- 本轮继续补 malformed request 收口：`null-byte header` 现在也在 parser/server/security 三层有 focused proof，并已从旧的“拒绝或关闭”口径收紧成显式 `400`
- 这轮没有新增生产修复；当前 parser/H1 transport 已经会拒绝 header 中的 NUL 字节
- 本轮继续补 malformed request 收口：generic malformed request 现在也在 parser/server/security 三层有 focused proof，并已从旧的“`400` 或关闭”口径收紧成显式 `400`
- 这轮没有新增生产修复；当前 parser/H1 transport 已经会对 generic malformed request 返回 parser error / 显式 `400`
- 本轮继续补 legacy request 语义收口：`HTTP/1.1 missing Host` 现在在 server/security 两层有 focused proof，并已从旧的 broad safe-handling 收紧成显式 `400`
- 本轮包含生产修复：H1 server 现在会在请求分发前拒绝缺失 `Host` 的 HTTP/1.1 请求；同时 `HTTP/1.0 missing Host` focused 回归也已补齐，确保未被误伤
- 本轮继续补 legacy request 语义收口：`HTTP/0.9 / no-version` 现在在 parser/server/security 三层有 focused proof，并已从旧的 broad safe-handling 收紧成显式 `400`
- 本轮包含生产修复：H1 parser 现在会直接拒绝不带 HTTP version 的 request-line；server 对该类请求也稳定返回显式 `400`
- 本轮继续补 legacy request 语义收口：`CRLF injection / request-line splitting` 现在在 parser/server/security 三层都有 focused proof，并已从旧的 broad safe-handling 收紧成显式拒绝契约
- 这轮没有新增生产修复；上一轮 `HTTP/0.9 / no-version` 拒绝修复已经把该类 split request 一并收口，这轮主要是把 current truth 锁进测试
- 本轮继续补 malformed ingress 收口：`negative Content-Length` 与 `very long method` 现在在 parser/server/security 三层都有 focused proof，并已从旧的 broad safe-handling 收紧成显式 `400`
- 这轮没有新增生产修复；当前 parser/H1 transport 已经会直接拒绝这两类输入，这轮主要是把 current truth 锁进测试

## 当前重点

- 覆盖矩阵在 `docs/http/API_COVERAGE.md`，inbox 只保留路线状态。
- `nextpas.core.http.impl.h1.pas` 继续作为默认 H1 transport owner。
- internal registry 当前内建 `hvHttp10` / `hvHttp11` -> H1，client/server 默认版本都是 `hvHttp11`。
- `nextpas.core.http.NewHttpClient` / `NewHttpServer` 仍然支持显式注入 `IHttpTransport` / `IHttpServerTransport`；显式注入优先于 registry 默认解析。
- `http.impl.h1.chunked`、client 复用语义、hijack ownership 三条 H1 correctness 基线仍然保持成立。
- `impl.h1.parser` 现在同时有 request-side chunked decode / invalid size / missing chunk-data CRLF / truncation / CL-TE conflict / trailer isolation focused proof。
- `impl.h1.parser` 现在也有 late trailer byte accounting focused proof，用来支撑 server 对 trailer header budget 的后续判定。
- `impl.h1.parser` 现在也有 malformed trailer grammar / trailer EOF truncation focused proof。
- `impl.h1.parser` 现在也有 request-side fixed-length body EOF truncation focused proof。
- `impl.h1.parser` 现在也有 request-line / headers EOF truncation focused proof。
- `impl.h1.parser` 现在也有 duplicate `Content-Length` parser error focused proof。
- `impl.h1.parser` 现在也有 `null-byte header` parser error focused proof。
- `impl.h1.parser` 现在也有 generic malformed request parser error focused proof。
- `impl.h1.parser` 现在也有 `HTTP/0.9 / no-version` parser error focused proof。
- `impl.h1.parser` 现在也有 `CRLF injection / request-line splitting` parser error focused proof。
- `impl.h1.parser` 现在也有 `negative Content-Length` 与 `very long method` parser error focused proof。
- `THttpServer` 现在有 inbound chunked request body 解码、跨 chunk 累加 size-limit enforcement、raw-wire malformed chunk rejection、generic malformed request 显式 `400` rejection、`HTTP/1.1 missing Host` 显式 `400` rejection、`HTTP/1.0 missing Host` 仍允许的 focused 回归、`HTTP/0.9 / no-version` 显式 `400` rejection、`CRLF injection / request-line splitting` 显式 `400` rejection、`negative Content-Length` 显式 `400` rejection、`very long method` 显式 `400` rejection、CL-TE conflict rejection、duplicate `Content-Length` 显式 `400` rejection、`null-byte header` 显式 `400` rejection、trailer 不污染请求头、oversize trailer 触发 `431`/安全关闭且 handler 不落地、malformed trailer 显式 `400` proof、fixed-length request EOF truncation 显式 `400` proof、以及 request-line / headers EOF truncation 显式 `400` proof。
- `test_http_security` 现在也有 generic malformed request、`HTTP/1.1 missing Host`、`HTTP/0.9 / no-version`、`CRLF injection / request-line splitting`、`negative Content-Length`、`very long method`、duplicate `Content-Length`、`null-byte header`、malformed trailer、fixed-length request EOF truncation、以及 request-line / headers EOF truncation 的 raw-wire explicit `400` proof。
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

- 下一步优先判断 `body larger than Content-Length` 这类目前仍保留 broad safe-handling 的 ingress case，究竟应该维持“严格按声明长度读取并安全丢弃/关闭”还是继续系统性收紧成显式契约；同时继续判断 trailer 是否最终需要显式 public API。
- 当前阶段先保持“ignore trailer fields, preserve Trailer declaration header”的窄契约，不急着扩公开 API。
- 后续如果扩协议层，直接在已落地的 registry 上接 H2/H3，而不是重新把默认选择散回 facade/factory。
