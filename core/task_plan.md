# Task Plan: request RemoteAddr direct proof

## Goal

继续推进 `HttpServer 完成` 主线中的 public request contract 完整性，补齐
`IHttpRequest.RemoteAddr` 的 direct unit proof。server live 已证明 handler
能看到 remote addr，但 `THttpRequest.SetRemoteAddr` 到 interface getter 的直接契约
还需要锁进 `test_http_message`。

要求：

- 只补 focused proof，不改生产代码。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_message` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 `RemoteAddr` direct proof 缺口。
- [x] 审计 `THttpRequest.SetRemoteAddr` / `IHttpRequest.RemoteAddr` 当前实现。
- [x] 在 `test_http_message` 补 focused assertion：默认空值与 setter/getter round-trip。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `tests/nextpas.core.http/test_http_message/test_http_message.lpr`

## Intended outcome

- `NewGetRequest(...).RemoteAddr` 默认返回空字符串。
- `THttpRequest.SetRemoteAddr` 设置后，`IHttpRequest.RemoteAddr` 返回同一值。
- `docs/http/API_COVERAGE.md` 不再把 RemoteAddr direct proof 记为 next-action。
