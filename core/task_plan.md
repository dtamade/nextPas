# Task Plan: http epoll chunked-not-final security parity

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀只补一条
malformed chunked raw-wire security 缺口：

- 不扩散到新的接口面或 runtime 家族
- 只补 `Transfer-Encoding: chunked, gzip` 在 `epoll` backend 下的 live parity
- 锁定这条 malformed transfer-coding order 仍返回显式 `400`
- 如果只是既有 truth 缺测试，本轮保持 coverage-expansion，不改生产代码

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 epoll chunked-not-final live parity
- [x] 在 `test_http_security` 新增 epoll malformed chunked focused proof
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_security test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不改生产代码
- 不跑全量 HTTP suite
- 不扩散到 benchmark / H2/H3 / facade 话题

## Intended outcome

- malformed chunked transfer-coding order 不只覆盖：
  - threaded / generic raw-wire `400`
- 还要直接覆盖：
  - `epoll` backend live raw-wire `400`
- 证据要求：
  - `Transfer-Encoding: chunked, gzip` 返回显式 `400`
  - 不进入 handler success path
  - heaptrc `0 unfreed memory blocks`
