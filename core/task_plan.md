# Task Plan: http server expect list-membership semantics

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀转回 request-side protocol
completeness，专门收紧 `Expect` 的 list-membership 语义：

- `Expect` 不能只按“精确等于 `100-continue`”判断
- 只要 header value 的 comma-separated member 里包含
  `100-continue` expectation，server 就应按现有契约发出单条 interim
  `100 Continue`

本轮先只锁定一个最小但真实的组合值：
`Expect: 100-continue, 100-continue`

要求：

- 先 RED，再最小修复 H1 parse-stage 判定
- 优先复用现有 `RunExpectContinueSendsInterimResponse` helper
- 只跑 `test_http_server` focused gate
- 不扩成大面积 `Expect` 组合矩阵

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 `Expect` list-membership 语义
- [x] 在 `test_http_server` 补 duplicate `100-continue` threaded / epoll focused tests
- [x] 先跑 RED，确认当前实现把合法 list value 漏判成“不发 interim 100”
- [x] 最小修复 `RequestExpectsContinue`，从 exact-equals 改为 list-membership
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_server test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `src/nextpas.core.http.impl.h1.pas`
  - `tests/nextpas.core.http/test_http_server/test_http_server.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 security 大矩阵 / benchmark / server 基类重构

## Intended outcome

- duplicate `100-continue` 不再被当成“精确值不匹配”而漏掉 interim `100`
- threaded / epoll 两条 live 路径都锁住：
  - 先返回单条 `HTTP/1.1 100 Continue`
  - 后续仍能读取 body 并进入正常 handler
  - 最终 `200` 与 body contract 保持不变
- 证据要求：
  - 新增 duplicate-member tests 先 RED 后 GREEN
  - focused server suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
