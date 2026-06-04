# Findings: WebSocket invalid close-code rejection

## Scope

本轮补齐 WebSocket invalid close-code contract。close frame 是协议控制面，
payload 为空时合法；payload 长度为 1 或携带不可发送状态码时必须被视为 protocol error。

## Confirmed truths

### 1. RED 证明了真实缺口

`test_http_websocket` 新增 `InvalidCloseCodeRejected` 后首次 focused gate 失败：

- `13 total, 12 passed, 1 failed`
- failure: `invalid-close-code: close code protocol error: expected 1002, got 1000`
- heaptrc: `0 unfreed memory blocks`

这证明旧 `ReadFrame` 会接受 close code `999`，并把它交给 handler 走正常 close 路径。

### 2. 最小修复

`nextpas.core.http.websocket.TWebSocketImpl.ReadFrame` 现在在 close frame payload
解码后调用 close payload/code guard。payload 长度为 1、close code `<1000`、
保留码 `1004/1005/1006/1015`、以及 `>=5000` 的越界值都会抛 `EHttpError`。

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

## Remaining gaps / risks

- 本轮直接证明 close code `<1000` 的拒绝路径；保留码和 `>=5000` 由同一 guard 覆盖，但尚未逐个铺 raw-wire case。
- 本轮不覆盖 invalid UTF-8、fragmented data-frame assembly。
- 下一刀建议继续 invalid UTF-8 或先固定 fragmented data-frame policy，仍保持 focused wire proof。
