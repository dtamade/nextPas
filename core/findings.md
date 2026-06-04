# Findings: WebSocket bounded frame/message size options

## Scope

本轮补齐 WebSocket bounded size policy。`ReadFrame` 不能只验证 RFC framing；
它还需要 framework-level resource boundary，避免合法但超大的 declared length 导致
无界分配、长时间阻塞读取或 fragmented message 累计增长。

## Confirmed truths

### 1. RED 证明公开 API 缺口

`test_http_websocket` 新增两个 focused 用例后首次 focused gate 编译失败：

- `Identifier not found "TWebSocketOptions"`
- `Wrong number of parameters specified for call to "UpgradeWebSocket"`
- 失败位置覆盖 `MaxFrameSize` declared-length case 与 `MaxMessageSize` fragmented case

这证明当前 facade 没有 endpoint-level WebSocket size policy carrier，也没有带 options
的 `UpgradeWebSocket` overload。

### 2. 最小设计

新增 `TWebSocketOptions`：

- `MaxFrameSize`
- `MaxMessageSize`
- `Default`

默认值：

- `WEBSOCKET_DEFAULT_MAX_FRAME_SIZE = 16777216`，即 16 MiB。
- `WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE = 67108864`，即 64 MiB。

`nextpas.core.http` facade 现在 re-export：

- `TWebSocketOptions`
- `WEBSOCKET_DEFAULT_MAX_FRAME_SIZE`
- `WEBSOCKET_DEFAULT_MAX_MESSAGE_SIZE`
- `UpgradeWebSocket(AReq, AW, AOptions)`

### 3. Runtime behavior

`TWebSocketImpl.ReadFrame` 现在在 payload 分配/读取前检查 declared payload length：

- `LPayloadLen > MaxFrameSize` -> `EHttpError('WebSocket: frame too large')`
- 非 fragmented text/binary message 超过 `MaxMessageSize` -> `EHttpError('WebSocket: message too large')`
- continuation 累计超过 `MaxMessageSize` -> `EHttpError('WebSocket: message too large')`

测试 handler 将 size-limit error 映射为 WebSocket close code `1009`。

## Remaining gaps / risks

- 当前 focused proof 直接覆盖 text frame declared oversize 与 fragmented text cumulative oversize。
  binary fragmented message 走同一个 `FFragmentPayloadSize` 累计路径，但尚未单独铺 wire case。
- 后续如果 WebSocket 子协议/API 扩展到 streaming message reader，应重新审视是否仍适合
  `string` payload 一次性返回，避免 API 形态和大消息处理目标冲突。
