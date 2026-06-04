# Task Plan: WebSocket bounded frame/message size options

## Goal

继续推进 `HttpServer 完成` 主线中的 WebSocket safety/API completeness。上一轮已经拒绝
64-bit payload length high-bit，但合法 63-bit declared length 仍需要明确的 bounded
policy，避免 server-side `ReadFrame` 进入无界 payload 分配或长时间读取路径。

要求：

- 先 RED：经由 `nextpas.core.http` facade 使用 `TWebSocketOptions` 和
  `UpgradeWebSocket(Req, Writer, Options)`，旧代码应因 API 缺失编译失败。
- GREEN：新增 `TWebSocketOptions.Default`、facade alias、overload，并在 payload 分配前
  执行 `MaxFrameSize` 检查。
- 同时锁住 `MaxMessageSize` 对 fragmented message 的累计限制。
- handler 可将 size-limit `EHttpError` 映射为 WebSocket close code `1009`。
- 不写 `docs/nextpas.core.http.inbox.md`。
- 不跑全量测试；只跑 `test_http_websocket` focused gate。

## Checklist

- [x] 检查 `git status --short --branch`，确认 shared checkout 仍有大量无关脏文件。
- [x] 从 `docs/http/API_COVERAGE.md` 选择 WebSocket bounded size policy 缺口。
- [x] 在 `test_http_websocket` 写 RED：`TWebSocketOptions` / 三参数 `UpgradeWebSocket` 缺失。
- [x] 在 `nextpas.core.http.websocket` 增加 options、默认值、frame/message size guard。
- [x] 在 `nextpas.core.http` facade re-export options/default constants/overload。
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
- `src/nextpas.core.http.pas`
- `src/nextpas.core.http.websocket.pas`
- `tests/nextpas.core.http/test_http_websocket/test_http_websocket.lpr`

## Intended outcome

- WebSocket endpoint 可通过公开 options 设置 frame/message 边界。
- declared frame length 超过 `MaxFrameSize` 时，在 payload 分配/读取前拒绝。
- fragmented message 累计超过 `MaxMessageSize` 时拒绝。
- 原有 upgrade、正常 text/binary/close、negative frame proof 保持不变。
