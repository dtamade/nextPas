# Task Plan: HTTP no-body response contract hardening batch 9

## Goal

继续收紧 `TH1ResponseWriter` / `HttpServer` 的 response-side framing contract，
把 no-body status 的语义锁到 focused proof：

- `204 No Content` 不自动注入 `Transfer-Encoding: chunked`
- `304 Not Modified` 不自动注入 `Transfer-Encoding: chunked`
- no-body status 不写 terminal chunk，也不强行补 `Content-Length`
- 显式 no-body status 后续 body write 会被拒绝
- server raw-wire 直接证明 `204/304` 都保持 bodyless 响应

## Checklist

- [x] 审计 writer 默认 chunked 注入路径与 server 当前 response wire 行为。
- [x] 补 focused tests，锁定 `204/304` no-body framing 与 no-body body-write rejection。
- [x] 保持实现最小化：contract 收在 writer 状态机，不在 server 层做分散补丁。
- [x] 跑 changed-surface focused tests 与 heaptrc。
- [x] 更新覆盖矩阵与控制文件。
