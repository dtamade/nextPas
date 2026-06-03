# Findings: HTTP server runtime architecture freeze batch 4

## Root causes

- runtime 方向虽然已经在讨论里达成一致，也已有 `nextpas.core.net.server`
  foundation 与 `http.server` facade 化落地，但正式文档入口还不够清晰。
- 现状是方案主要留在 `docs/plans/2026-06-03-http-server-runtime-foundation.md`，
  这更像决策记录，不够适合作为长期 canonical architecture。
- `docs/net/README.md` 与 `docs/http/ARCHITECTURE.md` 也还没有把
  `nextpas.core.net.server` 作为 runtime owner 讲清楚，后续很容易再次误判
  “HTTPServer 是否固定只能线程驱动”。

## Fixed design truth

- 正式架构入口现在是 `docs/net/ARCHITECTURE.md`，它固定了三层选型：
  - public model: Go-like
  - internal runtime/protocol split: Tokio/Hyper-like
  - backend strategy: libuv-like (`epoll` / `kqueue` / `IOCP`)
- `nextpas.core.net.server` 被正式固定为 reusable TCP server runtime foundation；
  `nextpas.core.http` 只拥有 HTTP protocol semantics，不拥有线程模型或 event loop。
- `docs/http/ARCHITECTURE.md` 现在明确：
  - `http.server` 是 facade
  - `IHttpServerTransport` 是 per-connection protocol seam
  - ownership 通过 `TTcpServerConnOwnership` 与 TCP foundation 对齐
- 原 `docs/plans/2026-06-03-http-server-runtime-foundation.md` 保留为决策记录，
  但已加 canonical pointer，不再作为唯一真相来源。

## Why this is the right fix

- 这次先固定 foundation ownership，比直接争论“线程模型现代不现代”更有效。
- 先把 public contract、protocol seam、backend target 讲清楚，后续实现
  `epoll/kqueue/IOCP` 才不会反复推翻 HTTP public API。
- 让 `net.server` 成为通用运行时 owner，也避免其他 TCP 协议模块未来再次重复造
  accept/runtime 轮子。
