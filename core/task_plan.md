# Task Plan: security request-target over max-header explicit 431

## Goal

继续留在 `3/6 H1 正确性加固` 主线，但离开上一刀的
request-tail bridge 模板，转到更高价值的 malformed/runtime 邻接缺口：
把 `test_http_security` 里 `request-target over MaxHeaderSize` 从 broad
safe-handling 收紧成 raw-wire explicit `431` proof，并补 threaded / epoll
两条路径的直接证据。

- 复用 `test_http_server` 已有的 focused `431` 口径
- 先在 `test_http_security` 写 focused tests 取真值
- 如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_security` focused gate，不回去跑全量 HTTP

要求：

- 只动 HTTP 相关路径
- 不扩散到 benchmark / server 基类设计 / 大面积 parity 平铺

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `test_http_server` / `test_http_security` 现有 request-target over
  `MaxHeaderSize` 口径
- [x] 在 `test_http_security` 补 threaded raw-wire explicit `431` proof
- [x] 在 `test_http_security` 补 Linux `epoll` raw-wire explicit `431` proof
- [x] focused gate 直接 GREEN，证明现有 transport contract 已成立
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_security clean test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 benchmark / server 基类重构 / 架构重设计

## Intended outcome

- security 层对 `request-target over MaxHeaderSize` 明确锁住：
  - 在受控小 `MaxHeaderSize` 下，oversized request-target 直接返回显式 `431`
  - threaded / Linux `epoll` 两条路径都给出 raw-wire focused 证据
- server / security 两层口径重新对齐：
  - security 锁 raw-wire `431`
  - server 继续锁 handler 不进入的更窄契约
- 证据要求：
  - 新增两条 security request-target `431` tests GREEN
  - focused security suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
