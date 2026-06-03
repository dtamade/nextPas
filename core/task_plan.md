# Task Plan: net.server readiness driver extraction step2

## Goal

继续把 readiness-family runtime glue 从 `nextpas.core.net.server.epoll`
收回到 foundation：

- poll-driven worker completion bridge
- poll-driven session context wrapper

让 future `kqueue` 在接入时不需要复制这三层 glue。

## Checklist

- [x] 重新检查 shared checkout / worktree 状态，只处理 `net.server` / `http` 相关路径
- [x] 审阅 `nextpas.core.net.server.runtime`、`nextpas.core.net.server.epoll`、
      `test_net_server`、`test_http_server`
- [x] 确认切口：不动 completion queue 存储本身，只抽 bridge/context glue
- [x] 在 `nextpas.core.net.server.runtime.pas` 落地：
  - `TTcpServerPollWorkerHandoff`
  - `TTcpServerPollSessionContext`
  - `TTcpServerPollQueuedCompletion`
- [x] 让 `nextpas.core.net.server.epoll.pas` 改为消费 foundation bridge/context helper
- [x] 跑 focused `test_net_server`
- [x] 跑模块 gate `test_http_server`
- [x] 更新文档与控制文件
- [ ] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.net.server.runtime.pas`
  - `src/nextpas.core.net.server.epoll.pas`
  - `docs/net/ARCHITECTURE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改 public HTTP API
- 不改 H1 语义
- 不引入 `IOCP` 新接口
- 不跑全量测试

## Intended outcome

- readiness-family foundation 继续成型，不再只有 poll-session target 被收口
- future `kqueue` 至少可以直接复用：
  - poll session target
  - worker completion bridge
  - session context wrapper
- `HttpServer` 现有 threaded / epoll 契约保持不变，并有 focused tests + heaptrc 证据
