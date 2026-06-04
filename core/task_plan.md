# Task Plan: expect interim-100 truncated trailer separator EOF proof

## Goal

继续停留在 `3/6 H1 正确性加固` 主线，承接上一刀已经完成的
`Expect: 100-continue` trailer field-name EOF after-interim proof，继续补
更贴近 EOF 邻接的小缺口：`Expect + Transfer-Encoding: chunked`
在 interim `100` 发出后，如果 trailer separator 在 EOF 前被截断，
应返回 final `400 Bad Request`。

- 补 `test_http_security` 与 `test_http_server` 的
  after-interim trailer separator EOF focused proof
- 锁住 `interim 100` 已发出后：
  - partial trailer separator + write-half-close 会返回 explicit `400 Bad Request`
  - 不会重复发 `100 Continue`
  - 不会误回 `200`
  - handler 不会进入
- 要求 threaded / Linux `epoll` 两条 live path 都给出 raw-wire + server 双层证据
- 只跑 `test_http_security`、`test_http_server` 两个 focused gate

要求：

- 只动 HTTP 相关路径
- 不扩散到 benchmark / server 基类设计 / 大面积 malformed parity 平铺
- 不改生产代码，除非 RED 证明必须修

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `test_http_security` / `test_http_server` 现有 `Expect` / malformed
  trailer EOF 覆盖，确认 after-interim `truncated trailer separator EOF`
  仍是空缺
- [x] 复用现有 `shutdown-after-body` helper，不再扩新 helper 形状
- [x] 在 `test_http_security` 与 `test_http_server` 新增 threaded / epoll
  两组 `Expect + chunked truncated trailer separator EOF after interim 100`
  focused proof
- [x] focused gate 直接 GREEN，证明这轮只是 coverage-expansion，不需要生产修复
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_security test`
  - `make -C tests/nextpas.core.http/test_http_server test`
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

- `Expect: 100-continue` 的 trailer EOF 邻接 truth 在 security/server 两层收口：
  - interim `100` 先发出
  - partial trailer separator 后 peer write-half-close 会返回 final `400 Bad Request`
  - threaded / epoll 都不会重复 interim `100`
  - threaded / epoll 都不会误回 `200`
  - threaded / epoll 都不会进入 handler
- 证据要求：
  - 两条 security focused-after-interim tests GREEN
  - 两条 server focused-after-interim tests GREEN
  - `make -C tests/nextpas.core.http/test_http_security test` 全绿
  - `make -C tests/nextpas.core.http/test_http_server test` 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
