# Findings: WebSocket control-frame payload limit

## Scope

本轮补齐 WebSocket control-frame oversize contract。control frame 是协议控制面，
payload length > 125 必须被视为 protocol error，不能由 handler 作为普通 ping/pong/close
处理。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `ControlFramePayloadTooLargeRejected` 后首次 focused gate
失败：

- `10 total, 9 passed, 1 failed`
- failure: `control-oversize: server sends close frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会接受 masked ping payload length 126，并走正常 pong 路径。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl.ReadFrame` 现在保留 opcode byte，在解析扩展
payload length 后检查 control opcode：`opcode >= $08` 且 payload length > 125 时立即抛
`EHttpError('WebSocket: control frame payload too large')`。

### 3. Focused proof

`test_http_websocket` 现在同时覆盖：

- 正向 handshake。
- missing upgrade / missing key 负向 handshake。
- text / binary / close frame 正向路径。
- coalesced first frame。
- upgrade 后 handler exception 不追加 synthetic `500`，且 handler-owned websocket 仍可用。
- unmasked client frame rejection。
- control-frame payload length 126 被 handler 捕获为 `EHttpError` 后返回 close code `1002`，
  不再 pong。

## Remaining gaps / risks

- 本轮不覆盖 fragmented control frame、reserved opcode、invalid close code、invalid UTF-8。
- 当前 control-frame guard 在扩展长度解析后触发，未继续读取 payload；handler 若捕获错误后
  需要结束连接，应发送 close frame 或释放连接。
- 下一刀建议继续 reserved opcode 或 fragmented control frame，仍保持 focused wire proof。
