# nextpas.core.websocket 代码契约

**模块路径**：`core/src/nextpas.core.websocket*.pas`（帧层）+ `core/src/nextpas.core.http.websocket*.pas`（连接层与 Room）
**层级**：L3（依赖 L0-L2: net, tls, http）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-18
**版本**：1.1

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

### 1.3 Room / 广播（`nextpas.core.http.websocket.room`）

- **IWebSocketRoom**：命名连接组；`Join(WS, Data: TObject)` / `Leave(WS): TObject` /
  `Broadcast(Data, Exclude)` / `Count`。成员按接口指针判等；Join 幂等（首载荷生效）；
  Broadcast 锁内快照、锁外写出，写失败成员被剔除（不阻塞 join/leave 与其他成员）。
- **TWebSocketRoomManager**：有界房间注册表（默认 128，可配）；`GetOrCreate` / `Find` /
  `Remove` / `RoomCount`。房间为引用计数接口：注册表淘汰（先空房、后最小房）不悬垂持用引用。
- **载荷所有权**：房间只借 `Data`，由加入方线程持有并在断连时释放；Broadcast 剔除死成员
  不触碰其载荷（死连接线程仍持有权威引用）。

---

## 2. 不变量

- **[INV-1]** 客户端帧必须 mask（RFC 6455 要求）
- **[INV-2]** Close 后不再收发
- **[INV-3]** 文本帧必须是合法 UTF-8
- **[INV-4]** 单连接操作非线程安全；Room/广播层线程安全（内部锁，锁序 manager→room，无反向）

---

## 3-6. 概要

- **错误**: 非法帧抛 EParseError; 协议错误抛 ENetworkError；Room 写失败仅剔除成员、不抛给调用方
- **线程安全**: 单连接 ❌；Room/Manager ✅（每房一锁；广播快照后锁外写）
- **内存**: Payload 为 TBytes, 调用方管理; Room 成员载荷借入（调用方持有）
- **测试**: `tests/nextpas.core.websocket`（帧层）+ `tests/nextpas.core.http/test_http_websocket*`
  （连接/升级/Room；Room 套件 mock 驱动、确定性验证）

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-08-18 | 1.1 | Room/广播层（B6 pascn backfeed）：IWebSocketRoom + 有界管理器落 http.websocket.room | Claude |
