# Findings: WebSocket outgoing control-frame payload limits

## Scope

本轮补齐 outgoing WebSocket control-frame payload boundary。RFC 6455 要求所有
control frame payload 长度不超过 125 bytes；此前 inbound `ReadFrame` 已有该校验，
但 public write-side API 仍可通过 `Ping` / `Pong` / `Close` 写出非法 extended-length
control frame。

## Confirmed truths

### 1. RED 证明真实缺口

`test_http_websocket` 新增两个 focused 用例后首次 focused gate 失败：

- `25 total, 23 passed, 2 failed`
- failure: `outgoing-ping-oversize: server sends close frame`
- failure: `outgoing-close-oversize: server sends text frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧实现没有在 write-side API 边界拒绝 oversize control payload：

- `Ping(126 bytes)` 写出了非法 ping frame。
- `Close(1000, 124-byte reason)` 写出了非法 close frame。

### 2. 最小修复

新增 `ValidateControlPayloadSize`，在 write-side control frame 出口复用：

- `WriteFrame(wsOpPing/wsOpPong/wsOpClose, Payload)` 写出前检查 `Length(Payload) <= 125`。
- `Close` 在设置 `FCloseSent` / `FOpen := False` 前先校验完整 close payload
  `2-byte code + reason`。

失败统一抛：

- `EHttpError('WebSocket: control frame payload too large')`

### 3. Focused proof

`test_http_websocket` 现在覆盖：

- outgoing `Ping(126 bytes)` fail-fast，handler 可转 close `1002`，wire 上不会出现非法 ping。
- outgoing `Close(1000, 124-byte reason)` fail-fast，handler 仍可写 text fallback，证明状态未提前关闭。
- 既有 23 条 WebSocket focused case 保持通过。

## Remaining gaps / risks

- `Pong` 走同一个 `WriteFrame` guard，但本轮没有单独铺 wire case；如果后续需要更细 API coverage，
  可以补一条 `Pong(126 bytes)` parity。
- write-side text/binary 仍是一次性 string payload API；大 payload 行为由调用方内存决定，后续如要支持
  大消息，应考虑 streaming writer/reader，而不是继续扩大 string API。
