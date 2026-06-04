# Task Plan: HandlerFunc nil-callback contract

## Goal

继续推进 `HttpServer 完成` 主线中的 public handler contract 完整性，补齐
`HandlerFunc` nil-callback contract。nil handler callback 必须在 factory 边界被
显式拒绝，不能延迟到 `ServeHTTP` 时变成未定义调用或崩溃。

要求：

- 先 RED：nil closure/method/proc 没有被显式拒绝。
- GREEN：三个 overload 都在 factory 边界抛 `EHttpError`。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_middleware` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 `HandlerFunc` nil-callback contract 缺口。
- [x] 在 `test_http_middleware` 写 RED：nil closure/method/proc 应抛 `EHttpError`。
- [x] 在 `nextpas.core.http.middleware` 三个 overload 增加 nil guard。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `src/nextpas.core.http.middleware.pas`
- `tests/nextpas.core.http/test_http_middleware/test_http_middleware.lpr`

## Intended outcome

- `HandlerFunc(THttpHandlerFunc(nil))` 抛 `EHttpError`。
- `HandlerFunc(THttpHandlerMethod(nil))` 抛 `EHttpError`。
- `HandlerFunc(THttpHandlerProc(nil))` 抛 `EHttpError`。
- 已有非 nil handler / middleware chain 行为保持不变。
