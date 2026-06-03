# nextpas.core.http Inbox

最近更新：2026-06-03

## 当前批次

- 本轮继续补 raw-wire malformed chunk framing proof：`terminal 0 chunk` 后空 trailer section 的最终 CRLF 缺失，现在也已在 parser/server/security 三层有 focused 证据，server 语义锁成显式 `400`
- 这轮没有新增生产修复；当前 parser/H1 transport 已能安全拒绝该类 terminal-chunk ending 截断，本轮主要是把 current truth 锁进回归
- 本轮继续补 raw-wire malformed chunk framing proof：`chunk-size line EOF truncation` 现在也已在 parser/server/security 三层有 focused 证据，server 语义锁成显式 `400`
- 这轮没有新增生产修复；当前 parser/H1 transport 已能安全拒绝该类 chunk framing 截断，本轮主要是把 current truth 锁进回归
- 本轮继续补 keep-alive request-tail contract proof：`Content-Length` 首请求后紧跟 garbage tail 的 parser/security 证据现在也已补齐
- 这轮没有新增生产修复；当前 parser/H1 transport 已经会把 fixed-length 首请求先完整交付，再把尾巴作为 follow-up malformed request 处理，本轮主要是把 current truth 锁进回归
- 本轮继续补 keep-alive / pipelined request isolation proof：`chunked` 首请求后紧跟同包下一请求的 same-read / same-write 路径，现在都在 parser/server 两层有 focused 证据
- 这轮没有新增生产修复；当前 parser/H1 transport 已经会把首个 chunked request 与后续 pipelined request 正确隔离，本轮主要是把 current truth 锁进回归
- 本轮继续做 raw-wire malformed chunked request security proof：`invalid chunk size`、`malformed chunk extension`、`truncated chunked EOF` 现在也都在 parser/server/security 三层有 focused 证据，server 语义锁成显式 `400`
- 这轮没有新增生产修复；当前 parser/H1 transport 已能安全拒绝该类异常 chunk framing，本轮主要是把 current truth 锁进回归
- 本轮继续做 raw-wire malformed chunked request security proof：`chunked + Connection: close + extra bytes after terminal chunk` 现在也在 parser/server/security 三层有 focused 证据，server 语义锁成显式 `400`
- 这轮没有新增生产修复；当前 parser/H1 transport 已能安全拒绝该类异常 tail overrun，本轮主要是把 current truth 锁进回归
- 本轮继续做 raw-wire malformed chunked request security proof：`missing chunk-data CRLF` 现在也在 server/security 两层有 focused 显式 `400` 证据
- 这轮没有新增生产修复；当前 parser/H1 transport 已能安全拒绝该类异常 chunk framing，本轮主要是把 current truth 锁进回归
- 本轮新增生产修复：同一 read 中若首个完整 request 后还跟着下一个 pipelined request，H1 parser 现在只消费首个 request，不再让后续字节污染当前 request 的 method/url/body
- 本轮新增生产修复：H1 server transport 现在会保留单连接上的未消费尾巴，并把同一 write 里的第二个 request 留到下一轮分发；首个 response 不再误吃后续请求帧
- 本轮新增生产修复：upgrade/hijack 场景下如果 WebSocket 握手和首帧同包到达，H1 server 现在会把 read-ahead 尾巴继续交给 hijacked `ITcpStream`，首帧不再丢失
- 本轮 focused proof 继续扩到 parser/server 两层，并守住 `Connection: close` 下 `Content-Length` body 结束后 extra bytes 仍显式拒绝的旧契约
- 本轮新增生产修复：`Content-Length` 请求在声明 body 结束后若仍携带额外字节，且同一请求显式 `Connection: close`，parser 现在会把该输入保持为 error/not-complete，server 统一返回显式 `400`
- 这轮 focused proof 已补齐到 parser/server/security 三层；handler 不会落地
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
- `impl.h1.parser` 现在同时有 request-side chunked decode / invalid size / malformed chunk extension / missing chunk-data CRLF / truncation / `Connection: close` terminal-chunk tail overrun / CL-TE conflict / trailer isolation focused proof。
- `impl.h1.parser` 现在也有 `chunk-size line EOF truncation` focused proof。
- `impl.h1.parser` 现在也有 `terminal 0 chunk ending EOF truncation` focused proof。
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
- `impl.h1.parser` 现在也有 `Content-Length + Connection: close + extra bytes after body` parser error focused proof。
- `impl.h1.parser` 现在也有 keep-alive `Content-Length` garbage tail focused proof：首个合法 fixed-length request 只消费自己的字节，不会被后续垃圾尾巴污染。
- `impl.h1.parser` 现在也有 keep-alive chunked garbage tail focused proof：首个合法 chunked request 只消费自己的字节，不会被后续垃圾尾巴污染。
- `impl.h1.parser` 现在也有 `chunked first request + same-read pipelined next request` focused proof：只消费首个完整 chunked request，不会被同包后续 request 污染。
- `impl.h1.parser` 现在也有 `same-read pipelined next request does not pollute current request` focused proof。
- `THttpServer` 现在有 inbound chunked request body 解码、跨 chunk 累加 size-limit enforcement、raw-wire malformed chunk rejection、generic malformed request 显式 `400` rejection、`HTTP/1.1 missing Host` 显式 `400` rejection、`HTTP/1.0 missing Host` 仍允许的 focused 回归、`HTTP/0.9 / no-version` 显式 `400` rejection、`CRLF injection / request-line splitting` 显式 `400` rejection、`negative Content-Length` 显式 `400` rejection、`very long method` 显式 `400` rejection、`Content-Length + Connection: close + extra bytes after body` 显式 `400` rejection、`chunked + Connection: close + extra bytes after terminal chunk` 显式 `400` rejection、CL-TE conflict rejection、duplicate `Content-Length` 显式 `400` rejection、`null-byte header` 显式 `400` rejection、malformed chunk extension 显式 `400` rejection、missing chunk-data CRLF 显式 `400` rejection、trailer 不污染请求头、oversize trailer 触发 `431`/安全关闭且 handler 不落地、malformed trailer 显式 `400` proof、fixed-length request EOF truncation 显式 `400` proof、以及 request-line / headers EOF truncation 显式 `400` proof。
- `THttpServer` 现在也有非 `Connection: close` `Content-Length` garbage tail focused 现状证据：首个合法 request 仍按声明长度进入 handler，尾巴会在同连接上作为后续 malformed request 返回 `400`；这条目前记为 transport current truth，尚未上升为最终收紧契约。
- `THttpServer` 现在也有 keep-alive chunked garbage tail focused 现状证据：首个合法 chunked request 会先完成并进入 handler，尾巴会在同连接上作为后续 malformed request 返回 `400`；这条同样先记为 transport current truth，尚未上升为最终收紧契约。
- `THttpServer` 现在也有 `chunked first request + same-write pipelined next request` focused proof：首个 chunked request 的 handler/response/body 与第二个 request 保持分离，第二个 request 仍会在同连接上继续完成。
- `THttpServer` 现在也有 `same-write pipelined requests` focused proof：首个 request 的 body/handler/response 不会被第二个 request 污染，第二个 request 仍会在同连接上继续完成。
- `THttpServer` 现在也有 `chunk-size line EOF truncation` focused proof：peer half-close 后返回显式 `400`，且不进入 handler。
- `THttpServer` 现在也有 `terminal 0 chunk ending EOF truncation` focused proof：peer half-close 后返回显式 `400`，且不进入 handler。
- `test_http_security` 现在也有 generic malformed request、`HTTP/1.1 missing Host`、`HTTP/0.9 / no-version`、`CRLF injection / request-line splitting`、`negative Content-Length`、`very long method`、`Content-Length + Connection: close + extra bytes after body`、`chunked + Connection: close + extra bytes after terminal chunk`、duplicate `Content-Length`、`null-byte header`、invalid chunk size、malformed chunk extension、missing chunk-data CRLF、truncated chunked EOF、malformed trailer、fixed-length request EOF truncation、以及 request-line / headers EOF truncation 的 raw-wire explicit `400` proof；同时也有 keep-alive chunked garbage tail 的 safe-handling proof：首个请求完成，尾巴 follow-up `400`。
- `test_http_security` 现在也有 `terminal 0 chunk ending EOF truncation` 的 raw-wire explicit `400` proof。
- `test_http_security` 现在也有 `chunk-size line EOF truncation` 的 raw-wire explicit `400` proof。
- `test_http_security` 现在也有 keep-alive `Content-Length` garbage tail 的 safe-handling proof：首个请求完成，尾巴 follow-up `400`。
- `test_http_websocket` 现在也有 `upgrade request + first frame in one write` focused regression proof，锁定 hijack 后 read-ahead 尾巴不会丢失。
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

- 下一步优先把 keep-alive request-tail 契约定下来：当前 parser/server/security focused 证据已经覆盖 `Content-Length` tail、chunked tail、以及 fixed-length/chunked 首请求后的 same-read / same-write truth；接下来需要决定这些行为哪些保留为 transport truth，哪些继续系统性收紧成更早的显式拒绝。
- 同时继续补剩余 raw-wire malformed chunk framing 变体是否都稳定落在显式 `400` 或安全关闭语义，并继续评估 trailer 是否最终需要显式 public API。
- 当前阶段先保持“ignore trailer fields, preserve Trailer declaration header”的窄契约，不急着扩公开 API。
- 后续如果扩协议层，直接在已落地的 registry 上接 H2/H3，而不是重新把默认选择散回 facade/factory。
