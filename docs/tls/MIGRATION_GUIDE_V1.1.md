# fafafa.ssl v1.1 迁移指南

**版本**: v1.0.0 → v1.1.0
**发布日期**: 2026-02-05
**重要性**: 低（仅影响自定义后端开发者）

---

## 概述

v1.1.0 引入了架构改进，将 `GetNativeHandle` 方法从核心接口移至可选接口 `ISSLNativeHandleAccess`。此变更旨在：

1. **清晰化抽象层** - 核心接口不再暴露 C 库特定实现细节
2. **支持纯 Pascal 后端** - 让 `sslFreePascal` 这类不暴露 native handle 的 backend 成为一等公民
3. **提升类型安全** - 通过接口查询机制防止类型错误

**向后兼容性**: ✅ 对于标准用户代码，此变更完全向后兼容，无需任何修改。

> 当前口径：
> - 普通新代码优先使用 `uses fafafa.ssl, fafafa.ssl.context.builder;`，然后通过 `TSSLContextBuilder` / `TSSLConnector` 建立 TLS
> - 只有在你明确固定 backend、或需要 native-handle 高级访问时，才使用
>   `TSSLFactory.GetLibraryInstance(...)` + `Lib.CreateContext(...)`

---

## 谁会受到影响？

### ✅ 不受影响（99% 用户）

如果您的代码仅使用以下方式：

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.context.builder;

var
  Ctx: ISSLContext;
  TLS: TSSLConnector;
  Stream: TSSLStream;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .BuildClient;

  TLS := TSSLConnector.FromContext(Ctx);
  Stream := TLS.ConnectSocket(Socket, 'example.com');
  Stream.Free;
end;
```

**您无需任何修改！** 继续使用即可。

### ⚠️ 可能受影响（1% 高级用户）

如果您的代码符合以下情况之一：

1. **实现了自定义 TLS 后端**
2. **直接调用了 `GetNativeHandle` 方法**
3. **需要访问底层 C 库句柄**（如 OpenSSL `SSL*` 指针）

请继续阅读迁移步骤。

---

## 核心变更

### 变更前（v1.0.0）

```pascal
// GetNativeHandle 在核心接口中
ISSLContext = interface
  function GetNativeHandle: Pointer;  // 所有后端都必须实现
  // ... 其他方法
end;

ISSLConnection = interface
  function GetNativeHandle: Pointer;
  // ... 其他方法
end;

// 使用方式
Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
Ctx := Lib.CreateContext(sslCtxClient);
SSL_CTX := PSSL_CTX(Ctx.GetNativeHandle);  // 直接调用
```

### 变更后（v1.1.0）

```pascal
// GetNativeHandle 移至可选接口
ISSLContext = interface
  // GetNativeHandle 已移除
  // ... 其他方法（不变）
end;

// 新增可选接口
ISSLNativeHandleAccess = interface
  ['{B2C4E6F8-1A2B-3C4D-5E6F-7A8B9C0D1E2F}']
  function GetNativeHandle: Pointer;
  function GetBackendType: TSSLLibraryType;
  function IsNativeHandleValid: Boolean;
end;

// 使用方式 - 需要接口查询
Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
Ctx := Lib.CreateContext(sslCtxClient);
if Supports(Ctx, ISSLNativeHandleAccess, NativeAccess) then
  SSL_CTX := PSSL_CTX(NativeAccess.GetNativeHandle);
```

---

## 迁移步骤

### 场景 1：标准应用代码（99% 用户）

**无需任何修改！** 您的代码继续正常工作。

### 场景 2：访问原生句柄（高级用户）

#### 2.1 简单迁移（推荐）

使用后端提供的辅助函数：

**之前**:

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.openssl.api.ssl;

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  SSL_CTX: PSSL_CTX;
begin
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Ctx := Lib.CreateContext(sslCtxClient);
  SSL_CTX := PSSL_CTX(Ctx.GetNativeHandle);  // 旧方式
  // 使用 SSL_CTX
end;
```

**之后**:

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.openssl.api.ssl,
  fafafa.ssl.native_handle;  // 当前统一 helper

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  SSL_CTX: PSSL_CTX;
begin
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Ctx := Lib.CreateContext(sslCtxClient);

  // 方式 1: 使用辅助函数（推荐）
  SSL_CTX := PSSL_CTX(GetNativeHandleSafe(Ctx, 'MyCode.DoSomething'));

  // 方式 2: 类型安全的 Try 版本
  if specialize TryGetNativeHandleAs<PSSL_CTX>(Ctx, SSL_CTX) and (SSL_CTX <> nil) then
    // 使用 SSL_CTX
  else
    WriteLn('This backend does not provide native handles');
end;
```

#### 2.2 完整迁移（最佳实践）

手动进行接口查询：

```pascal
uses
  fafafa.ssl;

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  NativeAccess: ISSLNativeHandleAccess;
  SSL_CTX: PSSL_CTX;
begin
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Ctx := Lib.CreateContext(sslCtxClient);

  // 检查是否支持原生句柄访问
  if not Supports(Ctx, ISSLNativeHandleAccess, NativeAccess) then
  begin
    WriteLn('This backend does not support native handle access');
    Exit;
  end;

  // 检查句柄是否有效
  if not NativeAccess.IsNativeHandleValid then
  begin
    WriteLn('Native handle is not valid');
    Exit;
  end;

  // 获取原生句柄
  SSL_CTX := PSSL_CTX(NativeAccess.GetNativeHandle);

  // 现在可以安全使用 SSL_CTX
  WriteLn('Backend type: ', GetEnumName(TypeInfo(TSSLLibraryType),
                                         Ord(NativeAccess.GetBackendType)));
end;
```

### 场景 3：实现自定义后端

如果您实现了自定义 TLS 后端，需要决定是否支持原生句柄访问。

#### 3.1 基于 C 库的后端（需要实现）

```pascal
type
  TMyCustomSSLContext = class(TInterfacedObject, ISSLContext, ISSLNativeHandleAccess)
  private
    FNativeCtx: Pointer;  // 您的 C 库上下文
  public
    // ISSLContext 方法（保持不变）
    // ...

    // ISSLNativeHandleAccess 方法（新增）
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
  end;

function TMyCustomSSLContext.GetNativeHandle: Pointer;
begin
  Result := FNativeCtx;
end;

function TMyCustomSSLContext.GetBackendType: TSSLLibraryType;
begin
  Result := sslCustom;  // 或您的后端类型
end;

function TMyCustomSSLContext.IsNativeHandleValid: Boolean;
begin
  Result := (FNativeCtx <> nil);
end;
```

#### 3.2 纯 Pascal 后端（无需实现）

```pascal
type
  TPureFreePascalSSLContext = class(TInterfacedObject, ISSLContext)
    // ✅ 无需实现 ISSLNativeHandleAccess
    // ✅ 无需返回假的 nil 句柄
    // ✅ 架构完全清晰
  private
    FConfig: TPascalTLSConfig;  // 纯 Pascal 数据结构
  public
    // 仅实现 ISSLContext 方法
    // ...
  end;
```

---

## 辅助函数参考

当前推荐使用统一辅助单元 `fafafa.ssl.native_handle`；
如需保持 backend-specific helper，现有单元也仍可用。

统一 helper 暴露的核心函数如下：

### GetNativeHandleSafe

**签名**:

```pascal
function GetNativeHandleSafe(const AObject: IInterface;
                              const AContext: string = ''): Pointer;
```

**说明**:

- 安全获取原生句柄
- 如果对象不支持 `ISSLNativeHandleAccess`，抛出异常
- 如果句柄为 `nil`，抛出异常
- `AContext` 用于提供错误上下文（如 `'MyClass.MyMethod'`）

**示例**:

```pascal
uses fafafa.ssl.native_handle;

SSL_CTX := PSSL_CTX(GetNativeHandleSafe(Ctx, 'TMyApp.Initialize'));
```

### TryGetNativeHandle

**签名**:

```pascal
function TryGetNativeHandle(const AObject: IInterface;
                             out AHandle: Pointer): Boolean;
```

**说明**:

- 尝试获取原生句柄
- 返回 `True` 如果对象支持原生句柄接口，`False` 如果不支持
- 输出句柄可能仍为 `nil`，这通常表示对象尚未完成初始化
- 不抛出异常

**示例**:

```pascal
uses fafafa.ssl.native_handle;

var
  Handle: Pointer;
begin
  if TryGetNativeHandle(Ctx, Handle) and (Handle <> nil) then
    SSL_CTX := PSSL_CTX(Handle)
  else
    WriteLn('Native handle not available');
end;
```

### 可用的辅助单元

| 场景 | 辅助单元 |
|------|----------|
| 通用（推荐） | `fafafa.ssl.native_handle` |
| OpenSSL | `fafafa.ssl.openssl.native_handle` |
| WinSSL | `fafafa.ssl.winssl.native_handle` |
| MbedTLS | `fafafa.ssl.mbedtls.native_handle` |
| WolfSSL | `fafafa.ssl.wolfssl.native_handle` |

---

## ISSLNativeHandleAccess 接口参考

```pascal
ISSLNativeHandleAccess = interface
  ['{B2C4E6F8-1A2B-3C4D-5E6F-7A8B9C0D1E2F}']

  {** 获取后端原生句柄（如 SSL*, CredHandle, mbedtls_ssl_context*）
      @returns 原生句柄指针，仅供高级用户或后端内部使用 *}
  function GetNativeHandle: Pointer;

  {** 获取后端类型
      @returns 后端类型枚举值 *}
  function GetBackendType: TSSLLibraryType;

  {** 检查原生句柄是否有效
      @returns True 如果句柄有效且可用 *}
  function IsNativeHandleValid: Boolean;
end;
```

---

## 常见问题 (FAQ)

### Q1: 为什么要做这个变更？

**A**: 主要原因：

1. **架构清晰** - 核心接口不应暴露特定实现细节
2. **支持纯 Pascal** - 让 `sslFreePascal` 这类不暴露 native handle 的 backend 成为一等公民
3. **类型安全** - 通过接口查询防止运行时类型错误

### Q2: 这会破坏我的代码吗？

**A**: 对于 99% 的用户，**不会**。只有直接调用 `GetNativeHandle` 的高级用户需要迁移。

### Q3: 我该如何知道我的后端是否支持原生句柄？

**A**: 使用 `Supports` 函数检查：

```pascal
if Supports(Ctx, ISSLNativeHandleAccess) then
  WriteLn('Supports native handles')
else
  WriteLn('Pure Pascal backend');
```

### Q4: 性能有影响吗？

**A**: **没有**。`Supports` 接口查询是 FreePascal 编译器内置机制，开销可忽略（<1ns）。

### Q5: 我能同时使用支持和不支持原生句柄的后端吗？

**A**: **可以**。这正是此设计的优势。您的代码可以动态检查并适配：

```pascal
if Supports(Ctx, ISSLNativeHandleAccess, NativeAccess) then
  // 使用 C 库特定功能
else
  // 使用标准接口方法
```

### Q6: 纯 Pascal 后端现在是什么状态？

**A**: 当前仓库已经包含 `sslFreePascal` backend，并且这正是本次 native-handle optional boundary 的现实受益者之一。后续仍会继续完善 capability/runtime proof，但不再是“等待未来某个纯 Pascal backend 才能落地”的状态。

---

## 升级检查清单

- [ ] 检查代码中是否有直接调用 `GetNativeHandle` 的地方
- [ ] 如果有，决定迁移方式（辅助函数 vs 手动查询）
- [ ] 添加相应的 `uses` 子句（如 `fafafa.ssl.openssl.native_handle`）
- [ ] 更新调用代码
- [ ] 编译测试
- [ ] 运行测试套件
- [ ] 更新相关文档

---

## 获取帮助

如果您在迁移过程中遇到问题：

1. **查看示例**: `examples/` 目录中的示例已更新
2. **阅读测试**: `tests/` 目录展示了各种使用场景
3. **提交 Issue**: https://github.com/your-org/fafafa.ssl/issues
4. **查看完整报告**: `.claude/plans/refactoring-completion-report.md`

---

---

## v1.2.0 更新: 能力矩阵扩展 (2026-02-05)

v1.2.0 在 v1.1.0 的基础上进一步扩展了后端能力查询功能，引入了细粒度的能力矩阵系统。

### 新增功能

#### 1. 扩展的能力矩阵

`TSSLBackendCapabilities` 从 11 个字段扩展到 40+ 个字段：

```pascal
var
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
begin
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Caps := Lib.GetCapabilities;

  // 当前仍保留的主 bool 真相
  WriteLn('TLS 1.3: ', Caps.SupportsTLS13);

  // paired feature 现在优先读取 support-level truth
  WriteLn('ALPN Support Level: ', Ord(Caps.ALPNSupport));
  WriteLn('SNI Support Level: ', Ord(Caps.SNISupport));

  // v1.2.0 新增字段
  WriteLn('Backend Version: ', Caps.BackendVersion);
  WriteLn('Implementation Type: ', Ord(Caps.BackendImplType));
  WriteLn('Supports DTLS: ', Caps.SupportsDTLS);
  WriteLn('Has Hardware Acceleration: ', Caps.HasHardwareAcceleration);
  WriteLn('Supports System Cert Store: ', Caps.SupportsSystemCertStore);
  WriteLn('Supports PKCS#11: ', Caps.SupportsPKCS11);
end;
```

对于 paired feature（如 ALPN / SNI / OCSP Stapling / CT / Session Tickets）请优先读取 `*Support` 字段；legacy `Supports*` 仅用于兼容旧调用代码。
`SupportsTLS13` 目前仍是主 bool truth，因为当前没有 `TLS13Support`。

#### 2. 算法支持查询

v1.2.0 引入了细粒度的算法支持查询：

```pascal
uses
  fafafa.ssl.base;

var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 查询对称加密算法
  if IsCipherSupported(Caps, sslCipherAES256GCM) then
    WriteLn('AES-256-GCM is supported');

  if IsCipherSupported(Caps, sslCipherCHACHA20_POLY1305) then
    WriteLn('ChaCha20-Poly1305 is supported');

  // 查询哈希算法
  if IsHashSupported(Caps, sslHashSHA256) then
    WriteLn('SHA-256 is supported');

  // 查询密钥交换算法
  if IsKeyExchangeSupported(Caps, sslKexECDHE_RSA) then
    WriteLn('ECDHE-RSA is supported');
end;
```

#### 3. 功能成熟度评估

v1.2.0 引入了功能支持级别的概念：

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 检查功能是否稳定（推荐生产使用）
  if IsFeatureStable(Caps.ALPNSupport) then
    WriteLn('ALPN is production-ready');

  // 检查功能是否可用（包括实验性）
  if IsFeatureUsable(Caps.OCSPStaplingSupport) and
     not IsFeatureDeprecated(Caps.OCSPStaplingSupport) then
    WriteLn('OCSP Stapling can be used');

  // 检查功能是否已弃用
  if IsFeatureDeprecated(Caps.RenegotiationSupport) then
    WriteLn('TLS renegotiation is deprecated on this backend');
end;
```

#### 4. 后端评分系统

v1.2.0 引入了安全和性能评分系统（0-100）：

```pascal
var
  Caps: TSSLBackendCapabilities;
  SecScore, PerfScore: Integer;
begin
  Caps := Lib.GetCapabilities;

  // 安全评分（基于安全特性）
  SecScore := GetSecurityScore(Caps);
  WriteLn('Security Score: ', SecScore, '/100');

  // 性能评分（基于性能特性）
  PerfScore := GetPerformanceScore(Caps);
  WriteLn('Performance Score: ', PerfScore, '/100');
end;
```

#### 5. 统一的原生句柄辅助单元 (v1.1.1)

v1.1.1 引入了统一的辅助单元，简化了原生句柄访问：

**之前（v1.1.0）**:

```pascal
uses
  fafafa.ssl.openssl.native_handle;  // 需要记住后端特定单元

var
  Ctx: ISSLContext;
  Handle: PSSL_CTX;
begin
  Handle := PSSL_CTX(GetNativeHandleSafe(Ctx, 'MyCode'));
end;
```

**之后（v1.1.1+）**:

```pascal
uses
  fafafa.ssl.native_handle;  // 统一单元，适用于所有后端

var
  Ctx: ISSLContext;
  Handle: PSSL_CTX;
begin
  // 方式1: 简洁（接近 v1.0.0）
  Handle := PSSL_CTX(GetNativeHandle(Ctx));

  // 方式2: 类型安全（推荐）
  Handle := specialize GetNativeHandleAs<PSSL_CTX>(Ctx);

  // 方式3: 最安全（生产环境推荐）
  Handle := specialize GetNativeHandleAsSafe<PSSL_CTX>(Ctx, 'MyCode');
end;
```

#### 6. 智能后端选择示例

基于能力矩阵的智能后端选择：

```pascal
function SelectBestBackend: TSSLLibraryType;
var
  Candidates: array of TSSLLibraryType;
  BestScore, Score: Integer;
  I: Integer;
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
begin
  Candidates := [sslOpenSSL, sslFreePascal, sslWolfSSL, sslMbedTLS, sslWinSSL];
  BestScore := 0;
  Result := sslOpenSSL;

  for I := Low(Candidates) to High(Candidates) do
  begin
    try
      Lib := TSSLFactory.GetLibraryInstance(Candidates[I]);
      if not Assigned(Lib) then
        Continue;

      Caps := Lib.GetCapabilities;

      // 综合评分（安全 + 性能）
      Score := GetSecurityScore(Caps) + GetPerformanceScore(Caps);

      // 额外加分：系统证书存储支持
      if Caps.SupportsSystemCertStore then
        Score := Score + 10;

      // 额外加分：硬件加速
      if Caps.HasHardwareAcceleration then
        Score := Score + 5;

      if Score > BestScore then
      begin
        BestScore := Score;
        Result := Candidates[I];
      end;
    except
      Continue;
    end;
  end;

  WriteLn('Selected backend: ', LibraryTypeToString(Result),
          ' (score: ', BestScore, ')');
end;
```

#### 7. 完整能力描述

获取后端的完整文本描述：

```pascal
var
  Caps: TSSLBackendCapabilities;
  Desc: string;
begin
  Caps := Lib.GetCapabilities;
  Desc := GetCapabilitiesDescription(Caps);
  WriteLn(Desc);

  // 输出示例:
  // Backend: OpenSSL
  // Version: OpenSSL 3.5.4 30 Sep 2025
  // Implementation: C Library Binding
  // TLS Versions: TLS 1.0 - TLS 1.3
  // Dependencies: External library required
  // Security Score: 90/100
  // Performance Score: 100/100
end;
```

### 向后兼容性

✅ **完全向后兼容**：

- v1.1.0 的所有 11 个字段保持不变
- 新字段追加到记录末尾
- 现有代码无需任何修改

### 后端特性对比 (v1.2.0)

| 特性         | OpenSSL   | WolfSSL   | MbedTLS   | WinSSL      |
| ------------ | --------- | --------- | --------- | ----------- |
| **实现类型** | C Library | C Library | C Library | OS Native   |
| **安全评分** | 90/100    | 85/100    | 80/100    | 90/100      |
| **性能评分** | 100/100   | 95/100    | 85/100    | 100/100     |
| **TLS 1.3**  | ✅        | ✅        | ✅        | ✅ (Win10+) |
| **DTLS**     | ✅        | ✅        | ✅        | ❌          |
| **硬件加速** | ✅        | ✅        | ✅        | ✅          |
| **系统证书** | ❌        | ❌        | ❌        | ✅          |
| **PKCS#11**  | ⚠️ 依赖运行时 | ❌        | ❌        | ❌          |
| **TPM**      | ❌        | ❌        | ❌        | ❌          |
| **FIPS**     | ❌        | ❌        | ❌        | ❌          |

OpenSSL 的 PKCS#11 capability 取决于 Provider / ENGINE runtime surface readiness；默认构建也不发布 FIPS capability。
WinSSL 的 `fafafa.ssl.winssl.enterprise` 当前只提供系统 FIPS policy/helper 检测，不等于已发布 `SupportsFIPSMode=True` capability。

### 相关文档

- **快速参考**: `docs/NATIVE_HANDLE_QUICK_REF.md` - 原生句柄使用指南
- **能力矩阵指南**: `docs/CAPABILITY_MATRIX_GUIDE.md` - 能力矩阵详细说明
- **API 参考**: `docs/API_REFERENCE.md` - 完整 API 文档
- **完成报告**: `.claude/plans/task3-capability-matrix-completion-report.md` - 技术细节

---

## 总结

v1.1.0 的架构改进为 fafafa.ssl 的长远发展奠定了基础，v1.2.0 进一步扩展了细粒度的能力查询功能。对于绝大多数用户，这些变更是透明的；对于高级用户，提供了更强大的后端查询和决策能力。

感谢您使用 fafafa.ssl！

---

**文档状态**: 历史 v1.1 / v1.2 迁移专题（已按当前 active truth 注释）
**最后更新**: 2026-05-21
**作者**: fafafa.ssl 团队
