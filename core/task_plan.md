# Task Plan: HTTP server runtime foundation implementation batch 1

## Goal

按已冻结的 runtime 方案落地第一实现批：

- 新增 `nextpas.core.net.server` 通用 skeleton
- 先提供 threaded backend
- 让 `nextpas.core.http.server` 迁移到通用 foundation
- 补齐 hijack / detached connection 的 ownership seam

## Checklist

- [x] 新增 `nextpas.core.net.server.base` / `intf` / `threaded` / facade。
- [x] 让 `THttpServer` 改为组合 `ITcpServer`，不再私有 accept/thread loop。
- [x] 先用 focused RED 锁定 detached connection 语义。
- [x] 修复 foundation 与 HTTP transport 间的 ownership 交接。
- [x] 运行 changed-surface focused tests，并确认 heaptrc 无泄漏。
