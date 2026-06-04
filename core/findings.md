# Findings: WebSocket standalone continuation rejection

## Scope

本轮补齐 WebSocket fragmented data-frame policy 的第一刀：continuation frame
只能出现在已经打开的 fragmented text/binary message 中；standalone continuation
必须被视为 protocol error。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `StandaloneContinuationFrameRejected` 后首次 focused gate 失败：

- `16 total, 15 passed, 1 failed`
- failure: `standalone-continuation: server sends close frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会接受 opcode `$00` 的 orphan continuation，并把它交给 handler。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl` 现在记录 `FFragmentOpen`。没有打开的
fragmented data message 时收到 continuation 会抛 `EHttpError`；fragment 已打开时又收到新的
text/binary 起帧也会抛 `EHttpError`。control frame 仍不改变 fragment state。

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

## Remaining gaps / risks

- 本轮不实现 message reassembly，也不声明完整 fragmented message UTF-8 validation。
- 下一刀建议补 interleaved data-frame rejection 或 valid fragmented sequence state proof。
