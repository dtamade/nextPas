# Task Plan: WebSocket fragmented control-frame rejection

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket negative frame coverage。RFC 6455
要求 control frame 不得被 fragmented；server-side `ReadFrame` 必须拒绝 `FIN=0`
的 ping/pong/close，不得把非法 control frame 交给 handler。

要求：

- 先 RED：masked `FIN=0 + ping` 当前被当作正常 ping，handler 会 pong。
- GREEN：`ReadFrame` 对 control opcode 检查 `FIN`，fragmented control frame 抛 `EHttpError`。
- handler 可捕获该错误并返回 close frame code `1002`。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket fragmented control frame 缺口。
- [x] 在 `test_http_websocket` 写 RED：`FIN=0 + ping` 应被 protocol close。
- [x] 在 `nextpas.core.http.websocket.ReadFrame` 增加 control-frame FIN guard。
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

- masked `FIN=0 + ping` 不再被 handler 当作正常 ping。
- handler 捕获 `EHttpError` 后可发送 close frame，wire 上 close code 为 `1002`。
- 正常 text/binary/close、unmasked rejection、control-frame oversize rejection、reserved opcode rejection 保持不变。
