# Task Plan: http server expect plus transfer-coding rejection ordering

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀继续 request-side protocol
completeness，补齐 `Expect: 100-continue` 与异常 `Transfer-Encoding`
的优先级次序：

- 当 transfer-coding 本身已经非法或不支持时，应先直接拒绝
- 这次只锁：
  - `Expect + Transfer-Encoding: gzip, chunked` -> final `501`
  - `Expect + Transfer-Encoding: chunked, gzip` -> final `400`
- 两条路径都不应先发 interim `100 Continue`

要求：

- 优先复用现有 `Expect` / raw-wire helper 风格
- 先用 focused tests 取真值；如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_server` focused gate
- 不扩成大面积 `Expect` / transfer-coding 组合矩阵

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅实现里的 parser error / unsupported-expect / continue 触发顺序
- [x] 缩小剩余高价值缺口，选定 `Expect + transfer-coding` error ordering
- [x] 在 `test_http_server` 补 threaded / epoll focused live tests
- [x] focused gate 直接 GREEN，证明现有 error-first ordering 已成立
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
- 不扩散到 security 大矩阵 / benchmark / server 基类重构

## Intended outcome

- `Expect` 与 transfer-coding error 的先后顺序不再只靠实现阅读，而是有 direct live proof
- threaded / epoll 两条 live 路径都锁住：
  - unsupported transfer-coding 直接返回 `501`
  - chunked-not-final malformed 直接返回 `400`
  - 两条路径都不先发 interim `100 Continue`
  - handler 都不会被调度
- 证据要求：
  - 新增 `Expect + transfer-coding` tests GREEN
  - focused server suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
