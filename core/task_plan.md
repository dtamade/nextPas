# Task Plan: http server no-length expect-continue guard proof

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀继续 request-side protocol
completeness，补齐 `Expect: 100-continue` 的 no-body 守卫 live 契约里
“完全不声明 body”的分支：

- 当请求没有真正声明 body 时，不应误发 interim `100 Continue`
- 这次只锁 `POST + Expect: 100-continue` 且无 `Content-Length` / 无
  `Transfer-Encoding`
- 最终应直接进入 handler/final response 路径

要求：

- 优先复用现有 `Expect` live helper 风格
- 先用 focused tests 取真值；如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_server` focused gate
- 不扩成大面积 `Expect` 无-body 组合矩阵

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅实现里的 `ShouldSendContinueResponse` / `RequestDeclaresBody`
- [x] 缩小剩余高价值缺口，选定 no-length bodyless `Expect`
- [x] 把 zero-length helper 泛化，避免重复 live-test 代码
- [x] 在 `test_http_server` 补 threaded / epoll focused live tests
- [x] focused gate 直接 GREEN，证明现有 no-body guard 已成立
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

- `Expect: 100-continue` 在 no-body 请求上不再只靠实现阅读，而是有 direct live proof
- threaded / epoll 两条 live 路径都锁住：
  - 无 `Content-Length` / `Transfer-Encoding` 时不发 interim `100 Continue`
  - handler 仍会被正常调度
  - final response 直接返回 `200`
- 证据要求：
  - 新增 no-body `Expect` tests GREEN
  - focused server suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
