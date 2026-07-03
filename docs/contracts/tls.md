# nextpas.core.tls 代码契约

> 模块路径: `core/src/nextpas.core.tls.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

TLS 模块统一门面。对齐 Rust rustls API 设计，提供 TSSLConnector/TSSLAcceptor
和便捷 TLSDial 函数。

---

## 关键接口

```pascal
type
  TSSLConnector = record
    class function FromContext(AContext: TSSLContext): TSSLConnector; static;
    function ConnectSocket(ASocket: IStream; AHost: string): TSSLStream;
  end;

  TSSLAcceptor = record
    class function FromContext(AContext: TSSLContext): TSSLAcceptor; static;
    function AcceptSocket(ASocket: IStream): TSSLStream;
  end;

  TSSLStream = record ... end;
  TSSLDialer = record ... end;

function TLSDial(AHost: string; APort: Word): IStream;
function TryTLSDial(AHost: string; APort: Word;
  out AStream: IStream; out AError: string): Boolean;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 握手失败 | raise ESSLException |
| 证书验证失败 | raise ESSLException |
| TLSDial 失败 | raise ESSLException |
| TryTLSDial 失败 | 返回 false，AError 描述原因 |

---

## 线程安全

- TSSLConnector/TSSLAcceptor 为值类型，可安全复制
- TSSLStream 不线程安全（per-connection）
- TSSLDialer 线程安全

---

## 依赖关系

- 依赖: io, crypto, net, hash
- 被依赖: http (HTTPS), websocket (WSS)

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
