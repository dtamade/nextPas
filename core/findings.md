# Findings: WebSocket fragmented UTF-8 text sequence acceptance

## Scope

本轮补齐 WebSocket fragmented data-frame policy 的正向边界：text message 的 UTF-8
byte sequence 可以跨 frame boundary 拆分；`ReadFrame` 不应对 `FIN=0` text 首片做单帧
UTF-8 误拒，而应在 final continuation 到达时校验累计 text message。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `FragmentedTextUtf8SequenceAccepted` 后首次 focused gate 失败：

- `17 total, 16 passed, 1 failed`
- failure: `fragmented-utf8: server sends text frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会在首片 `#$C3` 上做单帧 UTF-8 校验并误回 protocol close，
即使首片加 final continuation `#$A9` 后整体是合法 UTF-8。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl` 现在记录 fragmented text 的累计 payload。
非 fragmented text 仍立即校验 UTF-8；fragmented text 首片与中间 continuation 先累计，
final continuation 到达后校验整条 text message。binary fragmentation 不参与 UTF-8 校验。

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

## Remaining gaps / risks

- 当前仍是 frame-level API，handler 仍需自行理解 fragmented frame 序列；本轮只修正 UTF-8 校验时机。
- 下一刀建议补 invalid fragmented final UTF-8 或 interleaved data-frame rejection 的 focused proof。
