# nextpas.core.http 代码契约

> 模块路径: `core/src/nextpas.core.http.*.pas`
> 创建日期: 2026-07-04
> 最后更新: 2026-07-06
> 维护者: AI
> 模块文档: [core/docs/http/](../../core/docs/http/)

---

## 概述

HTTP/1.1 + HTTP/2 双协议实现，包含客户端、服务器、路由、中间件、WebSocket。35 个源文件，31 个测试套件 ~1400+ 测试。

---

## 关键接口

```pascal
type
  THttpMethod = (hmGet, hmHead, hmPost, hmPut, hmDelete, hmPatch, hmOptions);
  THttpVersion = (hv10, hv11, hv20);

  IHttpHeaders = interface;    // HTTP 头管理
  IHttpRequest = interface;    // 请求消息
  IHttpResponse = interface;   // 响应消息
  IHttpHandler = interface;    // 请求处理器
  IHttpMiddleware = interface; // 中间件
  IHttpRouter = interface;     // 路由器
  IHttpServer = interface;     // 服务器
  IHttpClient = interface;     // 客户端

function NewHttpClient: IHttpClient;
function NewHttpServer(APort: UInt16): IHttpServer;
function NewHttpResponse(AStatusCode: UInt16; const ABody: string): IHttpResponse;
function NewHttpRequest(AMethod: THttpMethod; const AUrl: string): IHttpRequest;
```

---

## 错误语义

| 场景 | 行为 | 异常类型 |
|------|------|----------|
| 请求解析失败 | 400 Bad Request | EHttpParseError |
| 路由未匹配 | 404 Not Found | — (返回响应) |
| 中间件超时 | 408 Request Timeout | EHttpTimeout |
| 连接超时 | 408 Request Timeout | EHttpTimeout |
| 服务器内部错误 | 500 Internal Server Error | — (Recovery 中间件) |
| Header 注入 | 拒绝请求 | EHttpError |
| 路径遍历 | 拒绝请求 | EHttpError |
| 请求走私 | 拒绝请求 | EHttpError |

---

## 线程安全

| 接口 | 线程安全 | 说明 |
|------|----------|------|
| IHttpServer | ✅ | 多连接并发 |
| IHttpClient | ✅ | 连接池内部同步 |
| IHttpRouter | ❌ | 配置阶段单线程 |
| IHttpRequest | ❌ | per-connection |
| IHttpResponse | ❌ | per-connection |
| IHttpHeaders | ❌ | per-request |

---

## 依赖关系

```
nextpas.core.http
  ├── L0: base, errors, platform, mem, log.intf
  ├── L1: text, collections, sync, async, stream
  ├── L2: net.tcp, tls
  └── L3: self
```

被依赖: 应用层

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-06 | Response parser pause + same-read tail 检测 | 修复同 TCP segment 多响应检测 |
| 2026-07-06 | IPv4 字节序修复 | bind(99) 根因修复 |
| 2026-07-06 | Connection:close 响应处理 | 客户端容忍额外数据 |
| 2026-07-04 | 初始版本 | 契约建立 |
