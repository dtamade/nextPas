# Task Plan: http content-length epoll request-tail safety proofs

## Goal

继续留在 H1 correctness 主线，但不再一格一格碎片化推进；这一批直接把 `Content-Length` keep-alive request-tail 在 Linux `epoll` security 层剩余的同族 sibling gap 一次补齐：

- 先做矩阵筛查，确认 parser/server 已有而 security 还缺的 `Content-Length` epoll request-tail truth
- 在 `test_http_security` 里补两条 Linux `epoll` raw-wire proof：
  - garbage tail -> follow-up `400`
  - truncated follow-up request line -> follow-up `400`
- 保持已落地的 truncated follow-up headers proof 一起纳入 focused 验证，确认整组 `Content-Length` epoll request-tail contract 一次收口
- 只有真出现 threaded / epoll 分歧时才做最小生产修复；否则本轮继续保持测试和文档批次

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 做 parser/server/security 矩阵筛查，确认这轮最值的是把 `Content-Length` epoll request-tail 剩余 sibling gap 成组补齐
- [x] 在 `test_http_security` 里复用 threaded helper，并补 Linux `epoll` live variant：
  - garbage tail -> follow-up `400`
  - truncated follow-up request line -> follow-up `400`
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

- 把 `test_http_security` 里的 `Content-Length` epoll request-tail safety proof 一次补到 trio 对齐：
  - garbage tail
  - truncated follow-up request line
  - truncated follow-up headers
- 用最小 raw-wire live 证据确认这组 follow-up `200 -> 400` contract 在 threaded / epoll backend 上都没有偏移
- 如果直接 GREEN，就把结论固定进文档，避免后续反复猜测 backend 是否有差异
- 下一刀只从剩余 request-tail sibling gap 或 trailer/chunk truncation 边角里挑一格，不再扩成整片 parity 搬运
