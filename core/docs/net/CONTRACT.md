# nextpas.core.net 代码契约

**模块路径**：`core/src/nextpas.core.net*.pas`（14 个源文件）
**层级**：L2（依赖 L0-L1, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-24
**版本**：1.1

---

## 1. 接口契约

### 1.1 模块结构

```
net.base         ← TIPAddress, TSocketType, TProtocol 枚举
net.addr         ← TIPAddress 解析/格式化
net.socket       ← ISocket 接口 (Connect/Bind/Listen/Accept/Send/Recv/Close)
net.tcp          ← TCP 客户端/服务端
net.udp          ← UDP 收发
net.resolver     ← DNS 解析 (GetAddrInfo)
net.uri          ← URI 解析/构建
net.http.types   ← HTTP 请求/响应记录
net.pas          ← 门面
```

### 1.2 核心接口

```pascal
ISocket = interface
  function Send(const AData; ASize: SizeInt): SizeInt;
  function Recv(var AData; ASize: SizeInt): SizeInt;
  procedure Close;
  function GetRemoteAddr: TIPAddress;
  function GetRemotePort: UInt16;
end;
```

---

## 2. 不变量

- **[INV-1]** Socket Close 后不再操作（EBADF）
- **[INV-2]** Send/Recv 返回实际收发字节数（可能 < 请求量）
- **[INV-3]** URI 解析保持原始格式保真（Parse → ToString 往返）

---

## 3-6. 概要

- **错误**: 网络错误抛 ENetworkError, 超时抛 ETimeoutError
- **线程安全**: Socket 非线程安全, Resolver 线程安全
- **内存**: Socket 拥有底层 fd, Close 释放; Send/Recv 缓冲区由调用方管理
- **测试**: 2 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-08-24 | 1.1 | 导出 StripHostBrackets / HostIsIpLiteral / TryParseIPv4；TDnsResult.PreferredAddress；TNetAddress.WithPort | proxy888 反哺 |
| 2026-07-01 | 1.0 | 初始版本 | Claude |
