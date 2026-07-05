# nextpas.core.http 问题调研报告

**调研日期**: 2026-07-05
**调研范围**: 36 个源文件 + 31 个测试目录
**调研方法**: 根因分析 + 同类方案对标 + 修复策略 + 风险评估

---

## 一、问题总览

| 等级 | 数量 | 状态 |
|------|------|------|
| P0 | 2 | 需立即修复 |
| P1 | 5 | 需短期修复 |
| P2 | 15 | 需中期改进 |
| P3 | 12 | 建议改进 |

---

## 二、P0 问题调研

### P0-1: H2 测试套件编译失败（6 个文件，140 个测试）

**根因分析**:
- `test_http_h2_frame.lpr` 等 6 个文件使用旧版 test framework API
- 旧版: `with TTestSuite.Create('name') do begin Run('test', @Proc); Summary; end;`
- 新版: `T := TTestSuite.Create('name'); T.Test('test', @Proc); if not T.Run then Halt(1);`
- 关键差异: 旧版 `Run` 有参数（注册+执行），新版 `Run` 无参数（仅执行）

**受影响文件**:

| 文件 | Run 调用数 | 测试数 |
|------|-----------|--------|
| test_http_h2_frame.lpr | 18 | 18 |
| test_http_h2_hpack.lpr | 15 | 15 |
| test_http_h2_hpack_block.lpr | 11 | 11 |
| test_http_h2_types.lpr | 23 | 23 |
| test_http_h2_stream.lpr | 36 | 36 |
| test_http_h2_session.lpr | 37 | 37 |
| **合计** | **140** | **140** |

**修复策略**:
```pascal
// 旧版 (需替换)
with TTestSuite.Create('name') do
begin
  Run('test1', @TestProc1);
  Run('test2', @TestProc2);
  Summary;
end;

// 新版 (目标)
T := TTestSuite.Create('name');
T.Test('test1', @TestProc1);
T.Test('test2', @TestProc2);
if not T.Run then Halt(1);
```

**风险评估**: 低风险，纯机械替换，不影响测试逻辑

**对标**: Go testing 框架也经历过 API 演进，但保持向后兼容

---

## 三、P1 问题调研

### P1-1: H1/H2 连接池无线程安全保护

**根因分析**:
- `TH1ClientTransport` (h1.pas:1999-2045) 连接池操作无锁
- `TH2ClientTransport` (h2.client.pas:1387-1451) 连接池操作无锁
- 共享 `FPool` 数组和 `FPoolCount` 计数器
- 多线程并发调用 `RoundTrip` 会导致数据竞争

**影响范围**:
- 所有使用共享 `IHttpClient` 的多线程场景
- 高并发 HTTP 服务网关、代理服务器

**对标方案**:

| 语言/库 | 方案 | 性能影响 |
|---------|------|---------|
| Go net/http | `sync.Mutex` 保护 transport pool | 低（锁粒度小） |
| Rust reqwest | `Arc<Mutex<Pool>>` 或 lock-free | 中等 |
| Java HttpClient | `ConcurrentLinkedDeque` | 低 |

**修复策略**:
```pascal
// 方案 A: 临界区保护 (推荐)
TH1ClientTransport = class
private
  FPoolLock: TRTLCriticalSection;
  FPool: array of TPoolEntry;
  FPoolCount: Int32;
  // ...
end;

constructor TH1ClientTransport.Create(...);
begin
  InitCriticalSection(FPoolLock);
  // ...
end;

destructor TH1ClientTransport.Destroy;
begin
  PoolClear;
  DoneCriticalSection(FPoolLock);
  inherited;
end;

function TH1ClientTransport.PoolGet(...): ITcpStream;
begin
  EnterCriticalSection(FPoolLock);
  try
    // 原有逻辑
  finally
    LeaveCriticalSection(FPoolLock);
  end;
end;
```

**风险评估**: 中等风险
- 需确保所有池操作路径都加锁
- 需避免死锁（如 PoolGet 内调用 PooledConnectionIsReusable 可能阻塞）
- 性能影响: 锁粒度小，影响可忽略

---

### P1-2: FindFirst 双重遍历性能问题

**根因分析**:
- `THttpHeaders.FindFirst` (headers.pas:200-217) 先精确匹配，再 normalized 匹配
- 如果调用方传入已 normalized 的名称（小写），第二次遍历是浪费
- 大多数 HTTP 头部名称已是小写（parser 输出 normalized）

**影响范围**:
- 高频头部访问场景（如 `Content-Type`, `Authorization`）
- 每个请求可能调用 10-20 次 `Get/Has`

**对标方案**:

| 语言/库 | 方案 |
|---------|------|
| Go net/http | CanonicalHeaderKey 预标准化 |
| Rust hyper | HeaderName 类型保证 normalized |

**修复策略**:
```pascal
// 方案: 记录已 normalized 状态
function THttpHeaders.FindFirst(const AName: string): Int32;
var
  LNorm: string;
  LI: Int32;
begin
  // 快速路径: 直接匹配
  for LI := 0 to FCount - 1 do
    if FEntries[LI].Name = AName then
      Exit(LI);

  // 仅在需要时 normalized
  if NeedsNormalize(AName) then
  begin
    LNorm := Normalize(AName);
    for LI := 0 to FCount - 1 do
      if FEntries[LI].Name = LNorm then
        Exit(LI);
  end;

  Result := -1;
end;
```

**风险评估**: 低风险，纯优化，不影响语义

---

### P1-3: ParserErrorStatus case 不完整

**根因分析**:
- `ParserErrorStatus` (h1.pas:368-374) case 语句缺少 `pekNone` 分支
- 编译器可能产生警告，运行时不会到达

**修复策略**:
```pascal
function ParserErrorStatus(const AParser: IH1Parser): THttpStatus;
begin
  case AParser.ErrorKind of
    pekNone: Result := HTTP_STATUS_BAD_REQUEST;  // 添加
    pekUnsupportedTransferCoding:
      Result := HTTP_STATUS_NOT_IMPLEMENTED;
  else
    Result := HTTP_STATUS_BAD_REQUEST;
  end;
end;
```

**风险评估**: 极低风险

---

### P1-4: 全局注册表并发风险

**根因分析**:
- `GClientFactories/GServerFactories` (registry.pas:57-60) 全局数组无保护
- 注释说"必须在并发前调用"但无运行时检查
- 如果动态注册 transport，可能读到半写状态

**修复策略**:
```pascal
// 方案: InitOnce 保护
var
  GRegistryInitialized: Boolean;
  GRegistryLock: TRTLCriticalSection;

procedure EnsureRegistryInitialized;
begin
  if GRegistryInitialized then Exit;
  EnterCriticalSection(GRegistryLock);
  try
    if not GRegistryInitialized then
    begin
      RegisterBuiltins;
      GRegistryInitialized := True;
    end;
  finally
    LeaveCriticalSection(GRegistryLock);
  end;
end;
```

**风险评估**: 低风险，当前仅在 initialization 段调用，实际竞争概率低

---

### P1-5: PoolPut 池满时未关闭连接

**根因分析**:
- `TH1ClientTransport.PoolPut` (h1.pas:2021-2024) 池满时调用 `AConn.Close` ✅
- `TH2ClientTransport.PoolPut` (h2.client.pas:1424-1428) 池满时调用 `AConn.Close; AConn.Free` ✅
- **实际已正确处理**，原 findings.md 判断有误

**状态**: 无需修复

---

## 四、P2 问题调研

### P2-1: 中间件测试缺失

**现状**:
- `http.middleware.logger.pas` — 无独立测试
- `http.middleware.recovery.pas` — 无独立测试
- `http.middleware.timeout.pas` — 无独立测试
- `test_http_middlewares` 目录存在但内容待查

**对标**: Go 标准库每个 middleware 都有独立测试

**修复策略**: 添加 3 个测试文件
- `test_http_logger/test_http_logger.lpr`
- `test_http_recovery/test_http_recovery.lpr`
- `test_http_responstime/test_http_responstime.lpr`

**风险评估**: 低风险，纯测试补充

---

### P2-2: TLS 相关测试缺失

**现状**:
- `http.impl.h2.tls.pas` — 无测试
- `http.impl.tls.stream.pas` — 无测试
- 依赖真实 TLS 证书，测试环境搭建复杂

**对标**: Go crypto/tls 有完整的 mock 测试

**修复策略**:
1. 使用自签名证书进行集成测试
2. 或 mock `ISSLContext` 进行单元测试

**风险评估**: 中等风险，需要测试基础设施支持

---

### P2-3: CONTRACT.md 与代码不一致

**现状**:
- CONTRACT.md:14-27 定义的接口与实际代码不符
- 如 `IHttpClient.Get` 返回 `THttpResponse`（应为 `IHttpResponse`）
- 如 `IHttpServer.Get` 方法签名不同

**修复策略**: 更新 CONTRACT.md 与实际代码同步

**风险评估**: 极低风险，纯文档更新

---

### P2-4: 命名误导 (timeout middleware)

**现状**:
- `http.middleware.timeout.pas` 实际功能是 ResponseTime
- `TimeoutMiddleware` 已标记 deprecated
- 文件名未改

**修复策略**:
1. 重命名为 `http.middleware.responstime.pas`
2. 保留 `TimeoutMiddleware` 作为 deprecated alias

**风险评估**: 低风险，需更新所有引用

---

### P2-5: IH2StreamControl 未在门面暴露

**现状**:
- `http.intf.pas:180-185` 定义 `IH2StreamControl`
- `http.pas` 门面未 re-export

**修复策略**: 添加 re-export 或文档说明

**风险评估**: 极低风险

---

### P2-6: IsOriginAllowed 每次请求重新解析

**现状**:
- `http.middleware.cors.pas:31-59` 每次请求解析 `AllowOrigins` 字符串
- 高并发下有性能开销

**修复策略**:
```pascal
TCorsMiddleware = class
private
  FOrigins: TStringArray;  // 预解析
  FWildcard: Boolean;
  // ...
end;
```

**风险评估**: 低风险

---

### P2-7: ServeFileContent 硬编码错误响应

**现状**:
- `http.static.pas:126-128` 返回硬编码 "Not Found"
- 未设置 Content-Type

**修复策略**: 统一错误响应格式

**风险评估**: 极低风险

---

### P2-8: MatchNode 深度限制未文档化

**现状**:
- `http.router.pas:335` 限制 `MAX_MATCH_DEPTH`
- 未返回 414 状态码

**修复策略**: 文档化 + 考虑 414 响应

**风险评估**: 低风险

---

### P2-9: websocket.pas 自定义 LowerCase

**现状**:
- `http.websocket.pas:111-121` 自定义 `LowerCase` 函数
- 与 `nextpas.core.text.conv` 重复

**修复策略**: 删除自定义实现，使用标准库

**风险评估**: 极低风险

---

### P2-10: CloseRequestBody 接口覆盖不全

**现状**:
- `http.client.pas:100-120` 仅尝试 3 种接口
- 可能遗漏其他可关闭接口

**修复策略**: 统一使用 `ICloser` 标记接口

**风险评估**: 低风险

---

### P2-11: HttpStatusText 未知状态码处理

**现状**:
- `http.base.pas:220` 返回 "Unknown"
- RFC 9110 未要求特定行为

**修复策略**: 返回空字符串或 "XXX"

**风险评估**: 极低风险

---

### P2-12: UrlDecode 异常未捕获

**现状**:
- `http.url.pas:92-100` 对不完整 percent 序列抛异常
- `http.static.pas:176` 已捕获 ✅

**状态**: 部分已处理

---

### P2-13: ValidateValue TAB 字符未文档化

**现状**:
- `http.headers.pas:190-198` 允许 TAB (#9)
- 符合 RFC 9110 但未注释

**修复策略**: 添加 RFC 依据注释

**风险评估**: 极低风险

---

### P2-14: llhttp 文件过大

**现状**:
- `http.impl.h1.llhttp.pas` 676KB / 17884 行
- 自动生成的绑定代码

**对标**: Go 的 http parser 也是单文件

**修复策略**: 可考虑拆分但优先级低

**风险评估**: 低风险

---

### P2-15: logger middleware 使用 WriteLn

**现状**:
- `http.middleware.logger.pas:32` 使用 `WriteLn` 输出
- 生产环境不适用

**修复策略**: 改用 `nextpas.core.log` 或注入回调

**风险评估**: 低风险

---

## 五、P3 问题调研

### P3-1: TPrefixedTcpStream 命名不清
**建议**: 改为 `TTcpStreamWithPrefix`

### P3-2: 门面单元缺文档注释
**建议**: 添加 `@desc` 注释

### P3-3: H1 实现文件缺架构注释
**建议**: 在状态机处添加注释

### P3-4: llhttp 指针转有符号整数警告
**建议**: 使用 `SizeUInt`

### P3-5: GOAL_TREE.md 过时
**建议**: 更新 HTTP/3 状态

### P3-6: 缺少压力测试
**建议**: 添加 bench_http_concurrent

### P3-7: 缺少 HTTPS 重定向测试
**建议**: 补充场景

### P3-8: 缺少 Cookie 支持
**建议**: 长期规划

### P3-9: 缺少 Form 支持
**建议**: 长期规划

### P3-10: 缺少 WebSocket 客户端
**建议**: 长期规划

### P3-11: 缺少模糊测试
**建议**: 添加 HTTP parser fuzz

### P3-12: 缺少跨语言互操作测试
**建议**: 添加 Go/Rust 互测

---

## 六、实施规划

### 阶段 1: 紧急修复（1-2 天）

| 任务 | 优先级 | 依赖 | 工作量 |
|------|--------|------|--------|
| 迁移 6 个 H2 测试到新版 API | P0 | 无 | 2h |
| 修复 ParserErrorStatus case | P1 | 无 | 15min |

### 阶段 2: 线程安全（3-5 天）

| 任务 | 优先级 | 依赖 | 工作量 |
|------|--------|------|--------|
| H1 连接池添加临界区 | P1 | 无 | 2h |
| H2 连接池添加临界区 | P1 | 无 | 2h |
| 全局注册表添加保护 | P1 | 无 | 1h |
| 并发测试验证 | P1 | 上述完成 | 4h |

### 阶段 3: 性能优化（1 周）

| 任务 | 优先级 | 依赖 | 工作量 |
|------|--------|------|--------|
| FindFirst 优化 | P1 | 无 | 1h |
| CORS 预解析 | P2 | 无 | 1h |
| websocket.pas 删除重复函数 | P2 | 无 | 30min |

### 阶段 4: 测试补充（1-2 周）

| 任务 | 优先级 | 依赖 | 工作量 |
|------|--------|------|--------|
| 中间件测试 (3 个) | P2 | 无 | 4h |
| TLS 集成测试 | P2 | 测试基础设施 | 8h |
| 压力测试 | P3 | 无 | 4h |

### 阶段 5: 文档与规范（持续）

| 任务 | 优先级 | 依赖 | 工作量 |
|------|--------|------|--------|
| CONTRACT.md 同步 | P2 | 无 | 2h |
| 命名修正 | P2 | 无 | 1h |
| 注释补充 | P2 | 无 | 2h |

### 阶段 6: 长期规划（按需）

| 任务 | 优先级 | 依赖 | 工作量 |
|------|--------|------|--------|
| Cookie 支持 | P3 | 无 | 1 周 |
| Form 支持 | P3 | 无 | 1 周 |
| WebSocket 客户端 | P3 | 无 | 1 周 |
| HTTP/3 | P3 | QUIC 模块 | 1 月+ |

---

## 七、风险矩阵

| 风险 | 概率 | 影响 | 缓解措施 |
|------|------|------|---------|
| 线程安全修复引入死锁 | 低 | 高 | 代码审查 + 并发测试 |
| 测试迁移遗漏 | 低 | 中 | 编译验证 + 运行验证 |
| 性能优化引入回归 | 低 | 中 | 基准测试对比 |
| TLS 测试环境搭建失败 | 中 | 低 | 使用 mock 或跳过 |

---

## 八、验收标准

### 阶段 1 验收
- [ ] 6 个 H2 测试文件全部编译通过
- [ ] 140 个测试全部运行通过
- [ ] heaptrc 0 泄漏

### 阶段 2 验收
- [ ] 连接池操作无 data race (ThreadSanitizer 验证)
- [ ] 并发 RoundTrip 压力测试通过
- [ ] 性能无显著回退 (<5%)

### 阶段 3 验收
- [ ] FindFirst 性能提升可测量
- [ ] 所有修改通过现有测试

### 阶段 4 验收
- [ ] 新增测试全部通过
- [ ] 测试覆盖率提升

---

*调研人: Claude (AI)*
*审核状态: 待确认*
