# Task Plan: http content-length partial follow-up request-line epoll bridge proof

## Goal

继续留在 H1 correctness 主线，并沿 keep-alive request-tail contract 补掉一个明确的 security 缺口：

- 先做矩阵筛查，确认 parser/server 已有而 security 还缺的 request-tail truth
- 在 `test_http_security` 里补 `Content-Length` partial follow-up request-line can-complete-later 的 Linux `epoll` raw-wire bridge proof
- 锁定“首个 `Content-Length` request 先返回 `200 / echo:5`，后续把半截下一请求行补全后，第二个请求仍返回 `200 / ok`”的 live truth
- 只有真出现 threaded / epoll 分歧时才做最小生产修复；否则本轮继续保持测试和文档批次

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 做 parser/server/security 矩阵筛查，确认这轮最值的缺口是 `Content-Length` partial follow-up request-line bridge 的 epoll raw-wire proof
- [x] 在 `test_http_security` 里复用 threaded helper，并补 Linux `epoll` live variant：
  - first response -> `200 / echo:5`
  - completed follow-up request -> `200 / ok`
- [x] 跑 focused `make -C tests/nextpas.core.http/test_http_security clean test`
- [x] 判断是否需要生产修复：本轮不需要
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
- 不跑全量测试

## Intended outcome

- 把 `test_http_security` 从已存在的 threaded `Content-Length` partial-next-line bridge truth，再往前补到 epoll live backend
- 用最小 raw-wire live 证据确认这条 follow-up `200 -> 200` request-tail bridge contract 在 threaded / epoll backend 上都没有偏移
- 如果直接 GREEN，就把结论固定进文档，避免后续反复猜测 backend 是否有差异
- 下一刀只从剩余 request-tail sibling gap 或 trailer/chunk truncation 边角里挑一格，不再扩成整片 parity 搬运
