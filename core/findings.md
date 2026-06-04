# Findings: WebSocket unmasked client-frame rejection

## Scope

本轮补齐 WebSocket negative frame contract：server-side `IWebSocket.ReadFrame` 必须
拒绝未 masked 的 client frame。该 contract 是 WebSocket 安全边界，不能只依赖正向
echo tests。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `UnmaskedClientFrameRejected` 后首次 focused gate 失败：

- `9 total, 8 passed, 1 failed`
- failure: `unmasked: server sends close frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会接受 unmasked client text frame，并走正常 echo 路径。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl.ReadFrame` 现在解析 header 后立即检查
MASK bit；client frame 未 masked 时抛 `EHttpError('WebSocket: client frames must be masked')`。

### 3. Focused proof

`test_http_websocket` 现在同时覆盖：

- 正向 handshake。
- missing upgrade / missing key 负向 handshake。
- text / binary / close frame 正向路径。
- coalesced first frame。
- upgrade 后 handler exception 不追加 synthetic `500`，且 handler-owned websocket 仍可用。
- unmasked client frame 被 handler 捕获为 `EHttpError` 后返回 close code `1002`，不再 echo。

## Remaining gaps / risks

- 本轮不覆盖 control-frame payload > 125、fragmentation、reserved opcode、invalid close code、
  invalid UTF-8 等 WebSocket negative cases。
- 当前修复在 frame header 处 fail-fast，不消费后续非法 payload；handler 若捕获错误后需要
  结束连接，应发送 close frame 或释放连接。
- WebSocket oversize / invalid opcode 后续应继续用 focused wire tests 收口。
