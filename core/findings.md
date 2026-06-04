# Findings: WebSocket reserved opcode rejection

## Scope

本轮补齐 WebSocket reserved opcode contract。server-side `ReadFrame` 不应把 `$03`
这类 reserved opcode cast 成公开 `TWebSocketOpcode` 后交给 handler，而应在 frame
边界 fail-fast。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `ReservedOpcodeRejected` 后首次 focused gate 失败：

- `11 total, 10 passed, 1 failed`
- failure: `reserved-opcode: got close response`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 没有 opcode 合法性校验，reserved opcode 不会触发 protocol close。

### 2. 最小修复

`nextpas.core.http.websocket` 新增 `IsValidOpcode`，只允许 `$0/$1/$2/$8/$9/$A`。
`TWebSocketImpl.ReadFrame` 现在在 cast 到 `TWebSocketOpcode` 前检查 opcode；非法值抛
`EHttpError('WebSocket: reserved or invalid opcode')`。

### 3. Focused proof

`test_http_websocket` 现在同时覆盖：

- 正向 handshake。
- missing upgrade / missing key 负向 handshake。
- text / binary / close frame 正向路径。
- coalesced first frame。
- upgrade 后 handler exception 不追加 synthetic `500`，且 handler-owned websocket 仍可用。
- unmasked client frame rejection。
- control-frame payload length > 125 rejection。
- reserved opcode `$03` 被 handler 捕获为 `EHttpError` 后返回 close code `1002`。

## Remaining gaps / risks

- 本轮不覆盖 fragmented control frame、invalid close code、invalid UTF-8。
- 目前 reserved opcode guard 不区分未来扩展协商；当前 API 尚无 extension negotiation，
  因此 fail-fast 是正确默认。
- 下一刀建议继续 fragmented control frame 或 invalid close code。
