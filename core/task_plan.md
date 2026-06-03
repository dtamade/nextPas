# Task Plan: nextpas.core.net.server backend provider seam

## Goal

在不改 HTTP public contract 的前提下，把 `nextpas.core.net.server`
从“facade 内硬编码 backend case”推进到“可注册的 backend factory seam”，
为后续 phase-2 per-connection evented driver、`kqueue`、`IOCP` 留出稳定入口。

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 net/http runtime 相关文件
- [x] 审阅 `src/nextpas.core.net.server.pas` 与 `tests/nextpas.core.net.server/test_net_server`
- [x] 先补 RED：
  - built-in threaded backend factory 存在
  - custom backend factory 可以覆盖 backend 解析
  - missing backend factory 仍抛 `ENotSupportedError`
- [x] GREEN：
  - 在 `nextpas.core.net.server` 落地 `TTcpServerFactory`
  - 增加 register / unregister / try-get / resolve seam
  - built-in threaded / epoll 改为初始化注册
- [x] 跑 focused net.server 验证 + heaptrc
- [x] 跑 focused HTTP registry 回归 + heaptrc
- [x] 更新控制文件 / 文档并 path-limited commit

## Scope

- 这轮是 foundation seam 演进，不是 phase-2 evented driver 落地。
- 不改 `nextpas.core.http.impl.h1` 生产行为。
- 不跑全量测试，不做 benchmark。
- 不碰 shared checkout 里的无关脏文件。

## Intended outcome

- backend 选择不再写死在 `NewTcpServer(...)`
- builtin backend 与 future backend 共享同一种注册入口
- 当前剩余主线收敛为：
  - phase-2 per-connection evented driver
  - `kqueue`
  - `IOCP`
