# nextpas.core.websocket 代码契约

**模块路径**：`core/src/nextpas.core.websocket*.pas`（2 个源文件）
**层级**：L3（依赖 L0-L2: net, tls, http）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 核心接口

```pascal
IWebSocket = interface
  function SendText(const AData: string): Boolean;
  function SendBinary(const AData: TBytes): Boolean;
  function RecvFrame: TWebSocketFrame;
  procedure Close(AStatus: UInt16 = 1000; const AReason: string = '');
  function GetState: TWebSocketState;
end;

TWebSocketFrame = record
  Opcode: TWebSocketOpcode;  // Text/Binary/Ping/Pong/Close
  Payload: TBytes;
end;
```

### 1.2 WebSocket 协议

- RFC 6455 握手（HTTP Upgrade）
- 帧格式（FIN/opcode/mask/payload）
- Ping/Pong 心跳
- Close 握手

---

## 2. 不变量

- **[INV-1]** 客户端帧必须 mask（RFC 6455 要求）
- **[INV-2]** Close 后不再收发
- **[INV-3]** 文本帧必须是合法 UTF-8

---

## 3-6. 概要

- **错误**: 非法帧抛 EParseError; 协议错误抛 ENetworkError
- **线程安全**: ❌ 单连接操作
- **内存**: Payload 为 TBytes, 调用方管理
- **测试**: 1 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
