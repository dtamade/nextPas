# Task Plan: WebSocket standalone continuation rejection

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket negative frame coverage。RFC 6455
要求 continuation frame 只能出现在已经打开的 fragmented data message 中；server-side
`ReadFrame` 必须拒绝没有前置 fragmented text/binary 的 standalone continuation，
不得把 orphan continuation 当普通 frame 交给 handler。

要求：

- 先 RED：masked opcode `$00` continuation frame 当前被当作普通 continuation 交给 handler。
- GREEN：`ReadFrame` 跟踪 fragmented data message 状态，standalone continuation 抛 `EHttpError`。
- handler 可捕获该错误并返回 close frame code `1002`。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket fragmented data-frame policy 缺口。
- [x] 在 `test_http_websocket` 写 RED：standalone continuation 应被 protocol close。
- [x] 在 `nextpas.core.http.websocket.ReadFrame` 增加 continuation state guard。
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

- masked opcode `$00` continuation frame 不再被 handler 当作普通 continuation。
- handler 捕获 `EHttpError` 后可发送 close frame，wire 上 close code 为 `1002`。
- 正常 text/binary/close、unmasked rejection、control-frame oversize rejection、reserved opcode rejection、fragmented control-frame rejection、invalid close-code rejection、invalid UTF-8 rejection 保持不变。
