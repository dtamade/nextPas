# nextpas.core.tls 代码契约

**模块路径**：`core/src/nextpas.core.tls*.pas`（231 个源文件）
**层级**：L2（依赖 L0-L2: base, net, crypto, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 架构概览

```
tls.intf         ← ITlsContext, ITlsStream 接口
tls.context      ← TLS 上下文（证书/密钥/协议配置）
tls.stream       ← TLS 加密流（包装 ISocket）
tls.client       ← TLS 客户端握手
tls.server       ← TLS 服务端握手
tls13.*          ← TLS 1.3 协议实现（handshake/alert/wire/key-schedule）
tls.openssl.*    ← OpenSSL 绑定（FFI + API 封装）
tls.winssl.*     ← Windows SChannel 绑定
tls.ct.*         ← Certificate Transparency
tls.certstore    ← 证书存储
tls.websocket    ← WebSocket over TLS
tls.alpn         ← ALPN 协商
tls.pas          ← 门面
```

### 1.2 核心接口

```pascal
ITlsContext = interface
  function Connect(ASocket: ISocket): ITlsStream;
  function Accept(ASocket: ISocket): ITlsStream;
  procedure SetCertificate(const ACert, AKey: string);
  procedure SetVerifyMode(AVerify: TTlsVerifyMode);
  procedure SetAlpnProtocols(const AProtocols: array of string);
end;

ITlsStream = interface
  function Send(const AData; ASize: SizeInt): SizeInt;
  function Recv(var AData; ASize: SizeInt): SizeInt;
  procedure Close;
  function GetAlpnProtocol: string;
end;
```

### 1.3 TLS 1.3 实现

完整的 TLS 1.3 协议栈：
- Handshake: ClientHello/ServerHello/EncryptedExtensions/Certificate/Verify/Finished
- Key schedule: HKDF-Expand/Extract, traffic key derivation
- Record layer: AEAD encryption (AES-256-GCM, ChaCha20-Poly1305)
- Alert: 错误处理和关闭通知
- 0-RTT: 早期数据支持

### 1.4 平台后端

| 后端 | 文件数 | 说明 |
|------|--------|------|
| OpenSSL | ~80 | Linux/macOS 主要后端 |
| WinSSL/SChannel | ~60 | Windows 原生后端 |
| Pure Pascal TLS 1.3 | ~50 | 自实现 TLS 1.3 |
| Certificate Transparency | ~10 | SCT 验证 |
| ALPN | ~5 | 协议协商 |

---

## 2. 不变量

- **[INV-1]** TLS 握手完成后才能 Send/Recv
- **[INV-2]** Close 发送 close_notify alert
- **[INV-3]** 证书验证失败时握手中止（除非显式关闭验证）
- **[INV-4]** TLS 1.3 的 AEAD nonce = sequence_number XOR write_iv

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 握手失败 | ETlsError |
| 证书无效 | ETlsError + 验证错误码 |
| 收到 alert | ETlsError + alert 描述 |
| 底层 socket 错误 | ENetworkError |

---

## 4. 线程安全

- ITlsContext: ❌ 调用方同步
- ITlsStream: ❌ 单连接使用
- 证书存储: ✅ 只读初始化后共享

---

## 5. 内存管理

- ITlsContext 拥有 SSL_CTX (OpenSSL) 或 SChannel credentials
- ITlsStream 拥有 SSL 对象 + 收发缓冲区
- Close 释放所有 TLS 资源
- 证书/密钥在 TLS 会话期间保持有效

---

## 6. 测试覆盖

17 个测试目录，覆盖 TLS 握手/数据传输/证书/ALPN/WebSocket。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本：231 文件 | Claude |
