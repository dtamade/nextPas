# nextpas.core.websocket 代码契约

> 模块路径: `core/src/nextpas.core.websocket.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

WebSocket 协议实现。提供帧编解码、握手密钥生成和掩码操作。

---

## 关键接口

```pascal
type
  TWebSocketRole = (wrClient, wrServer);
  TWebSocketFrame = record ... end;
  TWebSocketMessage = record ... end;

function WebSocketAcceptKey(AClientKey: string): string;
function WebSocketGenerateKey: string;
function WebSocketEncodeFrame(AFrame: TWebSocketFrame; ARole: TWebSocketRole): TBytes;
function TryWebSocketDecodeFrame(AData: TBytes; AOffset: SizeUInt;
  ARole: TWebSocketRole; out AFrame: TWebSocketFrame; out AConsumed: SizeUInt): Boolean;
function WebSocketTextFrame(AText: string; ARole: TWebSocketRole): TBytes;
function WebSocketBinaryFrame(AData: TBytes; ARole: TWebSocketRole): TBytes;
function WebSocketPingFrame(ARole: TWebSocketRole): TBytes;
function WebSocketPongFrame(APingPayload: TBytes; ARole: TWebSocketRole): TBytes;
function WebSocketCloseFrame(ACode: UInt16; AReason: string; ARole: TWebSocketRole): TBytes;
procedure WebSocketMask(var AData: TBytes; const AMaskKey: array of Byte);
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 帧解码失败 | TryWebSocketDecodeFrame 返回 false |
| 握手密钥非法 | raise EInvalidArgument |

---

## 线程安全

- 编解码函数为纯函数，可安全并发调用
- WebSocket 连接不线程安全（需外部同步）

---

## 依赖关系

- 依赖: base, hash, encoding, platform.random
- 被依赖: http.websocket

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
