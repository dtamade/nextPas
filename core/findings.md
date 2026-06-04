# Findings: WebSocket high-bit 64-bit payload length rejection

## Scope

本轮补齐 WebSocket 64-bit extended payload length high-bit contract。RFC 6455
的 64-bit payload length 最高位必须为 0；非零时必须在组合/使用巨大长度前作为
protocol error 拒绝。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `HighBitPayloadLength64Rejected` 后首次 focused gate 失败：

- `21 total, 20 passed, 1 failed`
- failure: `high-bit-length64: fail-fast reason`
- expected: `WebSocket: invalid 64-bit payload length`
- got: `WebSocket: control frame payload too large`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 已经组合出 high-bit 64-bit length，并先落入后续 control-frame
payload-size 规则；它没有在 length field 自身做 fail-fast。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl.ReadFrame` 现在读取 8-byte extended length
后先检查 `LExtLen[0] and $80`；只要 high bit 非零，就立即抛
`EHttpError('WebSocket: invalid 64-bit payload length')`，不再进入长度组合、
control-size 判定、mask 读取或 payload 分配路径。

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
- 64-bit extended length high-bit 非零会被 handler 捕获为 `EHttpError` 后返回 close code `1002`，且 close reason 证明命中 length high-bit fail-fast。

## Remaining gaps / risks

- WebSocket 仍缺一个 explicit max frame/message size policy；即便 high-bit 已拒绝，合法 63-bit
  超大长度仍需要后续从 API/option 层明确边界，避免无界分配风险。
- 下一刀建议补 invalid fragmented final UTF-8，或先设计 `MaxFrameSize` / `MaxMessageSize`
  这类 bounded policy 后再写 RED。
