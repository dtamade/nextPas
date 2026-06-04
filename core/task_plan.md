# Task Plan: http poll-driven chunked-not-final partial-timeout proof

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀只补一条
`poll-driven` direct-error timeout seam 的窄缺口：

- 不扩散到新的 raw-wire/backend parity 家族
- 只补 `Transfer-Encoding: chunked, gzip` 在 poll-driven standalone direct-error partial-timeout 路径上的状态保持 proof
- 锁定这条 malformed transfer-coding order 在部分 error bytes 已写出后仍保持单一原始 `400`
- 如果只是既有 truth 缺测试，本轮保持 coverage-expansion，不改生产代码

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 poll-driven chunked-not-final partial-timeout seam
- [x] 在 `test_http_server` 新增 focused partial-timeout proof
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
  - poll-driven standalone writable-drain `400`
  - generic `400` partial-timeout
- 还要直接覆盖：
  - poll-driven standalone partial-timeout `400`
- 证据要求：
  - `Transfer-Encoding: chunked, gzip` 不进入 handler
  - partial error write 后仍只保留一条原始 `HTTP/1.1 400 Bad Request`
  - timeout close 后 `WakeDeadline` 清回 infinite
  - heaptrc `0 unfreed memory blocks`
