# Task Plan: http epoll malformed chunked live parity

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀回到用户要求的
raw-wire malformed chunked request security proof，只补两条还没拿到
`epoll` live parity 的窄缺口：

- `chunked + Connection: close + extra bytes after terminal chunk` -> `400`
- malformed trailer field -> `400`

如果只是既有 truth 缺测试，本轮保持 coverage-expansion，不改生产代码。

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定两条 `epoll` malformed chunked live case
- [x] 在 `test_http_security` 新增 focused live raw-wire proof
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
- 不改生产代码
- 不跑全量 HTTP suite
- 不扩散到 benchmark / H2/H3 / facade 话题

## Intended outcome

- Linux `epoll` backend 对这两条 malformed chunked request 拿到真实 socket 侧显式 `400` 证明
- 证据要求：
  - 请求不进入 handler 成功路径
  - wire 上出现单一 `HTTP/1.1 400`
  - `heaptrc` 为 `0 unfreed memory blocks`
