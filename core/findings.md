# Findings: WebSocket outgoing text UTF-8 validation

## Scope

本轮补齐 `IWebSocket.WriteText(AData)` 的 write-side UTF-8 validation。RFC 6455 text frame
必须承载 valid UTF-8；inbound `ReadFrame` 已经会拒绝 invalid UTF-8 text payload，但 outbound
public API 之前会直接写出调用方传入的 invalid text bytes。

## Confirmed truths

### 1. RED 证明真实缺口

`test_http_websocket` 新增 focused 用例后首次 focused gate 失败：

- `28 total, 27 passed, 1 failed`
- failure: `outgoing-text-invalid-utf8: fail-fast reason: expected "WebSocket: invalid text payload encoding", got "�"`
- heaptrc: `0 unfreed memory blocks`

这证明旧实现没有在 `WriteText` 写侧校验 UTF-8：

- `WriteText(#$C3)` 会写出 invalid UTF-8 text frame。
- handler 不会收到 `EHttpError`，因此不能把错误映射为 fallback frame。

### 2. 最小修复

`WriteText` 写出前执行：

- `ValidateTextPayload(AData)`

失败统一抛：

- `EHttpError('WebSocket: invalid text payload encoding')`

### 3. Focused proof

`test_http_websocket` 现在覆盖：

- outgoing invalid UTF-8 text fail-fast。
- fail-fast 后 handler 可写合法 text fallback，证明状态未提前关闭。
- 既有 27 条 WebSocket focused case 保持通过。

## Remaining gaps / risks

- `Pong(126 bytes)` 仍是同一 `WriteFrame` guard 的 parity case；当前判断不值得单独消耗一轮。
- WebSocket 目前仍是 frame-level string API；大消息/streaming writer 是后续 API 设计问题，不在本轮扩展。
