# Task Plan: oversize trailer max-header explicit 431

## Goal

继续留在 `3/6 H1 正确性加固` 主线，完成 header-budget 邻接收口：
把 chunked oversize trailer over `MaxHeaderSize` 从 `431 or safe-close`
收紧成 explicit `431` proof，并补齐 server/security 两层的 threaded /
epoll 直接证据。

- 复用普通 header field / request-target over `MaxHeaderSize` 已收紧的
  focused `431` 口径
- 先在 `test_http_server` / `test_http_security` 写 focused tests 取真值
- 如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_server` / `test_http_security` focused gates，不回去跑全量 HTTP

要求：

- 只动 HTTP 相关路径
- 不扩散到 benchmark / server 基类设计 / 大面积 parity 平铺

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `test_http_server` / `test_http_security` 现有 oversize trailer /
  `MaxHeaderSize` 口径
- [x] 在 `test_http_server` 收紧 threaded explicit `431` + handler 不进入 proof
- [x] 在 `test_http_server` 补 Linux `epoll` explicit `431` + handler 不进入 proof
- [x] 在 `test_http_security` 收紧 threaded raw-wire explicit `431` proof
- [x] 在 `test_http_security` 收紧 Linux `epoll` raw-wire explicit `431` proof
- [x] focused gates 直接 GREEN，证明现有 transport contract 已成立
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
  - `make -C tests/nextpas.core.http/test_http_security clean test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 benchmark / server 基类重构 / 架构重设计

## Intended outcome

- server/security 两层对 chunked oversize trailer over `MaxHeaderSize` 明确锁住：
  - 在受控小 `MaxHeaderSize` 下，oversized trailer 直接返回显式 `431`
  - threaded / Linux `epoll` 两条路径都给出 focused 证据
- server / security 两层口径重新对齐：
  - server 锁 `431` 且 handler 不进入
  - security 锁 raw-wire `431`
- 证据要求：
  - 四条 oversize trailer `431` tests GREEN
  - focused server/security suites 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
