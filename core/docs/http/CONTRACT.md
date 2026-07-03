# nextpas.core.http 代码契约

**模块路径**：`core/src/nextpas.core.http*.pas`（36 个源文件）
**层级**：L3（依赖 L0-L2: net, tls, json）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

```
http.base          ← THttpMethod, THttpStatusCode, THttpHeaders
http.client        ← IHttpClient (GET/POST/PUT/DELETE...)
http.server        ← IHttpServer (路由/中间件/请求处理)
http.request       ← THttpRequest 记录
http.response      ← THttpResponse 记录
http.h2.*          ← HTTP/2 协议实现 (HPACK/frames/stream)
http.hpack         ← HTTP/2 头部压缩
http.chunked       ← Transfer-Encoding: chunked
http.cookie        ← Cookie 管理
http.form           ← multipart/form-data
http.pas           ← 门面
```

### 1.2 核心接口

```pascal
IHttpClient = interface
  function Get(const AUrl: string): THttpResponse;
  function Post(const AUrl: string; const ABody: TBytes): THttpResponse;
  function Put(const AUrl: string; const ABody: TBytes): THttpResponse;
  function Delete(const AUrl: string): THttpResponse;
  procedure SetHeader(const AName, AValue: string);
  procedure SetTimeout(AMs: UInt32);
end;

IHttpServer = interface
  procedure Get(const APath: string; AHandler: THttpHandler);
  procedure Post(const APath: string; AHandler: THttpHandler);
  procedure Listen(APort: UInt16);
  procedure Stop;
end;
```

### 1.3 HTTP/2

- HPACK 头部压缩/解压
- 帧解析 (DATA/HEADERS/RST_STREAM/SETTINGS/PUSH_PROMISE...)
- 流多路复用
- TLS ALPN 协商 h2

---

## 2. 不变量

- **[INV-1]** HTTP/1.1 keep-alive 默认开启
- **[INV-2]** HTTP/2 流 ID 奇偶分离（客户端奇/服务端偶）
- **[INV-3]** HPACK 动态表有大小上限
- **[INV-4]** chunked 编码以 0 长度块终止

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 连接失败 | ENetworkError |
| 超时 | ETimeoutError |
| HTTP 错误码 | THttpResponse.Status 检查 |
| 协议错误 | EParseError |

---

## 4-6. 概要

- **线程安全**: IHttpClient ❌ (单连接); IHttpServer Handler 多线程调用
- **内存**: 请求/响应 body 为 TBytes, 调用方管理; HPACK 动态表内置于连接
- **测试**: 31 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
