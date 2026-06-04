# Findings: WebSocket fragmented control-frame rejection

## Scope

本轮补齐 WebSocket fragmented control-frame contract。control frame 是协议控制面，
`FIN` 必须为 1；`FIN=0 + ping/pong/close` 必须被视为 protocol error。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `FragmentedControlFrameRejected` 后首次 focused gate 失败：

- `12 total, 11 passed, 1 failed`
- failure: `fragmented-control: server sends close frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会接受 `FIN=0 + ping`，并走正常 pong 路径。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl.ReadFrame` 现在在 opcode 校验后检查
control opcode 的 `FIN` bit；`opcode >= $08` 且 `FIN=False` 时立即抛
`EHttpError('WebSocket: control frames must not be fragmented')`。

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

## Remaining gaps / risks

- 本轮不覆盖 invalid close code、invalid UTF-8、fragmented data-frame assembly。
- 目前只锁定 control-frame fragmentation 禁止规则；data-frame fragmentation 后续如果要支持，
  应单独设计 message reassembly contract。
- 下一刀建议继续 invalid close code，仍保持 focused wire proof。
