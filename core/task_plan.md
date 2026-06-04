# Task Plan: WebSocket echo runnable example

## Goal

继续推进 `HttpServer 完成` 主线中的 examples/docs 完成度。WebSocket public API 已有较强
unit/security 覆盖，但缺一个 runnable example 证明 `UpgradeWebSocket`、`ReadFrame`、
`WriteText`、`Close` 可以在真实 server 进程中组合使用。

要求：

- 先 RED：`test_http_examples` 增加 WebSocket example build/run smoke，当前应因示例缺失失败。
- GREEN：新增 `http_websocket_echo_demo`，提供 `/health` 与 `/ws`。
- smoke 必须自动 build example、启动外部 server 进程、完成 WebSocket handshake，并验证 masked
  text frame 得到 server text echo。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_examples` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` / `docs/http/README.md` 选择 WebSocket runnable example 缺口。
- [x] 在 `test_http_examples` 写 RED：WebSocket echo demo 必须可 build/run/handshake/echo。
- [x] 新增 `examples/nextpas.core.http/http_websocket_echo_demo`。
- [x] 更新 `docs/http/API_COVERAGE.md`、`docs/http/README.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `docs/http/README.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `examples/nextpas.core.http/http_websocket_echo_demo/Makefile`
- `examples/nextpas.core.http/http_websocket_echo_demo/http_websocket_echo_demo.lpr`
- `tests/nextpas.core.http/test_http_examples/test_http_examples.lpr`

## Intended outcome

- WebSocket API 不再只停留在 unit tests；有一个可运行 echo demo。
- example smoke 能证明示例可构建、可启动、可完成 `/ws` WebSocket handshake 和 text echo。
