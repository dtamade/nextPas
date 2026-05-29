# Native Handle 快速参考

**适用版本**: fafafa.ssl v1.1.1+（当前内容对齐 v1.5.0）
**最后更新**: 2026-05-21

---

## 概述

v1.1.0 重构后，`GetNativeHandle` 从核心接口移至可选接口 `ISSLNativeHandleAccess`。
v1.1.1 提供了统一辅助单元 `fafafa.ssl.native_handle`，简化高级用户体验。

**影响用户**: <1% 高级用户（直接使用 C 库 API）
**标准用户**: 无影响 ✅

> 当前 public 入口说明：
> - 普通 capability / native-handle 查询不必再拆分回 `uses fafafa.ssl.base` / `fafafa.ssl.factory`；`fafafa.ssl` 已 re-export `ISSLContext` / `ISSLNativeHandleAccess` / `TSSLFactory`。
> - 需要固定 backend 并访问原生句柄时，当前 library-entrypoint 优先使用 `TSSLFactory.GetLibraryInstance(...)` + `Lib.CreateContext(...)`。
> - 如果你只是普通客户端/服务端 TLS 建立，请优先回到 `docs/guides/GETTING_STARTED.md` 里的 `TSSLContextBuilder` / `TSSLConnector` / `TSSLStream` 主路径。

---

## 快速迁移

### v1.0.0 旧代码

```pascal
uses
  fafafa.ssl.base;

var
  Ctx: ISSLContext;
  Handle: PSSL_CTX;
begin
  Ctx := Lib.CreateContext(sslCtxClient);

  // 直接调用（v1.0.0）
  Handle := PSSL_CTX(Ctx.GetNativeHandle);
end;
```

### v1.1.1 新代码（推荐）

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.native_handle;  // 统一辅助单元

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Handle: PSSL_CTX;
begin
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Ctx := Lib.CreateContext(sslCtxClient);

  // 方式1: 简洁（接近v1.0.0）
  Handle := PSSL_CTX(GetNativeHandle(Ctx));

  // 方式2: 类型安全（推荐）✨
  Handle := specialize GetNativeHandleAs<PSSL_CTX>(Ctx);

  // 方式3: 最安全（生产环境推荐）✨✨
  Handle := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'MyApp.Initialize');
end;
```

**迁移步骤**:
1. 添加 `uses fafafa.ssl.native_handle`
2. 替换 `Ctx.GetNativeHandle` → `GetNativeHandle(Ctx)` 或泛型版本
3. （可选）使用泛型版本避免手动类型转换

**迁移时间**: 5-10 分钟

---

## API 参考

### 基础函数

#### GetNativeHandle
```pascal
function GetNativeHandle(const AObject: IInterface): Pointer;
```
- **用途**: 获取原生句柄（最简洁）
- **返回**: 指针，需手动类型转换
- **异常**: 如果不支持则抛出 `ESSLException`
- **示例**: `Handle := PSSL_CTX(GetNativeHandle(Ctx))`

#### GetNativeHandleSafe
```pascal
function GetNativeHandleSafe(const AObject: IInterface;
                              const AContext: string = ''): Pointer;
```
- **用途**: 安全获取，带上下文信息
- **参数**: `AContext` - 调用位置（用于错误消息）
- **返回**: 指针，保证非空
- **异常**: 如果不支持或句柄为空，抛出详细错误消息
- **示例**: `Handle := GetNativeHandleSafe(Ctx, 'MyModule.DoWork')`

#### TryGetNativeHandle
```pascal
function TryGetNativeHandle(const AObject: IInterface;
                            out AHandle: Pointer): Boolean;
```
- **用途**: 尝试获取（不抛出异常）
- **返回**: `True` 如果成功
- **示例**:
  ```pascal
  if TryGetNativeHandle(Ctx, Handle) then
    // 使用句柄
  else
    // 纯 Pascal 后端
  ```

### 泛型函数（类型安全）

#### GetNativeHandleAs\<T\>
```pascal
generic function GetNativeHandleAs<T>(const AObject: IInterface): T;
```
- **用途**: 类型安全版本，无需手动转换
- **示例**: `SSL_CTX := specialize GetNativeHandleAs<PSSL_CTX>(Ctx)`

#### GetNativeHandleAsSafe\<T\>
```pascal
generic function GetNativeHandleAsSafe<T>(const AObject: IInterface;
                                          const AContext: string = ''): T;
```
- **用途**: 类型安全 + 安全检查
- **示例**: `SSL_CTX := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'Init')`

#### TryGetNativeHandleAs\<T\>
```pascal
generic function TryGetNativeHandleAs<T>(const AObject: IInterface;
                                         out AHandle: T): Boolean;
```
- **用途**: 类型安全 + 不抛出异常
- **示例**:
  ```pascal
  if specialize TryGetNativeHandleAs<PSSL_CTX>(Ctx, SSL_CTX) then
    // 使用 SSL_CTX
  ```

### 辅助查询函数

#### IsNativeHandleAvailable
```pascal
function IsNativeHandleAvailable(const AObject: IInterface): Boolean;
```
- **用途**: 检查是否支持原生句柄
- **返回**: `True` 如果支持且有效
- **示例**: `if IsNativeHandleAvailable(Ctx) then ...`

#### GetBackendType
```pascal
function GetBackendType(const AObject: IInterface): TSSLLibraryType;
```
- **用途**: 获取后端类型
- **返回**: `sslOpenSSL`, `sslWinSSL` 等
- **示例**: `if GetBackendType(Ctx) = sslOpenSSL then ...`

#### IsNativeHandleValid
```pascal
function IsNativeHandleValid(const AObject: IInterface): Boolean;
```
- **用途**: 检查句柄是否有效（非空且已初始化）
- **示例**: `Assert(IsNativeHandleValid(Ctx))`

---

## 完整示例

### 示例1: OpenSSL 特定功能

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.native_handle,
  fafafa.ssl.openssl.api;  // OpenSSL C API

procedure UseOpenSSLSpecificFeature;
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  SSL_CTX: PSSL_CTX;
begin
  // 当前 fixed-backend / native-handle 场景优先先取 library-entrypoint
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Ctx := Lib.CreateContext(sslCtxClient);

  // 获取原生句柄（类型安全）
  SSL_CTX := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'UseOpenSSLSpecificFeature');

  // 调用 OpenSSL C API
  SSL_CTX_set_verify(SSL_CTX, SSL_VERIFY_PEER, nil);
  SSL_CTX_set_verify_depth(SSL_CTX, 10);

  // ... 其他 OpenSSL 特定操作
end;
```

### 示例2: 后端无关代码（推荐）

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.native_handle;

procedure ConfigureContext(Ctx: ISSLContext);
var
  Handle: Pointer;
begin
  // 检查是否支持原生句柄
  if IsNativeHandleAvailable(Ctx) then
  begin
    WriteLn('Backend: ', GetBackendType(Ctx));

    // 根据后端类型执行特定操作
    case GetBackendType(Ctx) of
      sslOpenSSL:
        begin
          Handle := GetNativeHandle(Ctx);
          // OpenSSL 特定配置
        end;
      sslWinSSL:
        begin
          Handle := GetNativeHandle(Ctx);
          // WinSSL 特定配置
        end;
    end;
  end
  else
    WriteLn('Pure Pascal backend - no native handle');
end;
```

### 示例3: 优雅的错误处理

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.native_handle;

procedure SafeHandleAccess(Ctx: ISSLContext);
var
  SSL_CTX: PSSL_CTX;
begin
  // 方式1: 使用 Try 版本（不抛出异常）
  if specialize TryGetNativeHandleAs<PSSL_CTX>(Ctx, SSL_CTX) then
  begin
    // 使用句柄
    WriteLn('Got native handle');
  end
  else
  begin
    // 纯 Pascal 后端，使用标准 API
    WriteLn('Using standard API only');
  end;

  // 方式2: 使用异常处理
  try
    SSL_CTX := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'SafeHandleAccess');
    // 使用句柄
  except
    on E: ESSLException do
    begin
      WriteLn('Cannot access native handle: ', E.Message);
      // 回退到标准 API
    end;
  end;
end;
```

---

## 常见问题 (FAQ)

### Q1: 为什么要这样改？
**A**: 为了支持纯 FreePascal TLS 后端（无 C 库依赖）。纯 Pascal 后端没有底层 C 库句柄，强制所有接口实现 `GetNativeHandle` 会导致语义不清（返回 nil）。

### Q2: 我的代码会受影响吗？
**A**: **99% 用户不受影响**。只有直接调用 `GetNativeHandle` 的高级用户（通常是需要访问 OpenSSL/WinSSL C API 的场景）需要迁移。

### Q3: 迁移需要多久？
**A**: 通常 **5-10 分钟**：
1. 添加 `uses fafafa.ssl.native_handle`（1 行）
2. 修改调用语法（每处 1 行）

### Q4: 泛型版本的优势是什么？
**A**: 类型安全，避免手动类型转换错误：
```pascal
// 非泛型：需要手动转换，容易出错
Handle := PSSL_CTX(GetNativeHandle(Ctx));  // 如果类型不匹配会崩溃

// 泛型：编译器检查类型
Handle := specialize GetNativeHandleAs<PSSL_CTX>(Ctx);  // 类型安全
```

### Q5: 什么时候使用 Safe 版本？
**A**: 生产环境推荐使用 `GetNativeHandleSafe` 或泛型 Safe 版本，因为：
- 提供详细的错误消息（包含调用位置）
- 帮助快速定位问题
- 错误消息包含修复建议

```pascal
// 开发/调试阶段：使用 Safe 版本
Handle := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'MyModule.Init');

// 性能关键路径：使用普通版本（跳过部分检查）
Handle := specialize GetNativeHandleAs<PSSL_CTX>(Ctx);
```

### Q6: 如何区分 C 库后端和纯 Pascal 后端？
**A**: 使用 `IsNativeHandleAvailable` 或 `GetBackendType`：
```pascal
if IsNativeHandleAvailable(Ctx) then
  WriteLn('C library backend')
else
  WriteLn('Pure Pascal backend');

// 或者
case GetBackendType(Ctx) of
  sslOpenSSL, sslWinSSL, sslMbedTLS, sslWolfSSL:
    WriteLn('C library backend');
  sslFreePascal:
    WriteLn('Pure Pascal backend');
end;
```

### Q7: 错误消息告诉我"纯 FreePascal 后端"，但我在用 OpenSSL？
**A**: 可能的原因：
1. OpenSSL 库未正确加载（检查 libssl.so 路径）
2. 对象未正确初始化（检查 `Initialize` 调用）
3. 固定 backend 的入口没走当前 library-entrypoint（确认 `Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);`，再由 `Lib.CreateContext(sslCtxClient)` 创建 context）

### Q8: 我能直接修改原生句柄吗？
**A**: ⚠️ **不推荐**。直接修改底层句柄可能导致：
- fafafa.ssl 内部状态不一致
- 内存泄漏或崩溃
- 未定义行为

**推荐做法**: 通过 fafafa.ssl 的标准 API 操作，仅在必要时读取句柄。

---

## 错误排查

### 错误1: "Native handle not available"

**原因**:
- 纯 FreePascal 后端
- 对象不支持 `ISSLNativeHandleAccess`
- 对象未正确初始化

**解决方案**:
1. 检查后端类型：`WriteLn(GetBackendType(Ctx))`
2. 确认库已初始化：`Assert(Lib.IsInitialized)`
3. 尝试使用 Try 版本避免异常：`TryGetNativeHandle(Ctx, Handle)`

### 错误2: "Native handle is null"

**原因**:
- C 库初始化失败
- 对象已被释放
- 底层 C API 调用失败

**解决方案**:
1. 检查错误日志：`WriteLn(Lib.GetLastErrorString)`
2. 验证库加载：`Assert(Lib.IsInitialized)`
3. 确认对象生命周期

### 错误3: 编译错误 "Unknown identifier 'specialize'"

**原因**: 未启用泛型模式开关

**解决方案**: 在文件头添加：
```pascal
{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}  // 启用泛型
```

---

## 性能考虑

### 开销分析

| 操作 | 开销 | 说明 |
|------|------|------|
| `GetNativeHandle()` | ~1ns | 接口查询 + 方法调用 |
| `GetNativeHandleSafe()` | ~2ns | 额外检查 |
| 泛型版本 | ~1ns | 编译时展开，无额外开销 |

**结论**: 开销可忽略不计（<0.001%），不会影响性能。

### 优化建议

**场景1: 频繁访问**
```pascal
// ❌ 不推荐：每次都查询
for i := 1 to 1000000 do
  Handle := GetNativeHandle(Ctx);  // 重复查询

// ✅ 推荐：缓存句柄
Handle := GetNativeHandle(Ctx);
for i := 1 to 1000000 do
  // 使用缓存的 Handle
```

**场景2: 性能关键路径**
```pascal
// 性能关键代码：使用普通版本
Handle := specialize GetNativeHandleAs<PSSL_CTX>(Ctx);

// 非关键代码：使用 Safe 版本（更好的错误消息）
Handle := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'Init');
```

---

## 最佳实践

### ✅ 推荐

1. **使用泛型版本**（类型安全）
   ```pascal
   Handle := specialize GetNativeHandleAs<PSSL_CTX>(Ctx);
   ```

2. **生产环境使用 Safe 版本**（详细错误）
   ```pascal
   Handle := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'ModuleName.FunctionName');
   ```

3. **缓存句柄**（性能优化）
   ```pascal
   FHandle := GetNativeHandle(FContext);  // 只查询一次
   ```

4. **检查后端类型**（跨后端代码）
   ```pascal
   if IsNativeHandleAvailable(Ctx) then
     // 使用原生句柄
   else
     // 使用标准 API
   ```

### ❌ 避免

1. **不要直接修改句柄**
   ```pascal
   // ❌ 危险
   SSL_CTX_set_options(Handle, ...);  // 可能导致状态不一致
   ```

2. **不要假设所有后端都有句柄**
   ```pascal
   // ❌ 错误：纯 Pascal 后端会抛出异常
   Handle := GetNativeHandle(Ctx);

   // ✅ 正确：检查可用性
   if IsNativeHandleAvailable(Ctx) then
     Handle := GetNativeHandle(Ctx);
   ```

3. **不要忽略上下文参数**
   ```pascal
   // ❌ 错误消息不清晰
   Handle := GetNativeHandleSafe(Ctx);

   // ✅ 错误消息包含位置信息
   Handle := GetNativeHandleSafe(Ctx, 'MyModule.Initialize');
   ```

---

## 相关文档

- **[迁移指南](MIGRATION_GUIDE_V1.1.md)** - 完整的 v1.0 → v1.1 迁移指南
- **[架构设计](ARCHITECTURE.md)** - 接口重构的设计原理
- **[API 参考](API_REFERENCE.md)** - 完整的 API 文档
- **[发布说明](../RELEASE_NOTES_V1.1.0.md)** - v1.1.0 变更说明

---

## 获取帮助

**GitHub Issues**: https://github.com/your-org/fafafa.ssl/issues
**讨论区**: https://github.com/your-org/fafafa.ssl/discussions
**邮件**: support@fafafa-ssl.org

---

**文档版本**: v1.5.0
**最后更新**: 2026-05-21
**维护者**: fafafa.ssl 文档团队
