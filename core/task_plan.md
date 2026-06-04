# Task Plan: http server expect-417 error-path coverage

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀不再扩新语义，而是把
上一刀刚引入的 `417 Expectation Failed` 接到现有 error-path 证据链上：

- queued follow-up wire-order
- poll-driven standalone writable-drain
- poll-driven partial-timeout preserve-status
- direct error write-timeout / partial-timeout preserve-status
- real-socket queued follow-up wire-order

要求：

- 优先复用现有 helper，把 `417` 接到既有 direct-error coverage 家族
- 如果 tests 直接 GREEN，则本轮不改生产代码
- 不跑全量 HTTP suite

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 `417` error-path coverage
- [x] 在 `test_http_server` 补 focused tests
- [x] 新增 tests 直接 GREEN，本轮无需生产修复
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
- 不扩散到 benchmark / H2/H3 / facade 话题

## Intended outcome

- `417 Expectation Failed` 不再只停留在 early-rejection proof，而是被接入
  既有 queued/direct error-path coverage 家族
- poll seam、threaded real-socket、epoll real-socket 都有 focused proof
- 证据要求：
  - queued follow-up `417` 保持在首个 `200` 之后
  - standalone/direct `417` timed drain 仍保持单一原始 status line
  - `heaptrc` 为 `0 unfreed memory blocks`
