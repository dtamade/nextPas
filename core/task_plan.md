# Task Plan: http security keep-alive partial follow-up headers raw-wire bridge

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀继续收口
`test_http_security` 的 keep-alive request-tail contract，把还缺的两条
`partial follow-up headers` 从 half-close safe-handling 提升成 raw-wire bridge proof：

- `Content-Length` 首请求先完整完成，半截 follow-up headers 后续补齐后第二请求应合法完成
- plain `chunked` 首请求先完整完成，半截 follow-up headers 后续补齐后第二请求应合法完成
- 两条路径都必须保住“不要过早判 malformed”的 transport 契约
- 这次仍然只做 coverage-expansion，不预设生产修复

要求：

- 优先复用现有 `test_http_security` raw-wire keep-alive bridge 风格
- 先用 focused tests 取真值；如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_security` focused gate
- 为了减少重复往返，这次把 `Content-Length` 与 plain `chunked` 同类缺口合并一刀完成

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `server/security` 现有 request-tail proofs，确认还缺的 security/raw-wire headers bridge
- [x] 选定 `Content-Length` 与 plain `chunked` partial follow-up headers raw-wire bridge
- [x] 在 `test_http_security` 补两组 threaded / epoll focused live tests
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

- `Content-Length` 与 plain `chunked` 的 partial follow-up headers 不再只停留在 half-close 后 follow-up `400`
- threaded / epoll 两条 live 路径都锁住：
  - 首个请求先返回 `200 / echo:5`
  - follow-up partial headers 在补齐后能完成为合法第二请求 `200 / ok`
- 证据要求：
  - 新增 `Content-Length` 与 plain `chunked` partial follow-up headers raw-wire bridge tests GREEN
  - focused security suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
