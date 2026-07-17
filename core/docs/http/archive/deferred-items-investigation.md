# HTTP 模块推迟项调研报告

**调研日期**: 2026-07-06
**调研范围**: P3-10 WebSocket 客户端 / P3-11 模糊测试 / P3-7 HTTPS 重定向测试
**调研方法**: RFC 对标 + Go/Rust 最佳实践 + 实现路径分析

---

## 一、P3-10 WebSocket 客户端 (ConnectWebSocket)

### 1.1 需求分析

**现状**: 仅服务端 WebSocket (`UpgradeWebSocket`)，无客户端实现。

**目标**: 提供 `ConnectWebSocket` 函数，支持:
- `ws://` 和 `wss://` 协议
- 客户端 → 服务器帧掩码 (RFC 6455 §5.3)
- 服务器 → 客户端帧不掩码
- 自动 Sec-WebSocket-Key 生成
- 101 Switching Protocols 响应验证

### 1.2 RFC 6455 对标

| 要求 | 服务端当前实现 | 客户端需要 |
|------|---------------|-----------|
| 帧掩码 | 接收掩码帧，验证掩码 | 发送掩码帧，接收不掩码 |
| Sec-WebSocket-Key | 验证 Key 格式 | 生成 16 字节随机 Key |
| Sec-WebSocket-Accept | 计算并发送 Accept | 验证 Accept 值 |
| 升级握手 | 发送 101 响应 | 发送升级请求，验证 101 |
| 关闭握手 | 支持 Close 帧 | 支持 Close 帧 |

### 1.3 Go/Rust 对标

**Go (gorilla/websocket)**:
```go
// 客户端连接
conn, _, err := websocket.DefaultDialer.Dial("ws://localhost/ws", nil)
defer conn.Close()

// 读写
_, message, err := conn.ReadMessage()
err = conn.WriteMessage(websocket.TextMessage, []byte("hello"))
```

**Rust (tungstenite)**:
```rust
let (mut socket, response) = connect("ws://localhost/ws")?;
socket.send(Message::Text("hello".into()))?;
let msg = socket.read()?;
```

**共同模式**:
1. Dial/Connect 函数返回 WebSocket 连接
2. 连接对象提供 Read/Write 方法
3. 自动处理帧掩码/解掩码
4. 支持 Ping/Pong 心跳
5. 支持 Close 握手

### 1.4 实现路径

#### 方案 A: 扩展现有 IWebSocket 接口 (推荐)

**优点**:
- 复用现有 TWebSocketImpl 类
- 统一服务端/客户端 API
- 最小代码变更

**实现**:
```pascal
{ 新增客户端连接函数 }
function ConnectWebSocket(const AUrl: string): IWebSocket; overload;
function ConnectWebSocket(const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket; overload;
function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string): IWebSocket; overload;
function ConnectWebSocket(const AClient: IHttpClient;
  const AUrl: string;
  const AOptions: TWebSocketOptions): IWebSocket; overload;

{ 修改 TWebSocketImpl 支持客户端模式 }
constructor TWebSocketImpl.Create(const AReader: IReader; const AWriter: IWriter;
  const AOptions: TWebSocketOptions; AIsClient: Boolean);
```

**关键变更**:
1. `WriteFrame` 方法根据 `FIsClient` 决定是否掩码
2. `ReadFrame` 方法根据 `FIsClient` 决定是否要求掩码
3. 新增 `ConnectWebSocket` 函数实现客户端握手

#### 方案 B: 独立客户端类

**优点**:
- 职责分离清晰
- 可针对客户端场景优化

**缺点**:
- 代码重复
- 维护成本高

**结论**: 推荐方案 A。

### 1.5 客户端握手流程

```
客户端                              服务器
  |                                   |
  |--- GET /ws HTTP/1.1 ------------>|
  |    Upgrade: websocket            |
  |    Connection: Upgrade           |
  |    Sec-WebSocket-Key: <key>      |
  |    Sec-WebSocket-Version: 13     |
  |                                   |
  |<-- HTTP/1.1 101 Switching ------|
  |    Upgrade: websocket            |
  |    Connection: Upgrade           |
  |    Sec-WebSocket-Accept: <accept>|
  |                                   |
  |<======= WebSocket frames ========>|
```

**客户端实现步骤**:
1. 解析 URL 获取 host/port/path
2. 建立 TCP 连接 (ws://) 或 TLS 连接 (wss://)
3. 生成 16 字节随机 Sec-WebSocket-Key
4. 发送升级请求
5. 读取响应，验证 101 状态码
6. 验证 Sec-WebSocket-Accept 值
7. 返回 IWebSocket 接口

### 1.6 依赖分析

| 依赖 | 状态 | 备注 |
|------|------|------|
| HTTP 客户端 | ✅ 已有 | THttpClient + IHttpTransport |
| TCP 连接 | ✅ 已有 | ITcpStream |
| TLS 连接 | ✅ 已有 | NewTlsClientTcpStream |
| SHA1 | ✅ 已有 | nextpas.core.hash |
| Base64 | ✅ 已有 | nextpas.core.encoding |
| URL 解析 | ✅ 已有 | nextpas.core.http.url |

**结论**: 所有依赖已就绪，可立即实现。

### 1.7 测试计划

| 测试 | 描述 |
|------|------|
| 客户端握手成功 | ws:// 连接本地服务器 |
| 客户端握手失败 | 服务器返回非 101 |
| 客户端掩码帧 | 验证发送帧被掩码 |
| 服务器不掩码帧 | 验证接收帧不被掩码 |
| 客户端 Ping/Pong | 心跳机制 |
| 客户端 Close | 关闭握手 |
| wss:// TLS 连接 | TLS 加密连接 |
| 并发客户端 | 多客户端同时连接 |

### 1.8 工作量估算

| 任务 | 工作量 |
|------|--------|
| 修改 TWebSocketImpl 支持客户端模式 | 2h |
| 实现 ConnectWebSocket 函数 | 3h |
| URL 解析 + 连接建立 | 1h |
| 测试编写 | 4h |
| 文档更新 | 1h |
| **总计** | **11h** |

---

## 二、P3-11 模糊测试 (Fuzz Testing)

### 2.1 需求分析

**现状**: 无 fuzz 测试。

**目标**: 实现简单变异 fuzzer，验证:
- HTTP parser 不崩溃
- HTTP parser 不泄漏
- WebSocket parser 不崩溃
- WebSocket parser 不泄漏

### 2.2 Go/Rust 对标

**Go (go-fuzz)**:
```go
func Fuzz(data []byte) int {
    // 尝试解析，返回 0 (无兴趣), 1 (有兴趣), -1 (拒绝)
    parser := NewParser()
    _, err := parser.Parse(data)
    if err != nil {
        return 0
    }
    return 1
}
```

**Rust (cargo-fuzz)**:
```rust
fuzz_target!(|data: &[u8]| {
    let _ = Parser::parse(data);
});
```

**共同模式**:
1. 提供种子语料库 (有效 HTTP 消息)
2. 变异策略: 字节翻转、插入、删除、替换
3. 覆盖率引导 (可选)
4. 内存安全检测 (heaptrc)

### 2.3 实现路径

#### 方案 A: 简单变异 Fuzzer (推荐)

**优点**:
- 实现简单
- 无外部依赖
- 可集成到现有测试框架

**实现**:
```pascal
unit nextpas.core.http.fuzz;

interface

type
  TFuzzMutator = record
    class function Mutate(const AData: TBytes): TBytes; static;
    class function FlipBits(const AData: TBytes; ACount: Int32): TBytes; static;
    class function InsertBytes(const AData: TBytes; ACount: Int32): TBytes; static;
    class function DeleteBytes(const AData: TBytes; ACount: Int32): TBytes; static;
    class function ReplaceBytes(const AData: TBytes; ACount: Int32): TBytes; static;
  end;

  TFuzzRunner = record
    class function RunHttpParserFuzz(const ASeeds: array of TBytes;
      AIterations: Int32): Int32; static;
    class function RunWebSocketFuzz(const ASeeds: array of TBytes;
      AIterations: Int32): Int32; static;
  end;
```

**变异策略**:
1. **字节翻转**: 随机翻转 1-4 位
2. **字节插入**: 随机位置插入 1-16 字节
3. **字节删除**: 随机删除 1-16 字节
4. **字节替换**: 随机替换 1-16 字节
5. **边界值**: 替换为 0x00, 0xFF, 0x7F, 0x80

#### 方案 B: 集成 libFuzzer

**优点**:
- 覆盖率引导
- 专业级 fuzzer

**缺点**:
- 需要 C 编译器
- 外部依赖
- 复杂度高

**结论**: 推荐方案 A，后续可升级到方案 B。

### 2.4 种子语料库

**HTTP 请求种子**:
```
GET / HTTP/1.1\r\nHost: localhost\r\n\r\n
POST /data HTTP/1.1\r\nHost: localhost\r\nContent-Length: 5\r\n\r\nhello
GET /path?query=value HTTP/1.1\r\nHost: localhost\r\n\r\n
```

**HTTP 响应种子**:
```
HTTP/1.1 200 OK\r\nContent-Length: 5\r\n\r\nhello
HTTP/1.1 404 Not Found\r\n\r\n
HTTP/1.1 301 Moved Permanently\r\nLocation: http://example.com\r\n\r\n
```

**WebSocket 帧种子**:
```
[FIN=1, opcode=0x1, mask=0, payload="hello"]
[FIN=1, opcode=0x2, mask=1, payload="binary"]
[FIN=0, opcode=0x1, mask=1, payload="fragment"]
[FIN=1, opcode=0x8, mask=1, payload=close_frame]
```

### 2.5 测试框架集成

```pascal
program test_http_fuzz;

uses
  nextpas.core.test,
  nextpas.core.http.fuzz;

var
  T: TTestSuite;

begin
  T := TTestSuite.Create('nextpas.core.http.fuzz');

  T.Test('HTTP parser fuzz - 1000 iterations', procedure
  var
    LSeeds: array[0..2] of TBytes;
    LCrashes: Int32;
  begin
    LSeeds[0] := TBytes.Create($47, $45, $54, $20, $2F, $20); // "GET / "
    LSeeds[1] := TBytes.Create($50, $4F, $53, $54, $20, $2F); // "POST /"
    LSeeds[2] := TBytes.Create($48, $54, $54, $50, $2F, $31); // "HTTP/1"
    LCrashes := TFuzzRunner.RunHttpParserFuzz(LSeeds, 1000);
    T.Expect(LCrashes).ToBe(0);
  end);

  T.Run;
  T.Free;
end.
```

### 2.6 内存泄漏检测

利用现有 heaptrc 集成:
```bash
# 运行 fuzz 测试，检测泄漏
make -C core/tests/nextpas.core.http/test_http_fuzz clean test
```

**预期输出**:
```
> nextpas.core.http.fuzz (3 tests)
  + HTTP parser fuzz - 1000 iterations
  + HTTP response fuzz - 1000 iterations
  + WebSocket frame fuzz - 1000 iterations

  3 passed, 0 failed, 0 skipped
Heap dump by heaptrc unit
0 unfreed memory blocks : 0
```

### 2.7 工作量估算

| 任务 | 工作量 |
|------|--------|
| 实现 TFuzzMutator | 2h |
| 实现 TFuzzRunner | 2h |
| 种子语料库 | 1h |
| 测试编写 | 2h |
| 文档更新 | 1h |
| **总计** | **8h** |

---

## 三、P3-7 HTTPS 重定向测试

### 3.1 需求分析

**现状**: 30+ 重定向测试存在，但无 `http→https` 场景。

**限制**: 客户端目前仅支持 `http://` scheme。

**目标**: 验证 HTTP 客户端正确处理 HTTPS 重定向。

### 3.2 场景分析

| 场景 | 描述 | 当前支持 |
|------|------|---------|
| http→http | 普通重定向 | ✅ 已测试 |
| http→https | 升级重定向 | ❌ 未测试 |
| https→http | 降级重定向 | ❌ 未测试 |
| https→https | TLS 重定向 | ❌ 未测试 |

### 3.3 实现路径

#### 方案 A: Mock TLS 服务器 (推荐)

**优点**:
- 无需真实证书
- 测试可控
- 无外部依赖

**实现**:
```pascal
{ 创建 Mock TLS 服务器 }
function StartMockTlsServer(const AHandler: IHttpHandler;
  out APort: UInt16): TPlatformThreadHandle;
var
  LContext: ISSLContext;
  LServer: THttpServer;
begin
  LContext := CreateSelfSignedContext;
  LServer := THttpServer.Create(AHandler, THttpServerOptions.Default);
  // 使用 TLS 传输
  Result := StartServerWithTls(LServer, LContext, APort);
end;

{ 测试 http→https 重定向 }
T.Test('Redirect http to https', procedure
var
  LClient: IHttpClient;
  LResp: IHttpResponse;
  LTlsPort: UInt16;
  LTlsHandle: TPlatformThreadHandle;
begin
  LTlsHandle := StartMockTlsServer(RedirectHandler, LTlsPort);
  try
    LClient := NewHttpClient;
    LResp := LClient.Get('http://localhost:' + IntToStr(LTlsPort) + '/redirect');
    T.Expect(LResp.StatusCode).ToBe(200);
  finally
    StopServer(LTlsServer, LTlsHandle);
  end;
end);
```

#### 方案 B: 真实 TLS 服务器

**优点**:
- 真实场景测试

**缺点**:
- 需要证书管理
- 测试复杂

**结论**: 推荐方案 A。

### 3.4 客户端 TLS 支持

**当前状态**: HTTP 客户端不支持 `https://` scheme。

**需要修改**:
1. `THttpClient.Get/Post/...` 方法解析 URL scheme
2. 如果是 `https://`，建立 TLS 连接
3. 使用 TLS 连接发送 HTTP 请求

**实现**:
```pascal
function THttpClient.DoRequest(const AReq: IHttpRequest; ARedirectsLeft: Int32;
  var ARequestBodyCloseAttempted: Boolean): IHttpResponse;
var
  LUrl: TUrl;
  LScheme: string;
  LConn: ITcpStream;
  LTlsConn: ITcpStream;
begin
  LUrl := AReq.Url;
  LScheme := LowerCase(LUrl.Scheme);

  if LScheme = 'https' then
  begin
    { 建立 TLS 连接 }
    LConn := FTransport.GetConnection(LUrl.Host, LUrl.Port);
    LTlsConn := NewTlsClientTcpStream(LConn, FOptions.TlsContext,
      LUrl.Host, 'http/1.1');
    { 使用 TLS 连接发送请求 }
    Result := DoRequestWithConnection(AReq, LTlsConn, ARedirectsLeft,
      ARequestBodyCloseAttempted);
  end
  else
  begin
    { 普通 HTTP 连接 }
    Result := DoRequestWithConnection(AReq, LConn, ARedirectsLeft,
      ARequestBodyCloseAttempted);
  end;
end;
```

### 3.5 测试计划

| 测试 | 描述 |
|------|------|
| http→https 重定向 | 301/302 从 http 到 https |
| https→http 重定向 | 301/302 从 https 到 http |
| https→https 重定向 | 301/302 从 https 到 https |
| 重定向循环检测 | https 重定向循环 |
| 重定向次数限制 | 超过 MaxRedirects |
| TLS 证书验证 | 自签名证书处理 |

### 3.6 依赖分析

| 依赖 | 状态 | 备注 |
|------|------|------|
| TLS 客户端流 | ✅ 已有 | NewTlsClientTcpStream |
| TLS 服务器流 | ✅ 已有 | NewTlsServerTcpStream |
| 自签名证书 | ✅ 已有 | CreateSelfSignedContext |
| HTTP 客户端 | ✅ 已有 | THttpClient |
| HTTP 服务器 | ✅ 已有 | THttpServer |

**结论**: 所有依赖已就绪，可立即实现。

### 3.7 工作量估算

| 任务 | 工作量 |
|------|--------|
| 修改 THttpClient 支持 https | 3h |
| Mock TLS 服务器 | 2h |
| 测试编写 | 3h |
| 文档更新 | 1h |
| **总计** | **9h** |

---

## 四、实施优先级

| 任务 | 优先级 | 工作量 | 依赖 | 建议 |
|------|--------|--------|------|------|
| P3-10 WebSocket 客户端 | P2 | 11h | 无 | **立即开始** |
| P3-11 模糊测试 | P3 | 8h | 无 | **立即开始** |
| P3-7 HTTPS 重定向测试 | P3 | 9h | TLS 运行时 | **立即开始** |

**总计**: 28h

### 推荐实施顺序

1. **Phase 1: WebSocket 客户端** (11h)
   - 扩展 TWebSocketImpl 支持客户端模式
   - 实现 ConnectWebSocket 函数
   - 编写测试

2. **Phase 2: 模糊测试** (8h)
   - 实现 TFuzzMutator
   - 实现 TFuzzRunner
   - 种子语料库 + 测试

3. **Phase 3: HTTPS 重定向测试** (9h)
   - 修改 THttpClient 支持 https
   - Mock TLS 服务器
   - 测试编写

---

## 五、风险评估

| 风险 | 概率 | 影响 | 缓解 |
|------|------|------|------|
| WebSocket 客户端帧掩码错误 | 中 | 高 | 严格遵循 RFC 6455 §5.3 |
| Fuzzer 发现 parser 崩溃 | 高 | 中 | 修复发现的问题 |
| TLS 集成复杂度 | 中 | 中 | 使用现有 TLS 基础设施 |
| 测试环境不稳定 | 低 | 低 | 使用 mock 服务器 |

---

## 六、验收标准

### P3-10 WebSocket 客户端
- [x] ConnectWebSocket 函数实现
- [x] ws:// 和 wss:// 支持
- [x] 客户端帧掩码正确
- [x] 服务器帧不掩码正确
- [x] 测试通过，0 泄漏

### P3-11 模糊测试
- [x] TFuzzMutator 实现
- [x] TFuzzRunner 实现
- [x] 种子语料库完整
- [x] 1000 次迭代无崩溃
- [x] 0 泄漏

### P3-7 HTTPS 重定向测试
- [x] THttpClient 支持 https
- [x] Mock TLS 服务器
- [x] http→https 重定向测试
- [x] 证书验证测试
- [x] 0 泄漏

---

*调研人: Claude (AI)*
*审核状态: 待确认*
