# Task Plan: after-interim trailer EOF chain closure audit

## Goal

继续停留在 `3/6 H1 正确性加固` 主线，但不再机械复制同型 malformed
case。本轮先审计上一组 `Expect: 100-continue` + chunked trailer EOF
after-interim proof 是否已经覆盖完整邻接链；若链条闭合，则把路线推进到
keep-alive request-tail contract 决策，而不是继续加重复测试。

要求：

- 只动 HTTP 相关控制文件和覆盖文档。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不改生产代码；没有明确 RED 缺口就不新增测试。
- 不跑全量测试；文档/路线图-only 变更只做 diff 级验证。

## Checklist

- [x] 阅读 `docs/design-conventions.md`、`docs/http/API_COVERAGE.md`、
  `task_plan.md`、`findings.md`、`progress.md`。
- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 审计 `test_http_security` after-interim trailer EOF threaded / epoll 用例注册。
- [x] 审计 `test_http_server` after-interim trailer EOF threaded / epoll 用例注册。
- [x] 对照 parser / security / server 的 trailer EOF 家族，确认 after-interim
  trailer EOF 邻接链已经闭合。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 diff 级验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`

## Intended outcome

- 明确记录 after-interim trailer EOF 邻接链已闭合，不再继续铺同型 parity。
- 下一阶段固定为 keep-alive request-tail contract 决策：
  - 先区分“当前 transport truth”和“需要公开固定的 API contract”。
  - 只在发现 contract 缺口时补 focused tests。
  - 仍然优先 threaded / epoll parity，但不为 parity 而复制无价值 case。
