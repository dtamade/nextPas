# Task Plan: WebSocket outgoing control-frame payload limits

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket public API correctness。上一轮补齐
inbound frame/message size boundary 后，outgoing `Ping` / `Pong` / `Close` 仍可能通过
`WriteFrameRaw` 写出 payload > 125 的 extended-length control frame，违反 RFC 6455。

要求：

- 先 RED：handler 调用 `Ping(126 bytes)` 或 `Close(1000, 124-byte reason)` 时，
  旧实现会写出非法 control frame，而不是抛 `EHttpError`。
- GREEN：outgoing control-frame payload > 125 时，在写出前抛
  `EHttpError('WebSocket: control frame payload too large')`。
- `Close` 也必须在设置 `FCloseSent/FOpen` 前检查，失败后 handler 仍可写 fallback 响应。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 outgoing control-frame payload 缺口。
- [x] 在 `test_http_websocket` 写 RED：oversize `Ping` / `Close` 必须 fail-fast。
- [x] 在 `nextpas.core.http.websocket` 增加 outgoing control payload guard。
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
- `src/nextpas.core.http.websocket.pas`
- `tests/nextpas.core.http/test_http_websocket/test_http_websocket.lpr`

## Intended outcome

- `Ping` / `Pong` 不再能写出 payload > 125 的 control frame。
- `Close` reason 超过 123 bytes 时不会写出非法 close frame，也不会提前关闭 `IWebSocket` 状态。
- 原有 inbound control-frame rejection、bounded frame/message size、正常 close/ping 行为保持不变。
