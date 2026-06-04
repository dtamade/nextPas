# Task Plan: http security trailer-complete chunked partial follow-up headers raw-wire bridge

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀直接进入
`test_http_security`，把 trailer-complete chunked follow-up partial headers 从
half-close safe-handling 提升成 raw-wire bridge proof：

- 首个 trailer-complete chunked request 先完整完成并进入 handler
- 同连接后续只送到一半的 follow-up headers 不应污染首个请求
- 若后续再补齐剩余 header bytes 与 header terminator，第二个请求应合法完成
- 首请求的 trailer declaration / trailer isolation 契约仍必须保持不变
- 这次仍然只做 coverage-expansion，不预设生产修复

要求：

- 优先复用现有 `test_http_security` raw-wire keep-alive bridge 风格
- 先用 focused tests 取真值；如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_security` focused gate
- 不扩成 fixed-length / plain chunked 的同型 parity 平铺

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `test_http_security` 中 trailer-complete request-tail 相邻用例与 helper 风格
- [x] 缩小剩余高价值缺口，选定 trailer-complete chunked partial follow-up headers raw-wire bridge
- [x] 在 `test_http_security` 补 threaded / epoll focused live tests
- [x] focused gate 直接 GREEN，证明现有 raw-wire bridge contract 已成立
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_security test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_security/test_http_security.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 benchmark / server 基类重构 / 架构重设计

## Intended outcome

- trailer-complete chunked partial follow-up headers 不再只停留在 half-close 后 follow-up `400`
- threaded / epoll 两条 live 路径都锁住：
  - 首个 trailer-complete chunked request 先返回 `200`
  - handler 只读到解码后的首个 request body，且 trailer declaration / isolation 不变
  - follow-up partial headers 在补齐后能完成为合法第二请求
- 证据要求：
  - 新增 trailer-complete chunked partial follow-up headers raw-wire bridge tests GREEN
  - focused security suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
