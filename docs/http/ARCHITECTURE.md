# nextpas.core.http 架构文档

## 分层架构

```
┌─────────────────────────────────────────────────────────┐
│  门面层: nextpas.core.http                              │
│  纯 re-export, 用户唯一入口                              │
├─────────────────────────────────────────────────────────┤
│  接口层: intf, base                                     │
│  IHttpRequest, IHttpResponse, IHttpHandler, IHttpRouter │
├─────────────────────────────────────────────────────────┤
│  功能层: client, server, router, middleware, static,     │
│          websocket, url, headers, message                │
├─────────────────────────────────────────────────────────┤
│  协议层: impl.h1.*, impl.h2.*                           │
│  HTTP/1.1: llhttp → parser → chunked → writer → fast    │
│  HTTP/2: frame → hpack → stream → session → client/srv  │
├─────────────────────────────────────────────────────────┤
│  传输层: impl.registry, impl.tls.stream                 │
│  TCP/TLS 连接管理, ALPN 协商                            │
└─────────────────────────────────────────────────────────┘
```

## 核心设计决策

### 1. llhttp 绑定而非手写解析器

使用 Node.js 的 llhttp 作为 HTTP/1.1 解析器后端：
- 经过亿万级生产验证
- 零拷贝设计 (回调式解析)
- 自动处理 chunked、Connection: close、Transfer-Encoding 优先级
- FFI 绑定在 `impl.h1.llhttp.pas`

### 2. 双协议统一接口

`IHttpTransport` 接口抽象了 H1 和 H2 的差异：
- `TH1ClientTransport` / `TH1ServerTransport` — HTTP/1.1
- `TH2ClientTransport` / `TH2ServerTransport` — HTTP/2
- 通过 `impl.registry` 自动选择，ALPN 协商决定协议

### 3. 连接池设计

客户端连接池 (`TH1ClientTransport.FPool`)：
- per-host:port 隔离
- 空闲连接复用 (非阻塞1字节读检测)
- `Connection: close` / 响应尾部自动丢弃
- 幂等请求失败自动重试

### 4. 中间件洋葱模型

```
Request → Middleware1.Before → Middleware2.Before → Handler
Response ← Middleware1.After ← Middleware2.After ← Handler
```

每个中间件实现 `IHttpMiddleware`：
- `BeforeRequest` — 请求预处理
- `AfterResponse` — 响应后处理
- `OnError` — 异常处理

### 5. 路由器设计

`THttpRouter` 实现：
- 精确匹配 (`/api/users`)
- 参数匹配 (`/api/users/:id`)
- 通配符匹配 (`/static/*`)
- 方法分发 (GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS)
- 中间件链按路由组挂载

## HTTP/1.1 实现细节

### 解析流水线

```
TCP Stream → llhttp_execute → CbOnHeaders → CbOnBody → CbOnMessageComplete
                                    ↓              ↓              ↓
                              THttpHeaders   IReader       FComplete=True
                                              (body)        (HPE_PAUSED)
```

### 快速路径

`TH1FastParser` 为最常见的 GET 200 Content-Length 场景优化：
- 零内存分配
- 手写状态机 (不经过 llhttp)
- 命中率取决于响应复杂度

### Chunked 编码

```
编码: body → "size\r\n" + chunk + "\r\n" → ... → "0\r\n\r\n"
解码: 解析 size → 读取 chunk → 处理 trailer → 完成
```

## HTTP/2 实现细节

### 帧格式

```
+-----------------------------------------------+
|                 Length (24)                    |
+---------------+---------------+---------------+
|   Type (8)    |   Flags (8)   |
+-+-------------+---------------+---------------+
|R|                 Stream ID (31)              |
+-+---------------------------------------------+
|                   Frame Payload ...            |
+-----------------------------------------------+
```

### HPACK 压缩

- 静态表: 61 个预定义头部字段
- 动态表: 连接期间学习的头部字段
- Huffman 编码: 高频字符用短编码

### 流状态机

```
idle → open → half-closed (local) → closed
                    ↓
          half-closed (remote) → closed
```

## 安全模型

### 已实现防护

| 攻击向量 | 防护机制 |
|----------|----------|
| 请求走私 | Transfer-Encoding 优先级检查 |
| Host 注入 | Host 头值验证 |
| 路径遍历 | 路径规范化 + `..` 拒绝 |
| Header 注入 | CR/LF 字符拒绝 |
| CORS | 预检 + Origin 验证 |

### TLS 集成

- ALPN 协商: `h2` 优先，回退 `http/1.1`
- TLS 流适配: `TTlsStream` 实现 `IStream`
- 证书验证: 委托给 `nextpas.core.tls`

## 依赖关系

```
nextpas.core.http
  ├── nextpas.core.base          (TBytes, SizeInt)
  ├── nextpas.core.text          (字符串处理)
  ├── nextpas.core.collections   (THttpHeaders 内部存储)
  ├── nextpas.core.stream        (IStream, IReader, IWriter)
  ├── nextpas.core.net.tcp       (TTcpStream, TTcpListener)
  ├── nextpas.core.tls           (TLS 握手)
  ├── nextpas.core.log.intf      (日志接口)
  ├── nextpas.core.platform      (平台抽象)
  └── nextpas.core.mem           (内存分配)
```
