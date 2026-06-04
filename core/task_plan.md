# Task Plan: http server repeated expect header aggregation

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀继续 request-side protocol
completeness，专门收紧 repeated `Expect` header-line 的聚合语义：

- parser 会把重复 header-line 存成多条 entry
- `Expect` 判定不能只看第一条 `Get('expect')`
- 如果后续 `Expect:` 行里带 unsupported member，server 仍必须直接返回
  final `417`，不能因为第一条是 `100-continue` 就误发 interim `100`

本轮只锁定一个最小但真实的重复 header-line 组合：
第一条 `Expect: 100-continue`，第二条 `Expect: fancy`

要求：

- 先 RED，再最小修复 H1 parse-stage 判定
- 优先复用现有 unsupported-Expect helper 风格
- 只跑 `test_http_server` focused gate
- 不扩成大面积 `Expect` 组合矩阵

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 缩小剩余高价值缺口，选定 repeated `Expect` header 聚合语义
- [x] 在 `test_http_server` 补 repeated `Expect` threaded / epoll focused tests
- [x] 先跑 RED，确认当前实现只看第一条 `Expect`，从而漏掉后续 unsupported member
- [x] 最小修复 `RequestExpectsContinue` / `RequestHasUnsupportedExpectations`，从 `Get` 改为 `GetAll` 全量扫描
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

- repeated `Expect` header-line 不再因为第一条是 `100-continue` 就漏掉后续 unsupported member
- threaded / epoll 两条 live 路径都锁住：
  - 直接返回 final `HTTP/1.1 417 Expectation Failed`
  - 不会误发 interim `100 Continue`
  - 不进入 handler
- 证据要求：
  - 新增 repeated-header tests 先 RED 后 GREEN
  - focused server suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
