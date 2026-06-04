# Findings: WebSocket echo runnable example

## Scope

本轮补齐 WebSocket runnable example。此前 `test_http_websocket` 已覆盖 WebSocket API
契约，但 examples 目录里只有 HTTP hello/client/server-options demo，没有可运行的 WebSocket
server example。

## Confirmed truths

### 1. RED 证明真实缺口

`test_http_examples` 新增 WebSocket example smoke 后首次 focused gate 失败：

- `3 total, 2 passed, 1 failed`
- failure: `websocket echo demo serves documented endpoint - unable to resolve core root from current directory or executable path`
- heaptrc: `0 unfreed memory blocks`

失败原因是 `examples/nextpas.core.http/http_websocket_echo_demo` 尚不存在，因此测试无法解析并构建该示例。

### 2. 最小实现

新增 `http_websocket_echo_demo`：

- `GET /health` 返回 `websocket-echo=ready`。
- `GET /ws` 执行 `UpgradeWebSocket`，读取一个 frame。
- text frame 返回 `echo=<payload>`，随后 `Close(1000, 'bye')`。
- 示例启动时打印 ready/listen/try markers，供 smoke 与人工运行使用。

### 3. Focused proof

`test_http_examples` 现在覆盖：

- 自动 build `http_websocket_echo_demo`。
- 启动外部 example server 进程并等待 ready marker。
- raw TCP 完成 WebSocket handshake。
- 发送 masked text frame `hello`。
- 验证 server 返回 unmasked text frame `echo=hello`。

## Remaining gaps / risks

- 这个示例是最小 echo demo，不覆盖 TLS/WebSocket over TLS、fragmentation 或大消息 streaming。
- benchmark 仍按路线后置；当前只补 examples/docs 可运行性闭环。
