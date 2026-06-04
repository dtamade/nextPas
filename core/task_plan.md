# Task Plan: WebSocket high-bit 64-bit payload length rejection

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket negative frame coverage。RFC 6455
的 64-bit extended payload length 实际只有低 63 bit 可用；最高位必须为 0。
server-side `ReadFrame` 必须在组合/使用长度前 fail-fast 拒绝 high-bit 非零输入，
避免后续路径尝试按巨大 payload 分配或读取。

要求：

- 先 RED：masked 64-bit extended length 最高位为 1 时，旧实现先落到后续 control-size 错误。
- GREEN：`ReadFrame` 读取 8-byte extended length 后先检查 high bit，非零时抛 `EHttpError`。
- handler 可捕获该错误并返回 close frame code `1002`。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket 64-bit length high-bit 缺口。
- [x] 在 `test_http_websocket` 写 RED：high-bit length 必须早于 control-size check 被识别。
- [x] 在 `nextpas.core.http.websocket.ReadFrame` 增加 64-bit length high-bit guard。
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

- 64-bit extended payload length 最高位非零时不再进入后续巨大长度使用路径。
- handler 捕获 `EHttpError` 后可发送 close frame，wire 上 close code 为 `1002`。
- 正常 text/binary/close、unmasked rejection、control-frame oversize rejection、reserved opcode rejection、fragmented control-frame rejection、invalid close-code rejection、invalid UTF-8 rejection、RSV bit rejection、canonical-length rejection 保持不变。
