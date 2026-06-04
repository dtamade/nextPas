# Task Plan: net.server kqueue backend wiring

## Goal

在上一轮 `platform.io` `kqueue` wake seam 已经补齐的基础上，继续把
`nextpas.core.net.server` readiness-family 主线往前推进一刀：

- 新增 `nextpas.core.net.server.kqueue`
- 让 `kqueue` backend 先落成和 `epoll` 对齐的薄包装
- 接上 `nextpas.core.net.server` facade 的 host-gated builtin registration
- 用 focused test 锁定源码/注册边界真实存在
- 补一个轻量 HTTP gate，确认上层 facade 没被带歪

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `net.server` / `platform.io` 相关路径
- [x] 审阅 `docs/design-conventions.md`、控制文件、`docs/net/ARCHITECTURE.md`
- [x] 先写 RED：给 `test_net_server` 增加 `kqueue backend source contract`
- [x] 新增 `src/nextpas.core.net.server.kqueue.pas`
- [x] 更新 `src/nextpas.core.net.server.pas` 的 uses / builtin registration
- [x] 跑 focused `test_net_server`
- [x] 跑轻量 HTTP module gate `test_http_contract`
- [x] 更新必要架构文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.net.server.kqueue.pas`
  - `src/nextpas.core.net.server.pas`
  - `tests/nextpas.core.net.server/test_net_server/test_net_server.lpr`
  - `docs/net/ARCHITECTURE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改 HTTP public API
- 不跑全量测试

## Intended outcome

- `kqueue` backend 不再只存在于规划文档，而是已经有真实单元与 facade 注册边界
- readiness-family 现在同时有：
  - Linux `epoll` 命名 backend
  - BSD/macOS `kqueue` 命名 backend
  - shared readiness runtime owner
- 剩余缺口进一步收窄到 BSD/macOS 实机 compile/runtime proof 与
  HTTP H1 poll-driven 默认化
