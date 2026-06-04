# Task Plan: router CONNECT / TRACE convenience surface

## Goal

继续推进 `HttpServer 完成` 主线中的 public interface 完整性，把
`IHttpRouter` / `THttpRouter` 的便利方法补齐到已经公开的全部
`THttpMethod` 枚举：`CONNECT` 和 `TRACE` 不应只能通过 generic
`Handle(hmConnect/hmTrace, ...)` 注册。

要求：

- 先 RED：`IHttpRouter.Connect` / `IHttpRouter.Trace` 编译失败。
- GREEN 只做最小接口声明和 router 转发。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_contract`、`test_http_router` 两个 focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 public surface 小缺口。
- [x] 在 `test_http_contract` 写 RED：interface 上调用 `Connect` / `Trace`。
- [x] 在 `test_http_router` 补 concrete router dispatch proof。
- [x] 在 `IHttpRouter` / `THttpRouter` 增加 `Connect` / `Trace`。
- [x] 更新 `docs/http/README.md`、`docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/README.md`
- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `src/nextpas.core.http.intf.pas`
- `src/nextpas.core.http.router.pas`
- `tests/nextpas.core.http/test_http_contract/test_http_contract.lpr`
- `tests/nextpas.core.http/test_http_router/test_http_router.lpr`

## Intended outcome

- `IHttpRouter.Connect` 注册 `hmConnect` route。
- `IHttpRouter.Trace` 注册 `hmTrace` route。
- `THttpRouter.Connect` / `Trace` concrete API 与 interface API 保持一致。
- README / coverage matrix 不再把 `Connect/Trace` 记为待决缺口。
