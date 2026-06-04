# Task Plan: EHttpError public category proof

## Goal

继续推进 `HttpServer 完成` 主线中的 public API 完整性，补齐 `http.base`
里公开的 `EHttpError` 契约证明：作为 HTTP 模块边界异常，它必须继承
`ENextPasError`、保留 message，并稳定归类到 `ecNetwork`。

要求：

- 先确认现状；如果 current truth 已正确，不为 RED 人为改坏代码。
- 只补 focused proof，不改生产代码。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_base` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 `EHttpError` category proof 缺口。
- [x] 审计 `EHttpError.Create` 当前实现：继承 `ENextPasError` 并设置 `ecNetwork`。
- [x] 在 `test_http_base` 补 focused assertion：继承、message、category。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `tests/nextpas.core.http/test_http_base/test_http_base.lpr`

## Intended outcome

- `EHttpError.Create` 的 message preservation 有 focused proof。
- `EHttpError` 继承 `ENextPasError` 有 focused proof。
- `EHttpError.Category = ecNetwork` 有 focused proof。
- `HttpStrToMethod` 抛出的 `EHttpError` 同样锁住 `ecNetwork` category。
