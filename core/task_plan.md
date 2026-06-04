# Task Plan: http server request-target over MaxHeaderSize contract

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀继续 request-side protocol
completeness，把 long-request-line 的 broad safe-handling 收紧成更具体的
server-layer `MaxHeaderSize` 契约：

- 当 request-target 本身把 request-line 顶过 `MaxHeaderSize` 预算时，
  server 应直接返回 `431`
- 这次只锁 request-target / request-line 这一条预算分支
- 同时证明 handler 不会被调度

要求：

- 优先复用现有 `MaxHeaderSize` / raw-wire helper 风格
- 先用 focused tests 取真值；如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_server` focused gate
- 不扩成大面积 long-URL / parser 安全矩阵

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 long-request-line 现有 security current truth 与 `MaxHeaderSize` 实现路径
- [x] 缩小剩余高价值缺口，选定 request-target over `MaxHeaderSize`
- [x] 在 `test_http_server` 补 threaded / epoll focused live tests
- [x] focused gate 直接 GREEN，证明现有 `431` contract 已成立
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_server test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 security 大矩阵 / benchmark / server 基类重构

## Intended outcome

- request-target over `MaxHeaderSize` 不再只停留在 broad safe-handling，而是有 direct live proof
- threaded / epoll 两条 live 路径都锁住：
  - request-target over budget 直接返回 `431`
  - handler 不会被调度
- 证据要求：
  - 新增 request-target over `MaxHeaderSize` tests GREEN
  - focused server suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
