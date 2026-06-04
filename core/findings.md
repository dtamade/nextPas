# Findings: WebSocket RSV bit rejection

## Scope

本轮补齐 WebSocket RSV bit contract。当前 WebSocket implementation 没有协商任何
extensions，因此 RSV1/RSV2/RSV3 必须为 0；非零 RSV bit 必须被视为 protocol error。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `ReservedBitsRejected` 后首次 focused gate 失败：

- `20 total, 19 passed, 1 failed`
- failure: `reserved-bits: server sends close frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会接受 first byte `$C1` 的 RSV1 text frame，并把它当正常 text
frame 交给 handler。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl.ReadFrame` 现在读取第一个 frame byte 后先检查
`$70` RSV bit mask；只要 RSV1/2/3 任一非零，就立即抛
`EHttpError('WebSocket: reserved bits set')`。

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
- RSV1 text frame 被 handler 捕获为 `EHttpError` 后返回 close code `1002`。

## Remaining gaps / risks

- 本轮只直接证明 RSV1 bit；RSV2/RSV3 由同一 bitmask guard 覆盖但未逐个铺 wire case。
- 下一刀建议继续 safe high-bit payload length proof，或补 invalid fragmented final UTF-8。
