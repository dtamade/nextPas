# Task Plan: WebSocket outgoing close validation

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket public API correctness。上一轮补齐
outgoing control-frame payload limit 后，`IWebSocket.Close(ACode, AReason)` 仍可能写出
invalid close code 或 invalid UTF-8 reason，导致 server-side API 自己生成非法 RFC 6455
close frame。

要求：

- 先 RED：handler 调用 `Close(999, 'bad')` 或 `Close(1000, #$C3)` 时，旧实现会写出非法
  close frame，而不是抛 `EHttpError`。
- GREEN：`Close` 在写出前复用 close payload 校验，拒绝 invalid close code / invalid UTF-8
  reason。
- 校验必须发生在 `FCloseSent/FOpen` 状态变更前；失败后 handler 仍可写 fallback frame。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket outgoing `Close` 真实 public API gap。
- [x] 在 `test_http_websocket` 写 RED：invalid close code / invalid close reason 必须 fail-fast。
- [x] 在 `nextpas.core.http.websocket` 让 `Close` 写出前复用 `ValidateClosePayload`。
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

- `IWebSocket.Close` 不再能写出 invalid close code。
- `IWebSocket.Close` 不再能写出 invalid UTF-8 close reason。
- 失败前 `IWebSocket` 仍保持可写，handler 可把错误映射成 fallback text/close frame。
