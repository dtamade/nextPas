# Platform 和 HTTP 模块开发实践总结

## 概述

本文档总结 `nextpas.core.platform` 和 `nextpas.core.http` 两个模块的开发实践，
为 tui 模块和其他模块提供可借鉴的经验。

---

## 一、Platform 模块开发实践

### 1.1 架构设计

**分层架构**:
```
L0: platform.base (纯常量/枚举，零依赖)
L1: platform.* (具体实现，仅依赖 base)
L2: platform.pas (门面 re-export)
```

**关键设计原则**:
- **单一职责**: 每个子模块只负责一个功能域（文件、进程、线程、网络等）
- **平台隔离**: `platform.linux.*`, `platform.windows.*` 等平台特定实现
- **FFI 边界清晰**: `platform.*.ffi.pas` 声明外部函数，实现层使用

### 1.2 错误处理

**统一错误码**:
```pascal
// 所有函数返回 Int32
function platform_file_open(...): Int32;  // 0 = 成功，正数 = errno

// 错误码常量
PLATFORM_ERR_INVALID (22)
PLATFORM_ERR_ENOENT (2)
PLATFORM_ERR_TIMEOUT (110)
PLATFORM_ERR_UNSUPPORTED (95)

// 错误消息
function platform_error_message(ACode: Int32; ABuf: PAnsiChar; ABufSize: SizeUInt): SizeUInt;
```

**最佳实践**:
- ✅ 不抛异常，返回错误码
- ✅ 提供人类可读的错误消息
- ✅ 错误分类 (`TPlatformErrorCategory`)

### 1.3 资源管理

**RAII 模式**:
```pascal
// ✅ 正确：及时关闭资源
var
  LFile: TPlatformFileHandle;
begin
  if platform_file_open(..., LFile) = 0 then
  begin
    try
      // 使用文件
    finally
      platform_file_close(LFile);
    end;
  end;
end;
```

**句柄无效值**:
- Unix: `TPlatformFileHandle.Value = -1`
- Windows: `INVALID_HANDLE_VALUE`

### 1.4 测试实践

**测试覆盖**:
- 106 个测试目录
- 覆盖所有平台（Linux/macOS/Windows/FreeBSD/Android）
- 交叉编译验证（aarch64/arm32/riscv64）

**测试类型**:
1. **功能测试**: 验证 API 行为
2. **契约测试**: 验证源码结构（`test_platform_facade_surface`）
3. **跨平台测试**: 交叉编译 + QEMU
4. **基准测试**: 性能验证

**测试模式**:
```pascal
var
  T: TTestSuite;
begin
  T := TTestSuite.Create('platform');
  T.Test('test name', @TestProcedure);
  if not T.Run then Halt(1);
end.
```

### 1.5 文档实践

**文档结构**:
- `CONTRACT.md`: 代码契约（接口、不变量、错误处理、线程安全）
- `BEST-PRACTICES.md`: 最佳实践和示例
- `API-REFERENCE.md`: API 参考
- `goal-tree.md`: 目标树和里程碑

---

## 二、HTTP 模块开发实践

### 2.1 架构设计

**分层架构**:
```
L3: http.pas (门面)
L3: http.client / http.server (facade)
L3: http.impl.h1 / http.impl.h2 (transport 实现)
L2: net, tls, json (依赖)
```

**关键设计原则**:
- **Transport 抽象**: `IHttpClient` / `IHttpServer` 接口隔离协议细节
- **Registry 模式**: 协议版本注册表，支持 H1/H2/H3 扩展
- **中间件链**: CORS、logging、rate-limit 等可组合

### 2.2 接口设计

**值类型 vs 接口**:
```pascal
// 请求/响应是值类型
THttpRequest = record
  Method: string;
  Headers: THttpHeaders;
  Body: TBytes;
end;

// Transport 是接口
IHttpClient = interface
  function RoundTrip(const AReq: THttpRequest): THttpResponse;
end;
```

**Builder 模式**:
```pascal
THttpClient.Create
  .WithTimeout(5000)
  .WithMaxRedirects(10)
  .WithTransport(TTransport.Create);
```

### 2.3 错误处理

**统一异常类型**:
```pascal
EHttpError = class(ENextPasError)
  // 错误码: ecNetwork
end;

// 使用场景
raise EHttpError.Create('connect failed: ' + host + ':' + port);
```

**错误分类**:
- 连接失败
- TLS 握手失败
- 协议错误
- 超时

### 2.4 线程安全

**连接池保护**:
```pascal
THttpConnectionPool = class
private
  FLock: TRTLCriticalSection;  // 保护连接池
public
  function Acquire: IConnection;
  procedure Release(AConn: IConnection);
end;
```

**线程安全矩阵**:
| 组件 | 线程安全 | 机制 |
|------|----------|------|
| IHttpClient | ✅ | 连接池用 CriticalSection |
| IHttpServer | ✅ | Handler 由线程池调用 |
| THttpHeaders | ✅ 读 | 只读无锁，写非线程安全 |
| 注册表 | ✅ | 初始化后冻结 |

### 2.5 测试实践

**测试覆盖**:
- 31 个测试套件
- ~1447 个测试用例
- 覆盖 HTTP/1.1、HTTP/2、HPACK、TLS

**测试类型**:
1. **解析测试**: HTTP/1.1 parser、HPACK 编解码
2. **集成测试**: 客户端-服务器交互
3. **契约测试**: RFC 合规性验证
4. **性能测试**: 基准对比（Go/Rust）

**测试工具**:
```pascal
// TCP echo server 用于测试
// TLS 证书生成工具
// 二进制验证器
```

### 2.6 性能优化

**关键优化点**:
1. **llhttp**: C 库解析，比 Pascal 实现快 ~10x
2. **HPACK MRU 缓存**: 减少重复头部传输
3. **连接池**: 空闲连接复用
4. **零拷贝**: `TBytes` 引用计数传递

---

## 三、可借鉴的实践

### 3.1 架构层面

1. **分层清晰**: L0/L1/L2/L3 严格分层，禁止循环依赖
2. **门面模式**: 统一入口，隐藏实现细节
3. **接口抽象**: Transport/Backend 通过接口隔离
4. **Registry 模式**: 支持协议/后端扩展

### 3.2 错误处理

1. **统一错误码/异常**: 不要混合使用
2. **人类可读消息**: 方便调试
3. **错误分类**: 便于上层处理

### 3.3 资源管理

1. **RAII 模式**: try/finally 确保资源释放
2. **句柄无效值**: 统一定义
3. **堆检测**: 测试启用 heaptrc，0 unfreed

### 3.4 测试实践

1. **契约测试**: 验证源码结构和接口
2. **跨平台测试**: 交叉编译 + QEMU
3. **基准测试**: 性能对比
4. **测试覆盖**: 100% 套件通过率

### 3.5 文档实践

1. **CONTRACT.md**: 代码契约（必读）
2. **BEST-PRACTICES.md**: 最佳实践
3. **ARCHITECTURE.md**: 架构设计
4. **goal-tree.md**: 里程碑追踪

---

## 四、对 TUI 模块的建议

### 4.1 已有优势

✅ 分层清晰（core/ext/experimental/full）
✅ 接口契约一致（IWidget）
✅ 内存管理合理（RAII 模式）
✅ 文档完整（ARCHITECTURE.md, CONTRACT.md）

### 4.2 可改进点

1. **错误处理**: 考虑统一错误类型（类似 EHttpError）
2. **契约测试**: 添加源码结构验证测试
3. **性能测试**: 添加基准测试对比
4. **跨平台验证**: 确保 Windows/macOS 兼容性

### 4.3 具体行动

1. 创建 `test_tui_facade_surface` 验证门面结构
2. 添加 `TUI_BENCHMARK.md` 记录性能数据
3. 创建 `BEST-PRACTICES.md` 总结使用示例
4. 补充 widget 测试覆盖（当前 38%，目标 60%）

---

## 五、关键代码模式

### 5.1 Builder 模式

```pascal
// Platform
TPlatformThread.Create
  .WithStackSize(1024 * 1024)
  .WithDetached(True)
  .Start(@MyProc, nil);

// HTTP
THttpClient.Create
  .WithTimeout(5000)
  .WithTransport(TTransport.Create);

// TUI
TBlock.New
  .WithBorderSet(BorderSetRounded)
  .WithBorderStyle(StyleDefault)
  .WithPadding(1);
```

### 5.2 状态机模式

```pascal
// HTTP 连接状态
THttpConnectionState = (
  csConnecting,
  csConnected,
  csIdle,
  csActive,
  csClosing
);

// TUI 树状态
TTreeState = record
  Offset: Integer;
  Selected: Integer;
  Opened: array of Boolean;
end;
```

### 5.3 适配器模式

```pascal
// HTTP Transport 适配器
THttpTransportAdapter = class(TInterfacedObject, IHttpTransport)
  // 适配不同协议实现
end;

// TUI Widget 适配器
TWidgetAdapter = class(TInterfacedObject, IWidget)
  // 适配回调函数为接口
end;
```

---

## 六、契约测试实践

### 6.1 Platform 契约测试

**验证源码结构**:
```pascal
procedure TestPlatformFacadeIsThin;
var
  LSource: string;
begin
  LSource := ReadSourceFile('nextpas.core.platform.pas');

  // 验证必须存在
  CheckTokenPresent(LSource, 'nextpas.core.platform.base',
    'platform facade must re-export platform.base');
  CheckTokenPresent(LSource, 'result := nextpas.core.platform.info.currentos;',
    'platform facade CurrentOS must forward to platform.info');

  // 验证必须不存在
  CheckTokenAbsent(LSource, 'case currentos of',
    'platform facade must not keep OS name mapping logic');
  CheckNoFpcPlatformTokens(LSource, 'platform facade');
end;
```

**验证纯度**:
```pascal
procedure TestPlatformBaseStaysPure;
begin
  // platform.base 不能有外部依赖
  CheckTokenAbsent(LSource, 'external ''',
    'platform.base must not declare external ABI directly');
  CheckNoFpcPlatformTokens(LSource, 'platform.base');
end;
```

### 6.2 HTTP 契约测试

**Mock Transport 测试**:
```pascal
type
  TMockHttpTransport = class(TInterfacedObject, IHttpTransport)
    function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  end;

// 测试接口契约
procedure TestTransportInterface;
var
  LMock: TMockHttpTransport;
  LReq: IHttpRequest;
begin
  LMock := TMockHttpTransport.Create;
  LReq := THttpRequest.Create;
  LMock.RoundTrip(LReq);
  Check(LMock.RoundTripCalled, 'transport called');
end;
```

**集成测试模式**:
```pascal
procedure TestServerClientIntegration;
var
  LServer: THttpServer;
  LClient: IHttpClient;
  LResp: IHttpResponse;
begin
  // 启动服务器
  LServer := StartTestServer(@Handler);
  try
    // 创建客户端
    LClient := THttpClient.Create;
    // 发送请求
    LResp := LClient.Get('http://localhost:' + Port + '/test');
    // 验证响应
    CheckEqual(200, LResp.StatusCode);
  finally
    LServer.Free;
  end;
end;
```

---

## 七、并发测试实践

### 7.1 压力测试模式

```pascal
const
  STRESS_REQUESTS = 96;
  STRESS_CONCURRENCY = 8;

type
  PThreadCtx = ^TThreadCtx;
  TThreadCtx = record
    Client: IHttpClient;
    BaseUrl: string;
    StartIdx: Int32;
    Count: Int32;
    SuccessCount: Int32;
    ErrorCount: Int32;
  end;

// 服务器线程
function ServerThreadFunc(AArg: Pointer): Pointer; cdecl;
begin
  GServer := THttpServer.Create(...);
  GServerReady := True;
  GServer.ListenAndServe('127.0.0.1', 0);
end;

// 客户端线程
function ClientThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PThreadCtx;
begin
  LCtx := PThreadCtx(AArg);
  for LI := 0 to LCtx^.Count - 1 do
  begin
    LResp := LCtx^.Client.Get(LCtx^.BaseUrl + '/ping');
    if LResp.StatusCode = HTTP_STATUS_OK then
      Inc(LCtx^.SuccessCount);
  end;
end;

// 主测试
procedure TestConcurrentRequests;
begin
  // 启动服务器
  StartServer(LPort);

  // 创建多个客户端线程
  for LI := 0 to STRESS_CONCURRENCY - 1 do
  begin
    LCtxs[LI].Client := LClient;
    platform_thread_create(LClientHandles[LI], @ClientThreadFunc, @LCtxs[LI]);
  end;

  // 等待所有线程完成
  for LI := 0 to STRESS_CONCURRENCY - 1 do
    platform_thread_join(LClientHandles[LI], LRet);

  // 验证结果
  CheckEqual(Int64(STRESS_REQUESTS), Int64(LTotalSuccess + LTotalError));
end;
```

### 7.2 同步原语测试

```pascal
// 测试互斥锁
procedure TestMutexConcurrency;
var
  LMutex: TPlatformMutex;
  LCounter: Int32;
begin
  platform_mutex_init(LMutex);
  LCounter := 0;

  // 多线程递增计数器
  for LI := 0 to 9 do
    platform_thread_create(LHandles[LI], @IncrementThread, @LCounter);

  // 等待完成
  for LI := 0 to 9 do
    platform_thread_join(LHandles[LI], LRet);

  // 验证无竞争
  CheckEqual(1000, LCounter, 'mutex protects counter');
  platform_mutex_destroy(LMutex);
end;
```

---

## 八、错误处理和资源管理模式

### 8.1 防御性编程

```pascal
// 忽略清理错误
procedure CloseRequestBodyIgnoringErrors(const ABody: IReader);
begin
  try
    CloseRequestBody(ABody);
  except
    on E: Exception do ;  // 静默处理
  end;
end;

// 释放响应体
procedure ReleaseResponseBodyIgnoringErrors(const AResp: IHttpResponse);
begin
  try
    ReleaseResponseBody(AResp);
  except
    on E: Exception do ;
  end;
end;
```

### 8.2 连接池管理

```pascal
type
  THttpConnectionPool = class
  private
    FPoolLock: TRTLCriticalSection;
    FPool: array of TPoolEntry;
    FPoolCount: Int32;
  public
    constructor Create;
    destructor Destroy; override;
    function Get(const AHost: string; APort: UInt16): ITcpStream;
    procedure Put(const AHost: string; APort: UInt16; AConn: ITcpStream);
    procedure Clear;
  end;

constructor THttpConnectionPool.Create;
begin
  InitializeCriticalSection(FPoolLock);
end;

destructor THttpConnectionPool.Destroy;
begin
  Clear;
  DeleteCriticalSection(FPoolLock);
  inherited;
end;

function THttpConnectionPool.Get(...): ITcpStream;
begin
  EnterCriticalSection(FPoolLock);
  try
    // 查找可复用连接
  finally
    LeaveCriticalSection(FPoolLock);
  end;
end;
```

### 8.3 重试模式

```pascal
function IsRetryableMethod(const AMethod: THttpMethod): Boolean;
begin
  Result := AMethod in [hmGet, hmHead, hmOptions, hmTrace];
end;

function IsRetrySafeRequest(const AReq: IHttpRequest): Boolean;
begin
  if AReq = nil then
    Exit(False);
  Result := IsRetryableMethod(AReq.Method) or
    AReq.Headers.Has('idempotency-key');
end;

// 重试客户端
TRetryClient = class(TInterfacedObject, IHttpClient)
  function RoundTrip(const AReq: IHttpRequest): IHttpResponse;
  var
    LRetries: Int32;
  begin
    LRetries := FMaxRetries;
    while True do
    begin
      try
        Result := FInner.RoundTrip(AReq);
        Exit;
      except
        on E: EHttpError do
        begin
          if (LRetries <= 0) or not IsRetrySafeRequest(AReq) then
            raise;
          Dec(LRetries);
        end;
      end;
    end;
  end;
end;
```

---

## 九、总结

### 9.1 关键成功因素

1. **严格的分层架构**: L0/L1/L2/L3 确保依赖方向正确
2. **统一的错误处理**: 错误码或异常，不要混合
3. **完善的测试覆盖**: 100% 套件通过率是底线
4. **详细的文档**: CONTRACT.md 是核心，必须维护
5. **性能优化**: llhttp、HPACK、连接池等关键优化

### 9.2 可直接应用的实践

| 实践 | Platform | HTTP | TUI 建议 |
|------|----------|------|----------|
| 契约测试 | ✅ 源码结构验证 | ✅ 接口契约验证 | 🔄 可添加 |
| 压力测试 | ✅ 跨平台验证 | ✅ 并发测试 | 🔄 可添加 |
| 性能基准 | ✅ 平台对比 | ✅ Go/Rust 对比 | 🔄 可添加 |
| 错误处理 | ✅ 统一错误码 | ✅ 统一异常 | ✅ 已有 |
| 资源管理 | ✅ RAII 模式 | ✅ 连接池 | ✅ 已有 |

### 9.3 TUI 模块改进路线

**短期（1-2 周）**:
1. 补充 widget 测试覆盖（目标 60%）
2. 添加 `test_tui_facade_surface` 契约测试
3. 创建 `TUI_BENCHMARK.md` 性能文档

**中期（1 个月）**:
1. 添加压力测试（并发渲染、事件处理）
2. 性能基准对比（与其他 TUI 库）
3. 完善 `BEST-PRACTICES.md`

**长期（3 个月）**:
1. 跨平台验证（Windows/macOS）
2. 性能优化（SIMD、零拷贝）
3. 生态集成（与其他 nextpas.core 模块）

### 9.4 核心代码模式

**Builder 模式**:
```pascal
TBlock.New
  .WithBorderSet(BorderSetRounded)
  .WithBorderStyle(StyleDefault)
  .WithPadding(1);
```

**状态机模式**:
```pascal
TTreeState = record
  Offset: Integer;
  Selected: Integer;
  Opened: array of Boolean;
end;
```

**适配器模式**:
```pascal
TWidgetAdapter = class(TInterfacedObject, IWidget)
  // 适配回调函数为接口
end;
```

**RAII 模式**:
```pascal
var
  Buf: TBuffer;
begin
  Buf := TBuffer.CreateEmpty(...);
  try
    // 使用 buffer
  finally
    Buf.Free;
  end;
end;
```

---

## 附录：关键文件路径

### Platform 模块
- `core/src/nextpas.core.platform.pas` — 门面
- `core/src/nextpas.core.platform.base.pas` — 基础类型
- `core/src/nextpas.core.platform.error.pas` — 错误处理
- `core/docs/platform/CONTRACT.md` — 代码契约
- `core/docs/platform/BEST-PRACTICES.md` — 最佳实践

### HTTP 模块
- `core/src/nextpas.core.http.pas` — 门面
- `core/src/nextpas.core.http.client.pas` — 客户端
- `core/src/nextpas.core.http.server.pas` — 服务器
- `core/src/nextpas.core.http.impl.h1.pas` — H1 实现
- `core/docs/http/CONTRACT.md` — 代码契约
- `core/docs/http/ARCHITECTURE.md` — 架构设计

### TUI 模块
- `core/src/nextpas.core.tui.pas` — 门面
- `core/src/nextpas.core.tui.ext.pas` — 扩展门面
- `core/src/nextpas.core.tui.app.pas` — 应用框架
- `core/docs/tui/CONTRACT.md` — 代码契约
- `core/docs/tui/ARCHITECTURE.md` — 架构设计
