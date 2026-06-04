# Findings: WebSocket invalid UTF-8 close-reason rejection

## Scope

本轮补齐 WebSocket invalid UTF-8 close-reason contract。close reason 是文本字段，
必须是合法 UTF-8；malformed UTF-8 reason 必须被视为 protocol error。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `InvalidUtf8CloseReasonRejected` 后首次 focused gate 失败：

- `15 total, 14 passed, 1 failed`
- failure: `invalid-utf8-close-reason: close code protocol error: expected 1002, got 1000`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会接受 malformed UTF-8 close reason，并把它交给 handler 走正常 close 路径。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl.ReadFrame` 的 close payload guard
现在在 status code 校验后继续校验 reason 字节。reason 长度大于 0 且
`nextpas.core.text.utf8.UTF8IsValid` 判为 false 时会抛 `EHttpError`，handler 可映射为 close code `1002`。

### 3. Focused proof

`test_http_websocket` 现在同时覆盖：

- 正向 handshake。
- missing upgrade / missing key 负向 handshake。
- text / binary / close frame 正向路径。
- coalesced first frame。
- upgrade 后 handler exception 不追加 synthetic `500`，且 handler-owned websocket 仍可用。
- unmasked client frame rejection。
- control-frame payload length > 125 rejection。
- reserved opcode rejection。
- `FIN=0 + ping` 被 handler 捕获为 `EHttpError` 后返回 close code `1002`。
- close code `999` 被 handler 捕获为 `EHttpError` 后返回 close code `1002`。
- malformed UTF-8 text payload 被 handler 捕获为 `EHttpError` 后返回 close code `1002`。
- malformed UTF-8 close reason 被 handler 捕获为 `EHttpError` 后返回 close code `1002`。

## Remaining gaps / risks

- 本轮不覆盖 fragmented data-frame assembly。
- 下一刀建议固定 fragmented data-frame policy，仍保持 focused wire proof。
