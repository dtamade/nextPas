# Task Plan: expect interim-100 body-stall server contract proof

## Goal

继续停留在 `3/6 H1 正确性加固` 主线，承接上一刀已经落地的 threaded
生产修复，把同一条 `Expect: 100-continue` request-side runtime truth
补成 `IHttpServer` public-contract focused proof。

- 只补 `test_http_server`，不再重复改生产代码
- 锁住 `interim 100` 已发出后，partial fixed-length / chunked body stall
  会按 `IdleTimeout` 安全关闭
- 要求 threaded / Linux `epoll` 两条 live path 都给出 server 层证据
- 只跑 `test_http_server` focused gate

要求：

- 只动 HTTP 相关路径
- 不扩散到 benchmark / server 基类设计 / 大面积 malformed parity 平铺

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `test_http_server` 现有 `Expect` / idle-timeout 覆盖，确认只缺
  public-contract proof
- [x] 在 `test_http_server` 新增 threaded / epoll 两组 focused proof：
  `interim 100` 后 body stall safe-close / no synthetic `500`
- [x] focused gate 直接 GREEN，证明上一刀生产修复已在 server 层自然成立
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_server clean test`
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
- 不改生产代码

## Intended outcome

- `IHttpServer` 的 `Expect: 100-continue` contract 在 server 层进一步收口：
  - interim `100` 先发出
  - partial fixed-length body stall 会安全关闭
  - partial chunked body stall 会安全关闭
  - threaded / epoll 都不会追加 synthetic `500`
  - handler 不会进入
- 证据要求：
  - 四条 `Expect after interim 100 body stall` server tests GREEN
  - `make -C tests/nextpas.core.http/test_http_server clean test` 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
