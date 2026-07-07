# nextpas.core.http 代码契约

**模块路径**：`core/src/nextpas.core.http*.pas`（36 个源文件）
**层级**：L3（依赖 L0-L2: net, tls, json）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-06
**版本**：2.0

---

## 1. 接口契约

### 1.1 子模块

```
http.base          ← THttpMethod, THttpStatus, THttpVersion, TUrl, EHttpError,
                     THttpClientOptions, THttpServerOptions, HttpStatusText
http.headers       ← THttpHeaders (header storage, RFC 9110 validation)
http.request       ← THttpRequest (value type)
http.response      ← THttpResponse (value type)
http.client        ← IHttpClient (transport abstraction), THttpClient (facade)
http.server        ← IHttpServer (transport abstraction), THttpServer (facade)
http.middleware.*   ← CORS, logging, rate-limit, request-id, recovery, compress
http.impl.h1       ← HTTP/1.1 transport (client + server)
http.impl.h2.*     ← HTTP/2 transport (client + server + TLS + HPACK)
http.impl.registry ← Default protocol registry (H1/H2 factory resolution)
http.static        ← Static file serving middleware
http.pas           ← 门面 (re-exports)
```

### 1.2 核心接口

```pascal
{ Transport abstraction — one instance per connection }
IHttpClient = interface
  function GetOptions: THttpClientOptions;
  procedure SetOptions(const AValue: THttpClientOptions);
  function RoundTrip(const AReq: THttpRequest): THttpResponse;
  property Options: THttpClientOptions read GetOptions write SetOptions;
end;

IHttpServer = interface
  function GetRequestHandler: THttpServerRequestEvent;
  procedure SetRequestHandler(const AValue: THttpServerRequestEvent);
  procedure AddRoute(const AMethod, APath: string;
    const AHandler: THttpServerRequestEvent);
  procedure AddMiddleware(const AMiddleware: IHttpMiddleware);
  procedure SetDefaultHandler(const AHandler: THttpServerRequestEvent);
  procedure Start;
  procedure Stop;
end;
```

### 1.3 请求/响应值类型

```pascal
THttpRequest = record
  Method: string;             { GET, POST, etc. (uppercase) }
  RequestTarget: string;      { /path?query }
  Version: THttpVersion;      { hvHttp10, hvHttp11, hvHttp2 }
  Headers: THttpHeaders;      { owned by caller }
  Body: TBytes;               { nil = no body }
  Trailers: THttpHeaders;     { for chunked trailer }
  MaxResponseBodySize: Int64; { 0 = default (32MB) }
end;

THttpResponse = record
  Version: THttpVersion;
  StatusCode: THttpStatus;    { UInt16 }
  StatusText: string;
  Headers: THttpHeaders;
  Body: TBytes;
  Trailers: THttpHeaders;
  IsInformational: Boolean;   { 1xx }
  GetSkippableInformational: Boolean; { 100/101/103 }
  HeaderBytes: Int64;
end;
```

### 1.4 HTTP/2

- HPACK 头部压缩/解压 (`nextpas.core.http.impl.h2.hpack`)
- 帧解析 (`nextpas.core.http.impl.h2.h2frame`)
- 流多路复用 + 流量控制 (`nextpas.core.http.impl.h2.client/server`)
- TLS ALPN 协商 h2 (`nextpas.core.http.impl.h2.tls`)
- 连接池: `TH2ConnectionPool` (线程安全, `FPoolLock: TRTLCriticalSection`)

### 1.5 HTTP/1.1

- llhttp C 库解析 (`nextpas.core.http.impl.h1.parser`)
- 连接池: `TH1ConnectionPool` (线程安全, `FPoolLock: TRTLCriticalSection`)
- keep-alive 默认开启, `Connection: close` 正确处理
- 响应解析器在 keep-alive 消息完成后暂停 (HPE_PAUSED)

---

## 2. 不变量

- **[INV-1]** HTTP/1.1 keep-alive 默认开启，`Connection: close` 响应后连接不复用
- **[INV-2]** HTTP/2 流 ID 奇偶分离（客户端奇/服务端偶）
- **[INV-3]** HPACK 动态表有大小上限 (SETTINGS_MAX_HEADER_TABLE_SIZE)
- **[INV-4]** chunked 编码以 0 长度块终止，可带 trailers
- **[INV-5]** 响应解析器在 keep-alive 消息完成后暂停 (HPE_PAUSED)，保留未消费字节
- **[INV-6]** 注册表初始化后冻结 (GFrozen)，运行时不可修改
- **[INV-7]** THttpHeaders 名称规范化: 小写存储，查找时大小写不敏感
- **[INV-8]** THttpHeaders 值验证: 拒绝 CR/LF/控制字符，允许 HTAB (RFC 9110 §5.5)

---

## 3. 错误处理

所有错误通过 `EHttpError` (继承 `ENextPasError`, 错误码 `ecNetwork`) 统一报告:

| 场景 | 抛出位置 | 消息模式 |
|------|----------|----------|
| 连接失败 | `TH1ClientTransport.ConnectSocket` | `'connect failed: ' + host + ':' + port + ': ' + msg` |
| TLS 握手失败 | `TH2TlsClientTransport.RoundTrip` | `'TLS handshake failed: ' + SysErrorMessage` |
| 协议错误 | `TH1ClientTransport.ReadResponse` | `'HTTP response incomplete: ' + msg` |
| 断言失败 | `TH2ClientTransport.AssertSuccess` | `'nghttp2 ' + funcName + ' failed: ' + errorCode` |
| 注册表冻结后修改 | `registry.Register/Unregister/SetDefault` | `'registry frozen: cannot ...'` |
| Header 名称无效 | `THttpHeaders.ValidateName` | `'header name must not be empty'` |
| Header 值无效 | `THttpHeaders.ValidateValue` | `'invalid header value character'` |

超时由 HTTP 客户端包装层处理: 比较 `DateTimeToSTicks(Now) - LStartTime >= LTimeout`。

---

## 4. 线程安全

| 组件 | 线程安全 | 机制 |
|------|----------|------|
| `IHttpClient` | ✅ | 连接池用 `TRTLCriticalSection` 保护 |
| `IHttpServer` | ✅ | Handler 由 TCP server 线程池调用 |
| `THttpHeaders` | ✅ 读 | 只读操作无锁; 写操作非线程安全 |
| `THttpClient` | ✅ | 内部持有 `IHttpClient`，`Options` 写时创建新 transport |
| `THttpServer` | ✅ | 内部持有 `IHttpServer`，`Options` 写时创建新 server |
| 注册表 | ✅ | 初始化后冻结，读操作无锁 |

---

## 5. 内存管理

- **请求/响应 body**: `TBytes`，调用方管理生命周期
- **THttpHeaders**: 值类型 record，内部 `FEntries` 动态数组，浅拷贝共享引用
- **HPACK 动态表**: 内置于 H2 连接，连接关闭时释放
- **连接池**: `THttpClient.Destroy` 时断开所有池连接
- **llhttp 解析器**: 每连接一个 `llhttp_t`，连接关闭时释放

---

## 6. 性能特征

- **Header 查找**: O(n) 线性扫描，规范化仅在首次查找时触发
- **连接池**: 空闲连接复用，避免 TCP 握手开销
- **HPACK**: 动态表减少重复头部传输
- **llhttp**: C 库解析，比 Pascal 实现快 ~10x
- **Body 传输**: `TBytes` 零拷贝传递 (引用计数)

---

## 7. 测试覆盖

- **31 个测试套件**, ~1447 测试
- **测试工具**: `tests/harness/` (TCP echo server, TLS cert gen, binary validator)
- **关键覆盖**: HTTP/1.1 解析, HTTP/2 帧, HPACK, keep-alive, chunked, CORS, 中间件
- **已知缺口**: TLS mock 测试缺失, 100 Continue 仅基本覆盖, 压力测试待建

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
| 2026-07-06 | 2.0 | 完全重写: 匹配实际代码接口，修正错误类型/线程安全描述 | Claude |
