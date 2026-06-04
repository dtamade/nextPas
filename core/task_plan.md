# Task Plan: WebSocket reserved opcode rejection

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket negative frame coverage。RFC 6455
只允许 data opcode `$0/$1/$2` 与 control opcode `$8/$9/$A`；reserved opcode
必须被视为 protocol error，不能被 cast 成公开 enum 后交给 handler。

要求：

- 先 RED：masked reserved opcode `$03` 当前没有触发 protocol close。
- GREEN：`ReadFrame` 在 opcode 边界拒绝 reserved/invalid opcode 并抛 `EHttpError`。
- handler 可捕获该错误并返回 close frame code `1002`。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket reserved opcode 缺口。
- [x] 在 `test_http_websocket` 写 RED：reserved opcode `$03` 应被 protocol close。
- [x] 在 `nextpas.core.http.websocket.ReadFrame` 增加 opcode validity guard。
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

- masked reserved opcode `$03` 不再被 handler 静默接受。
- handler 捕获 `EHttpError` 后可发送 close frame，wire 上 close code 为 `1002`。
- 正常 text/binary/close、unmasked rejection、control-frame oversize rejection 保持不变。
