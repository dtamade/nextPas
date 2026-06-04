# Findings: WebSocket outgoing close validation

## Scope

本轮补齐 `IWebSocket.Close(ACode, AReason)` 的 write-side close payload validation。
inbound `ReadFrame` 已经会拒绝 invalid close code 与 invalid UTF-8 close reason，但 outbound
public API 之前只检查 control-frame payload 长度，仍可能生成非法 close frame。

## Confirmed truths

### 1. RED 证明真实缺口

`test_http_websocket` 新增两个 focused 用例后首次 focused gate 失败：

- `27 total, 25 passed, 2 failed`
- failure: `outgoing-close-invalid-code: server sends text frame`
- failure: `outgoing-close-invalid-utf8: server sends text frame`
- heaptrc: `0 unfreed memory blocks`

这证明旧实现没有在 `Close` 写侧校验 RFC 6455 close payload 语义：

- `Close(999, 'bad')` 会写出 invalid close code。
- `Close(1000, #$C3)` 会写出 invalid UTF-8 reason。

### 2. 最小修复

`Close` 构造 payload 后、变更状态前，顺序执行：

- `ValidateControlPayloadSize(LPayload)`
- `ValidateClosePayload(LPayload)`

因此 oversize control payload 仍保持原有错误信息；语义非法时分别抛：

- `EHttpError('WebSocket: invalid close code')`
- `EHttpError('WebSocket: invalid close reason encoding')`

### 3. Focused proof

`test_http_websocket` 现在覆盖：

- outgoing invalid close code fail-fast，handler 可写 text fallback，证明状态未提前关闭。
- outgoing invalid UTF-8 close reason fail-fast，handler 可写 text fallback，证明状态未提前关闭。
- 既有 25 条 WebSocket focused case 保持通过。

## Remaining gaps / risks

- `Pong(126 bytes)` 仍是同一 `WriteFrame` guard 的 parity case；当前判断不值得单独消耗一轮。
- `WriteText` outbound UTF-8 validation 尚未作为契约固定。若决定 server API 必须阻止自己发非法 text frame，
  下一轮可用 RED 证明并补最小 guard。
