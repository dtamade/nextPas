# Findings: keep-alive request-tail contract decision

## Scope

本轮审计 keep-alive request-tail 现有证据，并把此前标记为 current-truth 的
行为提升为明确 contract。目标是固定 TCP 分段 / pipelining 下的合理语义，
避免后续 malformed hardening 误收紧合法 partial follow-up。

## Confirmed truths

### 1. request-tail contract 三类 framing 均已有证据

已覆盖的首请求 framing：

- fixed-length `Content-Length`
- plain `Transfer-Encoding: chunked`
- trailer-complete chunked request

每类都已有 parser / server / security 中的组合证据：

- garbage tail 不污染当前 request，随后作为 follow-up malformed request 返回 `400`。
- partial follow-up request-line 在 EOF-truncated 时作为 follow-up `400`。
- partial follow-up headers 在 EOF-truncated 时作为 follow-up `400`。
- partial follow-up request-line / headers 在后续字节补全后可合法完成为第二请求。
- valid same-read / same-write pipeline 不污染当前 request，并继续处理第二请求。

### 2. contract 决策

将上述 behavior 固定为 `IHttpServer` / H1 parser 的 keep-alive request-tail
contract：

- 当前 request framing 完成即完成当前 request。
- 未消费 tail bytes 属于下一次 request parse，不得污染当前 request body / headers。
- partial follow-up 不应在还可能补全时被提前判成 malformed。
- 当 follow-up 已经 conclusively malformed 或 EOF-truncated，返回 follow-up `400`。

这个决策更接近 Go/Rust/主流 H1 server 对 TCP stream framing 的处理范式：把
HTTP request framing 与 TCP 分段解耦，而不是因为同包 tail 或半截后续请求提前失败。

### 3. 不新增测试的理由

审计没有发现当前 contract 维度的真实空洞：

- `test_http_h1parser` 已覆盖 same-read isolation、garbage tail、truncated
  follow-up、partial follow-up bridge。
- `test_http_server` 已覆盖 threaded / epoll live server 行为，包括 valid pipeline。
- `test_http_security` 已覆盖 raw-wire garbage / truncated / partial bridge，
  并有 trailer-complete same-write pipeline proof。

因此本轮不新增重复测试，改为运行三个 focused gate 作为 fresh 证据。

## Remaining gaps / risks

- 本轮是契约固定，不是生产行为修改。
- 后续 malformed hardening 必须遵守该 contract：不能把 partial follow-up 误当成当前
  request 的垃圾尾巴。
- 若未来引入 H2/H3 或不同 server backend，必须保持同等 request-tail 隔离原则，
  或在协议文档中明确差异。
