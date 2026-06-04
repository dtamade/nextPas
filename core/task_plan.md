# Task Plan: Middleware nil-input contract

## Goal

继续推进 `HttpServer 完成` 主线中的 public middleware contract 完整性，补齐
`MiddlewareFunc` / `TMiddlewareChain` / `Chain` 的 nil 输入边界。无效 middleware
输入必须在 factory / chain 边界显式拒绝，不能延迟到 `Wrap` / `ServeHTTP` 时变成
nil interface 调用或异常路径泄漏。

要求：

- 先 RED：旧实现接受 `MiddlewareFunc(nil)`，且 chain nil 输入没有统一
  `EHttpError` 契约。
- GREEN：nil middleware callback、nil chain root handler、nil middleware entry
  都抛 `EHttpError`。
- 异常路径不得泄漏；heaptrc 必须为 0。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_middleware` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从上轮 findings / API coverage 选择 middleware nil 输入契约缺口。
- [x] 在 `test_http_middleware` 写 RED：middleware nil 输入应抛 `EHttpError`。
- [x] 在 `nextpas.core.http.middleware` 增加 nil guard。
- [x] 修复 `Chain` 异常路径，确保 `Use(nil)` 抛出时释放中间 chain。
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

- `MiddlewareFunc(TMiddlewareWrapFunc(nil))` 抛 `EHttpError`。
- `TMiddlewareChain.Create(nil)` 抛 `EHttpError`。
- `TMiddlewareChain.Use(nil)` 抛 `EHttpError`。
- `Chain(ValidHandler, [nil])` 抛 `EHttpError` 且不泄漏中间 chain。
- 已有 middleware order / short-circuit / response mutation 行为保持不变。
