# nextpas.core.http 代码契约

> 模块路径: `core/src/nextpas.core.http.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

HTTP 模块门面。提供 HTTP/1.1 服务器和客户端、路由、中间件、WebSocket 升级。

---

## 关键接口

```pascal
type
  THttpVersion = (hv10, hv11, hv20);
  THttpMethod = (hmGet, hmPost, hmPut, hmDelete, hmPatch, hmHead, hmOptions);
  THttpStatus = (hsOk, hsNotFound, hsBadRequest, ...);
  IHttpHeaders = interface ... end;
  IHttpRequest = interface ... end;
  IHttpResponse = interface ... end;
  IHttpHandler = interface ... end;
  IHttpMiddleware = interface ... end;
  IHttpRouter = interface ... end;
  IHttpServer = interface ... end;
  IHttpClient = interface ... end;

function HttpServer(APort: UInt16): IHttpServer;
function HttpClient: IHttpClient;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 请求解析失败 | 400 Bad Request |
| 路由未匹配 | 404 Not Found |
| 中间件超时 | 408 Request Timeout |
| 服务器内部错误 | 500 Internal Server Error |

---

## 线程安全

- IHttpServer 线程安全（多连接并发）
- IHttpClient 线程安全（连接池）
- IHttpRequest/IHttpResponse 不线程安全（per-connection）

---

## 依赖关系

- 依赖: base, net, io, json, text, sync, collections
- 被依赖: websocket, 应用层

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
