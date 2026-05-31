# fafafa.ssl 架构设计文档

**版本**: v1.5.0
**最后更新**: 2026-05-21
**状态**: 当前架构总览（已对齐 v1.5.0 public truth）

---

## 目录

1. [概述](#概述)
2. [设计原则](#设计原则)
3. [架构层次](#架构层次)
4. [核心接口](#核心接口)
5. [可选接口](#可选接口)
6. [后端架构](#后端架构)
7. [工厂模式](#工厂模式)
8. [扩展性设计](#扩展性设计)
9. [v1.1 架构改进](#v11-架构改进)
10. [当前路线与演进边界](#当前路线与演进边界)
11. [参考资料](#参考资料)

---

## 概述

fafafa.ssl 是一个多后端 TLS/SSL 库，为 Free Pascal 提供统一的高级 API，同时支持多种底层 TLS 实现（OpenSSL, WinSSL, MbedTLS, WolfSSL, FreePascal）。

### 核心特性

- **多后端支持** - 单一 API，多种后端可选
- **接口驱动** - 完全基于接口的设计，无全局状态
- **工厂模式** - 自动检测和加载最佳后端
- **类型安全** - 编译时和运行时类型检查
- **零依赖部署** - 可静态链接所有依赖
- **跨平台** - Linux, Windows, macOS, FreeBSD

> 当前入口说明：
> - 普通新代码优先使用 `uses fafafa.ssl, fafafa.ssl.context.builder;`，然后通过 `TSSLContextBuilder` / `TSSLConnector` 建立 TLS
> - 需要固定 backend 或做更低层控制时，再使用
>   `TSSLFactory.GetLibraryInstance(...)`
>   或
>   `TSSLFactory.CreateContext(...)`
> - `CreateLibrary` 这类旧 helper / 旧入口不再是当前 public truth

---

## 设计原则

### 1. 接口抽象优先

**原则**: 用户代码仅依赖接口，不依赖具体实现。

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.context.builder;

// ✅ 好的设计 - 依赖统一入口与接口
var
  Ctx: ISSLContext;
  TLS: TSSLConnector;
begin
  Ctx := TSSLContextBuilder.Create
    .WithTLS12And13
    .WithVerifyPeer
    .BuildClient;
  TLS := TSSLConnector.FromContext(Ctx);
end;

// ❌ 差的设计 - 依赖具体类
var
  Ctx: TOpenSSLContext;  // 紧耦合
begin
  Ctx := TOpenSSLContext.Create;
end;
```

### 2. 最少知识原则

**原则**: 接口仅暴露必要的方法，不暴露实现细节。

```pascal
// ✅ 核心接口 - 不暴露实现细节
ISSLContext = interface
  function CreateConnection(ASocket: THandle): ISSLConnection;
  // 无 GetNativeHandle - 实现细节
end;

// ✅ 可选接口 - 高级用户使用
ISSLNativeHandleAccess = interface
  function GetNativeHandle: Pointer;  // 仅需要时查询
end;
```

### 3. 开闭原则

**原则**: 对扩展开放，对修改封闭。

- 添加新后端无需修改现有代码
- 添加新功能通过可选接口扩展

### 4. 依赖倒置

**原则**: 高层模块不依赖低层模块，都依赖抽象。

```
用户代码 → ISSLContext → 后端实现
         ↓
      工厂模式
```

---

## 架构层次

```
┌─────────────────────────────────────────────────────┐
│                   用户应用层                         │
│            (HTTPS Client, Server, 等)              │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────┐
│                  统一 API 层                         │
│ fafafa.ssl / TSSLContextBuilder / TSSLConnector    │
│   ISSLLibrary, ISSLContext, ISSLConnection, ...    │
└─────────────────────────────────────────────────────┘
                         │
                         ↓
┌─────────────────────────────────────────────────────┐
│                  工厂模式层                          │
│ TSSLFactory (GetLibraryInstance / CreateContext /   │
│              DetectBestLibrary)                     │
└─────────────────────────────────────────────────────┘
                         │
        ┌────────────────┼────────────────┐
        ↓                ↓                ↓
┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ OpenSSL 后端 │  │ WinSSL 后端  │  │ MbedTLS 后端 │  │ FreePascal   │
└──────────────┘  └──────────────┘  └──────────────┘  │   后端       │
        ↓                ↓                ↓           └──────────────┘
┌──────────────┐  ┌──────────────┐  ┌──────────────┐          ↓
│  libssl.so   │  │  schannel    │  │ libmbedtls   │  ┌──────────────┐
│  libcrypto   │  │  (Windows)   │  │              │  │ pure Pascal   │
└──────────────┘  └──────────────┘  └──────────────┘  │ TLS core/data │
                                                      └──────────────┘
```

---

## 核心接口

### 接口继承关系

```
IInterface (FreePascal 内置)
    ↑
    ├─ ISSLLibrary          (库管理)
    ├─ ISSLContext          (上下文管理)
    ├─ ISSLConnection       (连接管理)
    │   ├─ ISSLClientConnection  (客户端扩展)
    │   ├─ ISSLConnectionControl   (timeout / blocking owner)
    │   ├─ ISSLConnectionTextIO    (文本 helper owner)
    │   ├─ ISSLConnectionInfo      (连接信息 mirrors)
    │   ├─ ISSLDiagnostics         (诊断扩展)
    │   ├─ ISSLSessionResumption   (会话扩展)
    │   ├─ ISSLCertificateVerification (证书验证扩展)
    │   └─ ISSLOCSPStapling        (OCSP 扩展)
    ├─ ISSLCertificate      (证书管理)
    ├─ ISSLCertificateStore (证书存储)
    └─ ISSLSession          (会话管理)
```

> 当前 public Pascal source 只声明了 `ISSLClientConnection`；
> 服务端特有能力目前主要通过可选 context 扩展接口暴露，
> 而不是通过单独的 `ISSLServerConnection` 公开接口。
>
> 连接侧 owner surfaces 当前已经明确分层：
> `ISSLConnectionTextIO` / `ISSLConnectionControl` / `ISSLConnectionInfo` /
> `ISSLDiagnostics` / `ISSLSessionResumption` /
> `ISSLCertificateVerification` / `ISSLOCSPStapling`；
> `ISSLConnection` 继续作为 compatibility-facing core shell。
>
> `ISSLConnection` 的 connection-side owner surfaces 当前主要通过这些可选接口暴露：
> - `ISSLConnectionControl`：timeout / blocking runtime control owner
> - `ISSLConnectionTextIO`：text helper owner；框架/transport 集成仍优先使用 `Read` / `Write`
> - `ISSLConnectionInfo`：connection info / ALPN / context / state-string mirrors 的默认 owner
> - `ISSLDiagnostics` / `ISSLSessionResumption` / `ISSLCertificateVerification` / `ISSLOCSPStapling`：其余 connection-side optional owners

### ISSLLibrary - 库管理

```pascal
ISSLLibrary = interface
  ['{GUID}']
  function Initialize: Boolean;
  procedure Finalize;
  function IsInitialized: Boolean;
  function GetVersionString: string;
  function GetLibraryType: TSSLLibraryType;

  function CreateContext(AContextType: TSSLContextType): ISSLContext;
  function CreateCertificate: ISSLCertificate;
  function CreateCertificateStore: ISSLCertificateStore;
  // ... 工厂方法
end;
```

### ISSLContext - 上下文管理

```pascal
ISSLContext = interface
  ['{GUID}']
  function CreateConnection(ASocket: THandle): ISSLConnection; overload;
  function CreateConnection(AStream: TStream): ISSLConnection; overload;

  function GetContextType: TSSLContextType;
  function IsValid: Boolean;

  procedure SetProtocolVersions(AMin, AMax: TSSLProtocolVersion);
  procedure SetVerifyMode(AMode: TSSLVerifyMode);
  procedure SetCipherList(const ACiphers: string);
  // ... 配置方法
end;
```

### ISSLConnection - 连接管理

以下代码块是 **概念上的最小 core slice**，不是 `v1.5.0` 当前 shipped source 的完整逐行镜像。
当前 shipped source 仍保留 `ReadString` / `WriteString` 与 timeout/blocking 这组 convenience-core / connection-adjacent 方法；权威 source-truth 视图请看 `docs/reference/API_REFERENCE.md`。
当前 shipped source 对 timeout / blocking 这组 runtime control state 已补上 `ISSLConnectionControl` owner path；core 侧继续保留 convenience mirror。
当前 shipped source 对 `ReadString` / `WriteString` 这组文本 helper 也已补上 `ISSLConnectionTextIO` owner path；core 侧继续保留 convenience mirror。

```pascal
ISSLConnection = interface
  ['{GUID}']
  function Connect: Boolean;
  function Accept: Boolean;
  function Shutdown: Boolean;

  function Read(var ABuffer; ACount: Integer): Integer;
  function Write(const ABuffer; ACount: Integer): Integer;

  function GetState: string;
  function GetPeerCertificate: ISSLCertificate;
  // ... 连接方法
end;
```

---

## 可选接口

### ISSLConnectionControl - timeout / blocking 控制 (v1.5.0+)

**设计目的**:
- 为连接创建后的 runtime control state 提供正式 owner path
- 保持 builder / connector / acceptor 仍是更高层的 build-stage 推荐入口
- 让 `ISSLConnection` 上的 timeout / blocking 方法继续作为 `v1.x` convenience mirror 保留

```pascal
ISSLConnectionControl = interface
  procedure SetTimeout(ATimeout: Integer);
  function GetTimeout: Integer;
  procedure SetBlocking(ABlocking: Boolean);
  function GetBlocking: Boolean;
end;
```

### ISSLConnectionTextIO - 文本 helper (v1.5.0+)

**设计目的**:
- 为连接创建后的文本 helper 语义提供正式 owner path
- 保持框架 / transport / framing 集成仍优先直接走 `Read` / `Write`
- 让 `ISSLConnection` 上的 `ReadString` / `WriteString` 继续作为 `v1.x` convenience mirror 保留

```pascal
ISSLConnectionTextIO = interface
  function ReadString(out AStr: string): Boolean;
  function WriteString(const AStr: string): Boolean;
end;
```

### ISSLNativeHandleAccess - 原生句柄访问 (v1.1+)

**设计目的**:
- 允许高级用户访问底层 C 库句柄
- 不强制所有后端实现（支持纯 Pascal 后端）

```pascal
ISSLNativeHandleAccess = interface
  ['{B2C4E6F8-1A2B-3C4D-5E6F-7A8B9C0D1E2F}']

  {** 获取后端原生句柄 *}
  function GetNativeHandle: Pointer;

  {** 获取后端类型 *}
  function GetBackendType: TSSLLibraryType;

  {** 检查原生句柄是否有效 *}
  function IsNativeHandleValid: Boolean;
end;
```

**使用模式**:

```pascal
// 检查并使用原生句柄
var
  Ctx: ISSLContext;
  NativeAccess: ISSLNativeHandleAccess;
begin
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Ctx := Lib.CreateContext(sslCtxClient);

  // 运行时检查是否支持
  if Supports(Ctx, ISSLNativeHandleAccess, NativeAccess) then
  begin
    // C 库后端 - 可以访问原生句柄
    Handle := NativeAccess.GetNativeHandle;
    BackendType := NativeAccess.GetBackendType;
  end
  else
  begin
    // 纯 Pascal 后端 - 无原生句柄
    WriteLn('Pure Pascal backend');
  end;
end;
```

### 其他可选接口

```pascal
// PKCS#11 硬件令牌支持
ISSLPkcs11Support = interface
  function LoadPkcs11Module(const AModulePath: string): Boolean;
  // ...
end;

// DANE/DNSSEC 支持
ISSLDaneSupport = interface
  function VerifyDaneRecord(const ADomain: string; ...): Boolean;
  // ...
end;
```

---

## 后端架构

### 后端接口实现

后端按 capability / runtime truth 暴露 optional interface，
不是每个 backend / class 都统一实现全部 optional surfaces。

```pascal
// OpenSSL 后端
TOpenSSLContext = class(TInterfacedObject,
                        ISSLContext,           // 核心
                        ISSLNativeHandleAccess) // 可选
private
  FCtx: PSSL_CTX;  // OpenSSL 原生句柄
public
  // ISSLContext 实现
  function CreateConnection(...): ISSLConnection; override;
  // ...

  // ISSLNativeHandleAccess 实现
  function GetNativeHandle: Pointer;
  function GetBackendType: TSSLLibraryType;
  function IsNativeHandleValid: Boolean;
end;

// 纯 Pascal 后端（当前实现）
TFreePascalSSLContext = class(TInterfacedObject, ISSLContext)
  // ✅ 仅实现 ISSLContext
  // ✅ 不实现 ISSLNativeHandleAccess
private
  FConfig: TPascalTLSConfig;  // 纯 Pascal 数据
public
  // ISSLContext 实现
  function CreateConnection(...): ISSLConnection; override;
  // ...
end;
```

### 后端文件组织

```
src/
├── fafafa.ssl.pas                   # 主门面 re-export
├── fafafa.ssl.base.pas              # 核心接口定义
├── fafafa.ssl.factory.pas           # 工厂模式 / core factory surface
├── fafafa.ssl.context.builder.pas   # 推荐 context builder 入口
├── fafafa.ssl.tls.pas               # TSSLConnector / TSSLAcceptor / TSSLStream
├── fafafa.ssl.native_handle.pas     # 当前统一 native-handle helper
│
├── fafafa.ssl.openssl.base.pas      # OpenSSL 基础定义
├── fafafa.ssl.openssl.api.*.pas     # OpenSSL API 绑定
├── fafafa.ssl.openssl.backed.pas    # OpenSSL ISSLLibrary 实现 / 注册入口
├── fafafa.ssl.openssl.context.pas   # ISSLContext 实现
├── fafafa.ssl.openssl.connection.pas# ISSLConnection 实现
├── fafafa.ssl.openssl.certificate.pas# ISSLCertificate 实现
├── fafafa.ssl.openssl.native_handle.pas # backend-specific helper
│
├── fafafa.ssl.winssl.*.pas          # WinSSL 后端
├── fafafa.ssl.mbedtls.*.pas         # MbedTLS 后端
├── fafafa.ssl.freepascal.*.pas      # FreePascal 后端
└── fafafa.ssl.wolfssl.*.pas         # WolfSSL 后端
```

---

## 工厂模式

### TSSLFactory 核心功能

```pascal
TSSLFactory = class
public
  // 后端注册
  class procedure RegisterLibrary(
    ALibType: TSSLLibraryType;
    ACreateFunc: TSSLLibraryCreateFunc;
    const ADescription: string = '';
    APriority: Integer = 0
  ); overload;

  // 自动检测
  class function DetectBestLibrary: TSSLLibraryType;

  // 当前公开库入口
  class function GetLibraryInstance(
    ALibType: TSSLLibraryType = sslAutoDetect
  ): ISSLLibrary;

  // core / factory surface
  class function CreateContext(
    AContextType: TSSLContextType;
    ALibType: TSSLLibraryType = sslAutoDetect
  ): ISSLContext; overload;

  class function GetAvailableLibraries: TSSLLibraryTypes;
  class function IsLibraryAvailable(ALibType: TSSLLibraryType): Boolean;
end;
```

### 后端优先级

当前注册优先级（数字越大越优先）：

- `WinSSL=200`
- `MbedTLS=175`
- `WolfSSL=150`
- `OpenSSL=100`
- `FreePascal=50`

`DetectBestLibrary()` / `GetLibraryInstance(sslAutoDetect)` 的当前核心逻辑是：

1. 扫描已注册 backend
2. 对每个 backend 调用 `IsLibraryAvailable(...)`
3. 选择 **优先级最高且真正可用** 的实现

也就是说，
当前主叙事不是“Linux 固定 OpenSSL / Windows 固定 WinSSL”，
而是“注册表 + availability + priority”。
平台分支只是在没有候选命中时的兜底路径。

---

## 扩展性设计

### 1. 添加新后端

步骤：

1. **创建基础单元**:
   ```pascal
   unit fafafa.ssl.newbackend.base;
   // 类型定义和常量
   ```

2. **实现核心接口**:
   ```pascal
   unit fafafa.ssl.newbackend.lib;
   type
     TNewBackendSSLLibrary = class(TInterfacedObject, ISSLLibrary)
       // 实现所有 ISSLLibrary 方法
     end;
   ```

3. **注册后端**:
   ```pascal
   initialization
     TSSLFactory.RegisterLibrary(
       sslNewBackend,
       @CreateNewBackendLibrary,
       'NewBackend TLS',
       80  // 优先级示例
     );
   ```

4. **可选实现 ISSLNativeHandleAccess**（如果基于 C 库）

### 2. 添加新功能

通过可选接口扩展：

```pascal
// 定义新接口
ISSLAdvancedFeature = interface
  ['{NEW-GUID}']
  function DoAdvancedThing: Boolean;
end;

// 在支持的后端实现
TOpenSSLContext = class(..., ISSLAdvancedFeature)
  function DoAdvancedThing: Boolean;
end;

// 用户代码检查并使用
if Supports(Ctx, ISSLAdvancedFeature, AdvFeature) then
  AdvFeature.DoAdvancedThing;
```

---

## v1.1 架构改进

### 改进前（v1.0.0）

**问题**:
- `GetNativeHandle` 在核心接口中
- 所有后端必须实现（即使是纯 Pascal 后端）
- 暴露了实现细节

```pascal
ISSLContext = interface
  function GetNativeHandle: Pointer;  // ❌ 所有后端必须实现
end;

// 纯 Pascal 后端被迫返回 nil
function TPascalContext.GetNativeHandle: Pointer;
begin
  Result := nil;  // ❌ 无意义的实现
end;
```

### 改进后（v1.1.0）

**解决方案**:
- 移除核心接口中的 `GetNativeHandle`
- 创建可选接口 `ISSLNativeHandleAccess`
- C 库后端实现，纯 Pascal 后端忽略

```pascal
// 核心接口 - 清晰
ISSLContext = interface
  // 无 GetNativeHandle
end;

// 可选接口 - 明确
ISSLNativeHandleAccess = interface
  function GetNativeHandle: Pointer;
end;

// C 库后端实现
TOpenSSLContext = class(..., ISSLNativeHandleAccess)
  function GetNativeHandle: Pointer;  // ✅ 返回真实句柄
end;

// 纯 Pascal 后端忽略
TPascalContext = class(..., ISSLContext)
  // ✅ 无需实现 GetNativeHandle
end;
```

### 架构优势

| 方面 | v1.0.0 | v1.1.0 |
|------|--------|--------|
| **抽象清晰度** | ❌ 核心接口暴露实现细节 | ✅ 核心接口纯粹抽象 |
| **纯 Pascal 支持** | ❌ 被迫实现无意义方法 | ✅ 无需实现不相关接口 |
| **类型安全** | ⚠️ 用户可能误用 | ✅ Supports 查询强制检查 |
| **扩展性** | ⚠️ 添加新接口破坏所有后端 | ✅ 可选接口灵活扩展 |

---

## 设计模式总结

fafafa.ssl 使用的设计模式：

1. **工厂模式** - TSSLFactory 创建后端实例
2. **抽象工厂** - 每个后端是一个抽象工厂
3. **接口隔离** - 核心接口 + 可选接口
4. **依赖注入** - 通过接口参数传递依赖
5. **策略模式** - 运行时选择后端
6. **适配器模式** - 统一不同 C 库 API

---

## 当前路线与演进边界

当前执行顺序与产品路线以 [ROADMAP.md](ROADMAP.md) 为准。
当前 release/runtime 结论请看 [test_reports/RELEASE_READINESS_V1.5.0.md](test_reports/RELEASE_READINESS_V1.5.0.md)。
当前下一条更大的 completeness 主线，继续以 [plans/2026-03-25-ssl-tls-backend-completeness-roadmap-and-freepascal-tls13-aes256-sha384-parity.md](plans/2026-03-25-ssl-tls-backend-completeness-roadmap-and-freepascal-tls13-aes256-sha384-parity.md) 为候选入口。
当前整体规格 / 架构原则 / 演进路线锚点，见 [plans/2026-05-24-framework-excellence-spec-and-evolution-roadmap.md](plans/2026-05-24-framework-excellence-spec-and-evolution-roadmap.md)。

这份根层 `ARCHITECTURE.md` 当前只负责：

- 当前 public entrypoint 与 backend/layering 总览
- connection-side owner surface 与 optional interface 的架构关系
- backend file layout / factory / priority 这类当前 shipped truth

这页不再继续承载：

- `v1.2-v1.3` / `v2.0` / `v3.0` 这类 future-version 路线桶
- 已发布项目的历史阶段待办清单
- release/runtime 状态公告牌

如果后续要继续推进架构演进：

- 架构分层真相继续回到本页与 `docs/reference/ARCHITECTURE.md`
- 整体北极星、关键设计原则与长期演进顺序继续回到 `plans/2026-05-24-framework-excellence-spec-and-evolution-roadmap.md`

---

## 参考资料

- **接口设计**: [API_DESIGN_GUIDE.md](reference/API_DESIGN_GUIDE.md)
- **迁移指南**: [MIGRATION_GUIDE_V1.1.md](MIGRATION_GUIDE_V1.1.md)
- **当前路线图**: [ROADMAP.md](ROADMAP.md)
- **整体规格与演进路线**: [plans/2026-05-24-framework-excellence-spec-and-evolution-roadmap.md](plans/2026-05-24-framework-excellence-spec-and-evolution-roadmap.md)
- **当前 completeness 主线**: [plans/2026-03-25-ssl-tls-backend-completeness-roadmap-and-freepascal-tls13-aes256-sha384-parity.md](plans/2026-03-25-ssl-tls-backend-completeness-roadmap-and-freepascal-tls13-aes256-sha384-parity.md)

---

**文档版本**: v1.5.0
**最后更新**: 2026-05-21
**作者**: fafafa.ssl 架构团队
