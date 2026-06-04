# Task Plan: http server plain chunked partial follow-up headers bridge

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀继续收口 keep-alive
request-tail contract，把 plain chunked follow-up partial headers 从
current-truth characterization 提升成更可依赖的 server-layer bridge proof：

- 首个 plain chunked request 先完整完成并进入 handler
- 同连接后续只送到一半的 follow-up headers 不应污染首个请求
- 若后续再补齐剩余 header bytes 与 header terminator，第二个请求应合法完成
- 这次仍然只做 coverage-expansion，不预设生产修复

要求：

- 优先复用现有 keep-alive bridge test 风格
- 先用 focused tests 取真值；如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_server` focused gate
- 不扩成大面积 malformed / security parity 平铺

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 keep-alive request-tail 现有 bridge / current-truth 分布
- [x] 缩小剩余高价值缺口，选定 plain chunked partial follow-up headers bridge
- [x] 在 `test_http_server` 补 threaded / epoll focused live tests
- [x] focused gate 直接 GREEN，证明现有 bridge contract 已成立
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

- plain chunked partial follow-up headers 不再只停留在 half-close 后 follow-up `400`
- threaded / epoll 两条 live 路径都锁住：
  - 首个 plain chunked request 先返回 `200`
  - handler 只读到解码后的首个 request body
  - follow-up partial headers 在补齐后能完成为合法第二请求
- 证据要求：
  - 新增 plain chunked partial follow-up headers bridge tests GREEN
  - focused server suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
