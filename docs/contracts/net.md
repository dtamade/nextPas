# nextpas.core.net 代码契约

> 模块路径: `core/src/nextpas.core.net.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

TCP/UDP 网络模块门面。提供 TCP 监听/连接、UDP 绑定和 DNS 解析。

---

## 关键接口

```pascal
type
  TNetAddress = record ... end;
  ITcpStream = interface ... end;
  ITcpListener = interface ... end;
  IUdpSocket = interface ... end;

function TcpListen(AAddr: string; APort: UInt16): ITcpListener;
function TcpConnect(AAddr: string; APort: UInt16): ITcpStream;
function UdpBind(AAddr: string; APort: UInt16): IUdpSocket;
function Resolve(AHost: string): TNetAddress;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 连接被拒 | raise ENetworkError |
| DNS 解析失败 | raise ENetworkError |
| 端口占用 | raise EAlreadyExistsError |
| 超时 | raise ETimeoutError |

---

## 线程安全

- ITcpStream 读写不线程安全（需外部同步）
- ITcpListener.Accept 线程安全
- IUdpSocket 线程安全

---

## 依赖关系

- 依赖: base, io, platform.socket, platform.net
- 被依赖: http, tls, websocket

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
