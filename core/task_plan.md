# Task Plan: WebSocket outgoing text UTF-8 validation

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket public API correctness。inbound text frame
已经要求 payload 是 valid UTF-8；outbound `IWebSocket.WriteText` 也应避免 server-side API
自己生成非法 RFC 6455 text frame。

要求：

- 先 RED：handler 调用 `WriteText(#$C3)` 时，旧实现会写出 invalid UTF-8 text frame，而不是抛
  `EHttpError`。
- GREEN：`WriteText` 在写出前复用 text payload 校验，拒绝 invalid UTF-8。
- 校验失败后 websocket 状态仍可写，handler 能发送合法 fallback text frame。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` / `progress.md` 选择 WebSocket outgoing `WriteText` 真实 public API gap。
- [x] 在 `test_http_websocket` 写 RED：invalid outbound UTF-8 text 必须 fail-fast。
- [x] 在 `nextpas.core.http.websocket` 让 `WriteText` 写出前复用 `ValidateTextPayload`。
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

- `IWebSocket.WriteText` 不再能写出 invalid UTF-8 text frame。
- 失败前 `IWebSocket` 仍保持可写，handler 可把错误映射成 fallback text/close frame。
