# Task Plan: WebSocket unmasked client-frame rejection

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket negative frame coverage。WebSocket
server-side `ReadFrame` 必须符合 RFC 6455：client-to-server frame 必须 masked；
unmasked client frame 属于 protocol error，不能被当作正常 text/binary frame 交给
handler。

要求：

- 先 RED：unmasked client text frame 当前被 echo，未触发 protocol error。
- GREEN：`ReadFrame` 在 frame 边界拒绝 unmasked client frame 并抛 `EHttpError`。
- handler 可捕获该错误并返回 close frame code `1002`。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket negative frame 缺口。
- [x] 在 `test_http_websocket` 写 RED：unmasked client frame 应被 protocol close。
- [x] 在 `nextpas.core.http.websocket.ReadFrame` 增加 mask-required guard。
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

- masked client text/binary/close frame 正常路径保持不变。
- unmasked client text frame 不再被 echo。
- handler 捕获 `EHttpError` 后可发送 close frame，wire 上 close code 为 `1002`。
