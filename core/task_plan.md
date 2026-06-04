# Task Plan: http poll-driven chunked-not-final direct-error proof

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀只补一条
`poll-driven` direct-error seam 的窄缺口：

- 不扩散到新的 backend parity 家族
- 只补 `Transfer-Encoding: chunked, gzip` 在 poll-driven standalone direct-error 路径上的 writable-drain proof
- 锁定这条 malformed transfer-coding order 会进入 reactor-owned nonblocking drain，并返回显式 `400`
- 如果只是既有 truth 缺测试，本轮保持 coverage-expansion，不改生产代码

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 poll-driven chunked-not-final direct-error seam
- [x] 在 `test_http_server` 新增 focused poll-driven proof
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
- 不改生产代码
- 不跑全量 HTTP suite
- 不扩散到 benchmark / H2/H3 / facade 话题

## Intended outcome

- `chunked` malformed transfer-coding order 不只覆盖：
  - parser focused truth
  - generic/threaded server `400`
  - epoll live raw-wire `400`
- 还要直接覆盖：
  - poll-driven standalone direct-error writable-drain `400`
- 证据要求：
  - `Transfer-Encoding: chunked, gzip` 不进入 handler
  - direct error 走 reactor-owned nonblocking drain
  - wire 上写出显式 `HTTP/1.1 400 Bad Request`
  - heaptrc `0 unfreed memory blocks`
