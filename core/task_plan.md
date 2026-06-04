# Task Plan: http idle-timeout chunk-size-line characterization

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀专注 request-side `IdleTimeout`
在真实 parser 中间态上的收口：

- 不再复制另一组 direct-error / follow-up wire-order case
- 专门锁定 `partial chunk-size-line stall` 这类 chunk framing 中间态
- 同时补 poll-driven seam proof 与 threaded / epoll live-socket proof
- 如果只是既有 truth 缺测试，本轮保持 coverage-expansion，不改生产代码

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 `IdleTimeout` + `chunk-size-line stall`
- [x] 在 `test_http_server` 新增 poll-driven partial chunk-size-line timeout proof
- [x] 在 `test_http_security` 新增 threaded / epoll live chunk-size-line timeout proof
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_server test`
  - `make -C tests/nextpas.core.http/test_http_security test`
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
- 不改生产代码
- 不跑全量 HTTP suite
- 不扩散到 benchmark / H2/H3 / facade 话题

## Intended outcome

- request-side `IdleTimeout` 的 contract 不只覆盖：
  - slowloris
  - partial fixed-length body
  - partial chunked trailer
- 还要直接覆盖：
  - `partial chunk-size-line stall`
- 证据要求：
  - poll-driven seam focused proof
  - threaded live-socket proof
  - epoll live-socket proof
  - heaptrc `0 unfreed memory blocks`
