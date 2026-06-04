# Findings: WebSocket 64-bit non-canonical payload length rejection

## Scope

本轮补齐 WebSocket payload length canonical encoding 的第二刀：payload length 必须使用
最短可表达编码；短 payload 不能用 64-bit extended length 绕过正常 frame grammar。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `NonCanonicalPayloadLength64Rejected` 后首次 focused gate 失败：

- `19 total, 18 passed, 1 failed`
- failure: `non-canonical-length64: server sends close frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会接受 payload `"hi"` 的 64-bit extended length encoding，
并把它当正常 text frame 交给 handler。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl.ReadFrame` 现在在读取 64-bit extended length
后检查实际长度；如果 `<65536`，立即抛 `EHttpError('WebSocket: non-canonical payload length')`。

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
- standalone continuation 被 handler 捕获为 `EHttpError` 后返回 close code `1002`。
- `FIN=0 text #$C3` + final continuation `#$A9` 可被 handler 连续读取，并返回正常 text response。
- 短 payload 使用 16-bit / 64-bit extended length 都会被 handler 捕获为 `EHttpError` 后返回 close code `1002`。

## Remaining gaps / risks

- 本轮只直接证明 64-bit extended length 表达 `<65536` 的 non-canonical case。
- 下一刀建议补 64-bit high-bit set 的 payload length rejection，避免超大长度路径进入分配/读循环。
