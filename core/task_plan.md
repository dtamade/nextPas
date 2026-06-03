# Task Plan: HTTP server backend contract surfacing batch 6

## Goal

继续收紧 `HttpServer` public contract，让已经下沉到 `nextpas.core.net.server`
foundation 的 runtime backend seam 真正出现在 HTTP public options 里，并有 focused
proof 锁住：

- `THttpServerOptions.Default.Backend`
- `THttpServerOptions.Backend` -> `THttpServer` -> `nextpas.core.net.server`
  的 forwarding 语义

## Checklist

- [x] 审计 `HttpServer` public options 与 runtime foundation 之间的 seam 缺口。
- [x] 先写 RED，确认 `THttpServerOptions` 还没有 backend public seam。
- [x] 做最小实现，把 backend 选择纳入 `THttpServerOptions` 并传到 TCP foundation。
- [x] 跑 changed-surface focused tests 与 heaptrc。
- [x] 更新覆盖矩阵、README、架构文档与控制文件。
