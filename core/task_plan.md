# Task Plan: platform.io kqueue wake seam

## Goal

补齐 BSD/macOS `kqueue` 分支缺失的 poller wake seam，让
`nextpas.core.net.server.readiness` 不再卡在 host-specific wake stub 上：

- 为 `TPlatformPoller` 增加 `WakeReadFd` / `WakeWriteFd`
- 实现 `platform_poller_enable_wake`
- 实现 `platform_poller_wake`
- 实现 `platform_poller_drain_wake`
- 用 focused test 锁定 source-contract，并确认 Linux readiness 基线不回退

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 `platform.io` / `net.server` 相关路径
- [x] 审阅 `docs/design-conventions.md`、控制文件、`docs/net/ARCHITECTURE.md`
- [x] 先写 RED：给 `test_platform_io` 增加 `kqueue wake` source-contract focused test
- [x] 为 BSD/macOS poller 增加 wake pipe 状态
- [x] 实现 `enable_wake / wake / drain_wake`
- [x] 跑 focused `test_platform_io`
- [x] 跑 module gate `test_net_server`
- [x] 更新必要架构文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.platform.io.base.pas`
  - `src/nextpas.core.platform.io.pas`
  - `tests/nextpas.core.platform.io/test_platform_io/test_platform_io.lpr`
  - `docs/net/ARCHITECTURE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改 HTTP public API
- 不跑全量测试

## Intended outcome

- BSD/macOS `kqueue` poller 不再在 wake 路径上返回 stub
- readiness-family runtime owner 的剩余缺口从 host wake seam 缩到
  `net.server.kqueue` backend 真正接线与实机验证
- 现有 Linux `platform.io` / `net.server` contract 保持稳定，并有 focused tests
  + heaptrc 证据
