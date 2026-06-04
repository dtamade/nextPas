# Task Plan: http chunk truncation epoll live parity proofs

## Goal

继续留在 H1 correctness 主线，并继续收口 malformed chunked/trailer truncation 边界；这一批直接把 chunk-side truncation 在 Linux `epoll` security 层剩余的 live parity gap 一次补齐：

- 先做矩阵筛查，确认 security 层仍缺的不是 request-tail，而是 chunk-side truncation 的 epoll live parity
- 在 `test_http_security` 里补一整组 Linux `epoll` raw-wire proof：
  - truncated chunk extension / extension CR
  - truncated chunked request / chunk-size line
  - truncated terminal chunk ending / ending CR
  - truncated terminal chunk extension / extension CR
  - truncated terminal chunk ending after extension / after-extension CR
  - truncated chunk-data ending / chunk-data CR
- 保持已存在的 threaded chunk truncation truth 不变，只补 epoll raw-wire parity
- 只有真出现 threaded / epoll 分歧时才做最小生产修复；否则本轮继续保持测试和文档批次

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 做 parser/server/security 矩阵筛查，确认这轮最值的是把 chunk truncation epoll live parity 成组补齐
- [x] 在 `test_http_security` 里复用 threaded helper，并补 Linux `epoll` live variant：
  - chunk extension / extension CR
  - chunked request / chunk-size line
  - terminal chunk ending / ending CR
  - terminal chunk extension / extension CR
  - ending after extension / after-extension CR
  - chunk-data ending / chunk-data CR
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

- 把 `test_http_security` 里的 chunk truncation epoll live proof 一次补到成组对齐：
  - chunk extension / extension CR
  - chunked request / chunk-size line
  - terminal chunk ending / extension / after-extension
  - chunk-data ending / chunk-data CR
- 用最小 raw-wire live 证据确认这组 malformed chunked `400` contract 在 threaded / epoll backend 上都没有偏移
- 如果直接 GREEN，就把结论固定进文档，避免后续反复猜测 backend 是否有差异
- 下一刀优先重新筛查是否还存在高价值 malformed raw-wire gap；如果只剩机械 parity，就停止扩 security
