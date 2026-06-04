# Task Plan: http request-side idle-timeout live proofs

## Goal

继续留在 H1 correctness 主线，并从 malformed parity 收口切回更高价值的 runtime contract；这一批直接把 request-side `IdleTimeout` 的 live-socket 语义补到 security：

- 先做矩阵筛查，确认 malformed raw-wire 的大块 parity 已经基本收口，接下来更值的是 request-side timeout characterization
- 在 `test_http_security` 里补 live-socket proof：
  - partial request line / slowloris
  - partial fixed-length body stall
  - partial chunked trailer stall
- 保持 server 层已有的 poll-driven `WakeDeadline` / timeout-close truth 不变，只补外部 real-socket 视角证据
- 只有真出现 threaded / epoll 分歧时才做最小生产修复；否则本轮继续保持测试和文档批次

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、控制文件
- [x] 做 parser/server/security 矩阵筛查，确认这轮最值的是补 request-side `IdleTimeout` 的 live-socket proof
- [x] 在 `test_http_security` 里复用 threaded helper，并补 Linux `epoll` live variant：
  - slowloris partial request
  - partial fixed-length body stall
  - partial chunked trailer stall
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

- 把 `test_http_security` 里的 request-side `IdleTimeout` live proof 扩成更完整的 runtime 视角：
  - partial request line eventually closes
  - partial fixed-length body stall eventually closes
  - partial chunked trailer stall eventually closes
- 用 real-socket live 证据确认 partial request progress 不会被误当成成功请求，也会在 timeout 后安全关闭
- 如果直接 GREEN，就把结论固定进文档，避免后续反复猜测 backend 是否有差异
- 下一刀优先重新筛查 security / contract 层是否还存在比 parity 更值的 runtime truth gap
