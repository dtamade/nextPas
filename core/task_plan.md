# Task Plan: net.server readiness driver extraction step1

## Goal

把 `nextpas.core.net.server` 当前只存在于 `epoll` backend 里的
readiness-family poll-driven session target 骨架，下沉到 foundation runtime helper，
让这条 seam 真正开始服务 future `kqueue` 复用，而不是继续挂在 `epoll` 私有实现里。

## Checklist

- [x] 重新检查 shared checkout / worktree 状态，只处理 `net.server` / `http` 相关路径
- [x] 审阅 `nextpas.core.net.server.runtime`、`nextpas.core.net.server.epoll`、
      `test_net_server`、`test_http_server`
- [x] 设计最小切口：只抽 readiness-family poll-session target/helper，
      不碰 public HTTP facade，不预先发散到 `IOCP`
- [x] 在 `nextpas.core.net.server.runtime.pas` 落地 foundation-owned
      poll session target + create helper
- [x] 让 `nextpas.core.net.server.epoll.pas` 改为消费 foundation helper
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

- readiness-family driver 的最小公共骨架开始属于 foundation，而不是 `epoll` 私有代码
- future `kqueue` 可以复用同一条 poll-session target/helper 起步
- `HttpServer` 现有 threaded / epoll 契约保持不变，并有 focused tests + heaptrc 证据
