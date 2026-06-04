# Task Plan: expect interim-100 zero-progress idle-timeout proof

## Goal

继续停留在 `3/6 H1 正确性加固` 主线，承接上一刀已经落地的
`Expect: 100-continue` partial-body stall coverage，补齐
`interim 100` 发出后 body 完全零进展就 stall 的相邻 runtime truth。

- 补 `test_http_security` 与 `test_http_server` 的 zero-progress focused proof
- 锁住 `interim 100` 已发出后，fixed-length / chunked body 若一个字节都不再到达，
  会按 `IdleTimeout` 安全关闭
- 要求 threaded / Linux `epoll` 两条 live path 都给出 raw-wire + server 双层证据
- 只跑 `test_http_security`、`test_http_server` 两个 focused gate

要求：

- 只动 HTTP 相关路径
- 不扩散到 benchmark / server 基类设计 / 大面积 malformed parity 平铺

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `test_http_security` / `test_http_server` 现有 `Expect` / idle-timeout
  覆盖，确认 zero-progress 还是空缺
- [x] 在 `test_http_security` 与 `test_http_server` 新增 threaded / epoll 两组
  fixed-length / chunked zero-progress focused proof
- [x] focused gate 直接 GREEN，证明这轮只是 coverage-expansion，不需要生产修复
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_security clean test`
  - `make -C tests/nextpas.core.http/test_http_server clean test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不改生产代码

## Intended outcome

- `Expect: 100-continue` 的 zero-progress 邻接 truth 在 security/server 两层收口：
  - interim `100` 先发出
  - fixed-length zero-progress body stall 会安全关闭
  - chunked zero-progress body stall 会安全关闭
  - threaded / epoll 都不会追加 final status line 或 synthetic `500`
  - handler 不会进入
- 证据要求：
  - 四条 security zero-progress tests GREEN
  - 四条 server zero-progress tests GREEN
  - `make -C tests/nextpas.core.http/test_http_security clean test` 全绿
  - `make -C tests/nextpas.core.http/test_http_server clean test` 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
