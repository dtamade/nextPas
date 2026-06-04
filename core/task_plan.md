# Task Plan: WebSocket 64-bit non-canonical payload length rejection

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket negative frame coverage。RFC 6455
要求 payload length 使用最短可表达编码；server-side `ReadFrame` 必须拒绝短 payload
使用 64-bit extended length 的 non-canonical frame。

要求：

- 先 RED：masked text payload `"hi"` 使用 64-bit extended length 当前会被当普通 text echo。
- GREEN：`ReadFrame` 在读取 64-bit extended length 后，如果实际长度 `<65536`，抛 `EHttpError`。
- handler 可捕获该错误并返回 close frame code `1002`。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket 64-bit payload length canonical encoding 缺口。
- [x] 在 `test_http_websocket` 写 RED：短 payload 的 64-bit extended length 应被 protocol close。
- [x] 在 `nextpas.core.http.websocket.ReadFrame` 增加 64-bit non-canonical length guard。
- [x] 更新 `docs/http/API_COVERAGE.md`、`task_plan.md`、`findings.md`、`progress.md`。
- [x] 运行 focused 验证。
- [x] path-limited commit。

## Scope

本轮只允许修改：

- `docs/http/API_COVERAGE.md`
- `task_plan.md`
- `findings.md`
- `progress.md`
- `src/nextpas.core.http.websocket.pas`
- `tests/nextpas.core.http/test_http_websocket/test_http_websocket.lpr`

## Intended outcome

- 短 payload 使用 64-bit extended length 不再被 handler 当作正常 text。
- handler 捕获 `EHttpError` 后可发送 close frame，wire 上 close code 为 `1002`。
- 正常 text/binary/close、unmasked rejection、control-frame oversize rejection、reserved opcode rejection、fragmented control-frame rejection、invalid close-code rejection、invalid UTF-8 rejection 保持不变。
