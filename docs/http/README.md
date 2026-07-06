# nextpas.core.http — HTTP 模块

HTTP/1.1 + HTTP/2 双协议实现，包含客户端、服务器、路由、中间件、WebSocket。

## Quick Start

### 客户端

```pascal
uses nextpas.core.http;

var
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  LClient := NewHttpClient;
  LResp := LClient.Get('https://example.com/api');
  WriteLn(LResp.StatusCode);        // 200
  WriteLn(HttpReadResponseBodyString(LResp));  // response body
end.
```

### 服务器

```pascal
uses nextpas.core.http;

var
  LServer: IHttpServer;
begin
  LServer := NewHttpServer(8080);
  LServer.Get('/hello', function(AReq: IHttpRequest): IHttpResponse
  begin
    Result := NewHttpResponse(200, 'Hello, World!');
  end);
  LServer.ListenAndServe;
end.
```

## 模块结构

```
nextpas.core.http.pas                  ← 门面 (re-export)
nextpas.core.http.base.pas             ← 基础类型 (THttpMethod, THttpVersion 等)
nextpas.core.http.intf.pas             ← 接口定义 (IHttpRequest, IHttpResponse 等)
nextpas.core.http.url.pas              ← URL 解析
nextpas.core.http.headers.pas          ← HTTP 头管理
nextpas.core.http.message.pas          ← 请求/响应消息体
nextpas.core.http.client.pas           ← 客户端 (连接池、重试、重定向)
nextpas.core.http.server.pas           ← 服务器 (会话管理、生命周期)
nextpas.core.http.router.pas           ← 路由器 (路径匹配、参数提取)
nextpas.core.http.middleware.pas       ← 中间件框架
nextpas.core.http.middleware.*.pas     ← 内置中间件 (CORS, Logger, Recovery, Timeout)
nextpas.core.http.static.pas           ← 静态文件服务
nextpas.core.http.websocket.pas        ← WebSocket 升级
nextpas.core.http.impl.h1.*.pas        ← HTTP/1.1 实现层
nextpas.core.http.impl.h2.*.pas        ← HTTP/2 实现层
nextpas.core.http.impl.registry.pas    ← 传输层注册表
nextpas.core.http.impl.tls.stream.pas  ← TLS 流适配
```

## 依赖

```
L0: base, errors, platform, mem, log.intf
L1: bytes, text, collections, sync, async, stream
L2: fs, net, tls, crypto
L3: http ← 当前模块
```

## 构建与验证

```bash
make -C core/tests/nextpas.core.http/test_http_client clean test
make -C core/tests/nextpas.core.http/test_http_contract clean test
make -C core/tests/nextpas.core.http/test_http_server clean test
```

## 文档索引

| 文档 | 内容 |
|------|------|
| [ROADMAP.md](ROADMAP.md) | 开发路线图与阶段规划 |
| [ARCHITECTURE.md](ARCHITECTURE.md) | 模块架构与设计决策 |
| [GOAL_TREE.md](GOAL_TREE.md) | 分阶段目标树 |
| [API_REFERENCE.md](API_REFERENCE.md) | 公共 API 参考 |
| [KNOWN_LIMITS.md](KNOWN_LIMITS.md) | 已知限制与边界 |
| [CHANGELOG.md](CHANGELOG.md) | 版本历史 |

## 测试覆盖

31 个测试套件，~1400+ 测试：

| 域 | 套件 | 测试数 |
|----|------|--------|
| H1 Parser | h1parser, h1scan, h1fast | ~153 |
| H1 Writer | h1writer, h1chunked, h1outbound | ~59 |
| H2 Core | h2_frame, h2_types, h2_hpack, h2_hpack_block | ~67 |
| H2 Session | h2_stream, h2_session, h2_client | ~95 |
| HTTP Core | headers, message, url, base | ~130 |
| Client | client | ~133 |
| Server | server, contract, registry | ~317 |
| Router/Middleware | router, middleware, middlewares | ~49 |
| Security | security | ~247 |
| Other | static, websocket, integration, examples, smoke, benchmarks | ~207 |
