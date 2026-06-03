# Task Plan: nextpas.core.net.server poll-driven session seam

## Goal

把 `nextpas.core.net.server` 从“只有 evented accept”推进到
“foundation 可直接驱动 poll-driven per-connection session”的最小 phase-2 切片，
同时保持现有 HTTP public contract 与 H1 行为不变。

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 net/http runtime 相关文件
- [x] 审阅 `TryRead/TryWrite`、`epoll` backend、`test_net_server`
- [x] 先补 RED / proof：
  - threaded backend 对 poll-driven session 仍回退到 `Run`
  - epoll backend 可以直接驱动 poll-driven session
- [x] GREEN：
  - 在 `net.server.intf` 落地 `ITcpServerPollDrivenSession`
  - 在 `net.server.runtime` 抽出 session creation / execution helper
  - 在 `net.server.epoll` 增加 poll-driven session 直驱路径
- [x] 跑 focused net.server 验证 + heaptrc
- [x] 跑 focused HTTP server 回归 + heaptrc
- [ ] 更新控制文件 / 文档并 path-limited commit

## Scope

- 这轮只落 foundation phase-2 seam，不直接把 H1 改成 poll-driven session。
- blocking session / legacy `ServeConn` 路径必须继续工作。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- `epoll` 不再只是 evented accept backend
- foundation 已具备 per-connection poll-driven session 直驱能力
- 下一批主线收敛为：
  - H1 session 迁移到 poll-driven driver
  - `kqueue`
  - `IOCP`
