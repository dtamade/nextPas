# Task Plan: h1 parser keep-alive partial follow-up headers bridge

## Goal

继续留在 `3/6 H1 正确性加固` 主线，这一刀补齐
`test_http_h1parser` 里 keep-alive request-tail 的 `partial follow-up headers`
bridge proof，让 parser / server / security 三层口径重新对齐：

- `Content-Length` follow-up partial headers 后续补齐后应能在 parser 层完成第二请求
- plain `chunked` follow-up partial headers 后续补齐后应能在 parser 层完成第二请求
- trailer-complete `chunked` follow-up partial headers 后续补齐后也应能在 parser 层完成第二请求
- 这次仍然只做 coverage-expansion，不预设生产修复

要求：

- 优先复用现有 `test_http_h1parser` request-tail bridge 风格
- 先用 focused tests 取真值；如果直接 GREEN，本轮不改生产代码
- 只跑 `test_http_h1parser` focused gate
- 不回去平铺 security 同型 parity case

## Checklist

- [x] 重新检查 shared checkout 状态，只处理 HTTP 相关路径
- [x] 审阅 `h1parser/server/security` 现有 request-tail proofs，确认 parser 层仍缺 headers bridge
- [x] 选定 `Content-Length` / plain `chunked` / trailer-complete `chunked` 三条 parser headers bridge
- [x] 在 `test_http_h1parser` 补三条 focused bridge tests
- [x] focused gate 直接 GREEN，证明现有 parser bridge contract 已成立
- [x] 跑 focused：
  - `make -C tests/nextpas.core.http/test_http_h1parser test`
- [x] 更新 coverage 文档与控制文件
- [x] path-limited commit

## Scope

- 本轮只动：
  - `tests/nextpas.core.http/test_http_h1parser/test_http_h1parser.lpr`
  - `docs/http/API_COVERAGE.md`
  - `task_plan.md`
  - `findings.md`
  - `progress.md`
- 不跑全量 HTTP suite
- 不扩散到 benchmark / server 基类重构 / 架构重设计

## Intended outcome

- parser 层对三条 keep-alive 主分支都明确锁住：
  - 首个请求只消费自己的字节
  - follow-up partial headers 在补齐后能完成为合法第二请求
- 证据要求：
  - 新增三条 parser partial follow-up headers bridge tests GREEN
  - focused h1parser suite 全绿
  - `heaptrc` 为 `0 unfreed memory blocks`
