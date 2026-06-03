# Task Plan: HTTP server correctness hardening batch 3

## Goal

继续收紧 `HttpServer` 的 public contract 与 runtime correctness，优先补齐：

- `HttpServer` public constructor/factory 的 fail-fast 输入校验
- chunked ingress `MaxBodySize` 的越线即拒绝语义
- hijack 后异常路径的 ownership contract proof
- threaded foundation 在 wildcard / empty listen addr 下的 shutdown proof

## Checklist

- [x] 用 focused RED 锁定 `nil` handler 必须抛 `EArgumentError`。
- [x] 用 focused RED 锁定 chunked body 超限后不必等待 terminal chunk 即返回 `413`。
- [x] 证明 hijack 后 handler 再抛异常时，server 不补写 `500` 且不回收连接。
- [x] 为 `net.server.threaded` 补 wildcard / empty listen addr shutdown proof。
- [x] 跑 changed-surface focused tests，并确认 heaptrc 无泄漏。
