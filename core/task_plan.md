# Task Plan: HTTP server lifecycle contract surfacing batch 7

## Goal

继续收紧 `HttpServer` public contract，把已经由 `THttpServer` 实际提供的
生命周期状态也真正收进 `IHttpServer` 公开契约，并用 focused proof 锁住：

- `IHttpServer.IsRunning`
- pre-listen `IHttpServer.LocalAddr`
- pre-listen `IHttpServer.Shutdown` 的安全语义

## Checklist

- [x] 审计 `IHttpServer` 与 `THttpServer` 生命周期 public seam 缺口。
- [x] 先写 RED，确认 `IHttpServer` 还没有 `IsRunning` public contract。
- [x] 做最小实现，把 `IsRunning` 收进 `IHttpServer`，不改运行时实现。
- [x] 跑 changed-surface focused tests 与 heaptrc。
- [x] 更新覆盖矩阵、README、架构文档与控制文件。
