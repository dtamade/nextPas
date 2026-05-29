# fafafa.ssl 后端自动选择指南

**版本**: v1.5.0
**作者**: fafafa.ssl 团队
**更新日期**: 2026-05-21

---

## 目录

1. [概述](#概述)
2. [快速开始](#快速开始)
3. [TSSLRequirements 详解](#tsslrequirements-详解)
4. [评分算法说明](#评分算法说明)
5. [Builder API](#builder-api)
6. [使用场景](#使用场景)
7. [最佳实践](#最佳实践)
8. [常见问题](#常见问题)

---

## 概述

### 什么是自动后端选择？

自动后端选择是 fafafa.ssl v1.3.0 引入的智能功能，它可以根据您的需求自动选择最佳的 SSL/TLS 后端实现（OpenSSL、WinSSL、WolfSSL、MbedTLS）。

### 为什么需要它？

不同的后端有不同的特性和优势：

- **OpenSSL**: 功能最全面，性能优秀，广泛支持
- **WinSSL**: Windows 原生，零依赖，系统集成好
- **WolfSSL**: 体积小，适合嵌入式
- **MbedTLS**: 模块化，代码简洁

手动选择后端需要了解每个后端的详细特性。自动选择可以帮您：

- ✅ 根据安全、性能、兼容性需求智能选择
- ✅ 确保选择的后端满足所有必需功能
- ✅ 优化用户体验（如 Windows 优先使用 WinSSL）
- ✅ 简化代码，无需手动判断

### 核心组件

1. **TSSLRequirements**: 需求定义记录
2. **SelectBestBackend()**: 单选函数
3. **SelectBestBackends()**: 多选函数
4. **Builder 集成**: 链式 API

当前入口说明：这页聚焦 backend auto-selection / builder integration / direct selector API。
如果你只是普通客户端/服务端 TLS 建立，请优先回到 `docs/guides/GETTING_STARTED.md` 里的 `TSSLContextBuilder` / `TSSLConnector` / `TSSLAcceptor` / `TSSLStream` 主路径。
这里保留 direct selector 示例，是因为它们属于专项 backend-selection API，不是普通 TLS bootstrap 第一入口。

---

## 快速开始

### 方式 1: 使用 Builder（推荐）

```pascal
uses
  fafafa.ssl,
  fafafa.ssl.context.builder;

var
  Ctx: ISSLContext;
begin
  // 安全优先
  Ctx := TSSLContextBuilder.Create
    .WithSecurityFirst
    .WithVerifyPeer
    .BuildClient;

  // 性能优先
  Ctx := TSSLContextBuilder.Create
    .WithPerformanceFirst
    .WithVerifyPeer
    .BuildClient;

  // 兼容性优先
  Ctx := TSSLContextBuilder.Create
    .WithCompatibilityFirst
    .WithVerifyPeer
    .BuildClient;
end;
```

这里的 Builder 推荐示例只负责“自动后端选择 + context 构建”。
真正把已连接 socket/stream 升级成 TLS 时，普通调用方仍优先回到 `TSSLConnector` / `TSSLAcceptor` / `TSSLStream`。

### 方式 2: 直接使用选择器

```pascal
uses
  fafafa.ssl.backend.selector;

var
  Requirements: TSSLRequirements;
  SelectedType: TSSLLibraryType;
  MatchScore: Integer;
begin
  // 创建需求
  Requirements := CreateSecurityFirstRequirements;

  // 选择后端
  if SelectBestBackend(Requirements, SelectedType, MatchScore) then
  begin
    WriteLn('选择的后端: ', Ord(SelectedType));
    WriteLn('匹配分数: ', MatchScore, '/100');
  end;
end;
```

### 方式 3: 链式需求定义

```pascal
Ctx := TSSLContextBuilder.Create
  .RequireTLS13                           // 必须 TLS 1.3
  .RequireCipher(sslCipherCHACHA20_POLY1305)  // 必须 ChaCha20
  .RequirePKCS11Support                   // 必须 PKCS#11
  .PreferOSNative                         // 优先 OS 原生
  .WithVerifyPeer
  .BuildClient;
```

---

## TSSLRequirements 详解

### 记录结构

```pascal
TSSLRequirements = record
  { 必需的协议支持 }
  RequiredProtocols: TSSLProtocolVersions;

  { 必需的算法支持 }
  RequiredCiphers: TSSLCipherSupport;
  RequiredHashes: TSSLHashSupport;
  RequiredKeyExchanges: TSSLKeyExchangeSupport;

  { 必需的功能 }
  RequiredFeatures: TSSLFeatures;

  { 优选的算法（可选） }
  PreferredCiphers: TSSLCipherSupport;
  PreferredHashes: TSSLHashSupport;

  { 最低评分要求 }
  MinSecurityScore: Integer;        // 0-100，默认 0
  MinPerformanceScore: Integer;     // 0-100，默认 0
  MinCompatibilityLevel: Integer;   // 0-100，默认 0

  { 平台偏好 }
  PlatformPreferences: TSSLPlatformPreferences;

  { 优化目标 }
  OptimizationTarget: TSSLOptimizationTarget;
end;
```

### 优化目标

```pascal
TSSLOptimizationTarget = (
  optBalanced,       // 平衡（默认）
  optSecurity,       // 优先安全
  optPerformance,    // 优先性能
  optSize,           // 优先体积（嵌入式）
  optCompatibility   // 优先兼容性
);
```

### 平台偏好

```pascal
TSSLPlatformPreferences = record
  PreferOSNative: Boolean;          // 优先 OS 原生实现
  PreferHardwareAccel: Boolean;     // 优先硬件加速
  PreferFIPSCompliant: Boolean;     // 优先 FIPS 兼容
  RequirePKCS11: Boolean;           // 需要 PKCS#11
  RequireTPM: Boolean;              // 需要 TPM
  RequireSystemCertStore: Boolean;  // 需要系统证书存储
end;
```

### 创建默认需求

```pascal
// 平衡需求（默认）
Requirements := CreateDefaultRequirements(optBalanced);

// 安全优先需求
Requirements := CreateSecurityFirstRequirements;
// 等同于：
Requirements := CreateDefaultRequirements(optSecurity);

// 性能优先需求
Requirements := CreatePerformanceFirstRequirements;

// 兼容性优先需求
Requirements := CreateCompatibilityFirstRequirements;
```

### 手动定义需求

```pascal
var
  Requirements: TSSLRequirements;
begin
  FillChar(Requirements, SizeOf(Requirements), 0);

  // 必须支持 TLS 1.3
  Requirements.RequiredProtocols := [sslProtocolTLS13];

  // 必须支持现代密码算法
  Requirements.RequiredCiphers := [
    sslCipherAES256GCM,
    sslCipherCHACHA20_POLY1305
  ];

  // 必须支持 SHA-256 以上
  Requirements.RequiredHashes := [
    sslHashSHA256,
    sslHashSHA384,
    sslHashSHA512
  ];

  // 必须支持前向保密
  Requirements.RequiredKeyExchanges := [
    sslKexECDHE_RSA,
    sslKexECDHE_ECDSA
  ];

  // 最低安全评分 80
  Requirements.MinSecurityScore := 80;

  // 优化目标：安全
  Requirements.OptimizationTarget := optSecurity;
end;
```

---

## 评分算法说明

### 总分计算公式 (0-100)

```
总分 = 必需功能(40%) + 优选功能(20%) + 安全评分(20%) + 性能评分(10%) + 平台匹配(10%)
```

### 详细说明

#### 1. 必需功能检查 (40%)

**不满足直接返回 0 分**，满足则得 40 分。

检查项目：

- 协议版本支持（TLS 1.2/1.3）
- 密码算法支持（AES-GCM, ChaCha20）
- 哈希算法支持（SHA-256/384/512）
- 密钥交换支持（ECDHE-RSA, ECDHE-ECDSA）
- 功能支持（SNI, ALPN, OCSP）
- 平台特性（PKCS#11, TPM, 系统证书库）

#### 2. 优选功能评分 (20%)

根据优选功能的匹配度计算，0-20 分。

```pascal
PreferredScore = (MatchedCount / TotalCount) * 20
```

#### 3. 安全评分 (20%)

使用后端能力矩阵中的 `SecurityScore` 字段。

权重根据优化目标调整：

- `optSecurity`: 40% (最高权重)
- `optBalanced`: 20% (默认)
- `optPerformance`: 10% (最低权重)

#### 4. 性能评分 (10%)

使用后端能力矩阵中的 `PerformanceScore` 字段。

权重根据优化目标调整：

- `optPerformance`: 40% (最高权重)
- `optBalanced`: 20% (默认)
- `optSecurity`: 10% (最低权重)

#### 5. 平台匹配 (10%)

根据平台偏好计算，最高 10 分。

- OS 原生实现: +3 分
- 硬件加速: +2.5 分
- FIPS 兼容: +2.5 分
- PKCS#11 支持: +1 分
- TPM 支持: +1 分

### 评分示例

#### OpenSSL 3.5.4 后端评分

**能力矩阵**:

- SecurityScore: 90/100
- PerformanceScore: 100/100
- SupportsTLS13: Yes
- SupportsPKCS11: Runtime-dependent (requires Provider / ENGINE readiness)
- HasHardwareAcceleration: Yes

平台分数 5.5/10 假设当前 OpenSSL runtime 已发布 PKCS#11 capability；若 Provider / ENGINE surface 不就绪，该项会更低。

**测试结果**:

| 优化目标              | 必需功能 | 优选 | 安全 | 性能 | 平台 | 总分    |
| --------------------- | -------- | ---- | ---- | ---- | ---- | ------- |
| 平衡 (optBalanced)    | 40       | 20   | 18   | 10   | 5.5  | 80/100  |
| 安全 (optSecurity)    | 40       | 20   | 36   | 4    | 5.5  | 88/100  |
| 性能 (optPerformance) | 40       | 20   | 9    | 40   | 5.5  | 100/100 |

---

## Builder API

### 自动选择方法

#### WithAutoBackendSelection

显式指定需求进行自动选择。

```pascal
var
  Requirements: TSSLRequirements;
begin
  Requirements := CreateSecurityFirstRequirements;

  Ctx := TSSLContextBuilder.Create
    .WithAutoBackendSelection(Requirements)
    .WithVerifyPeer
    .BuildClient;
end;
```

#### WithSecurityFirst

安全优先的快捷方法。

```pascal
Ctx := TSSLContextBuilder.Create
  .WithSecurityFirst
  .WithVerifyPeer
  .BuildClient;
```

注意：`WithSecurityFirst` 会优先满足 TLS 1.3、现代密码套件与安全评分；它本身不等于默认已进入 FIPS 路线。

**等同于**:

```pascal
Requirements := CreateSecurityFirstRequirements;
// 强制 TLS 1.3
// 要求 AES-256-GCM + ChaCha20
// 要求 SHA-256+ 哈希
// 要求前向保密密钥交换
// 最低安全评分 80
```

#### WithPerformanceFirst

性能优先的快捷方法。

```pascal
Ctx := TSSLContextBuilder.Create
  .WithPerformanceFirst
  .WithVerifyPeer
  .BuildClient;
```

**特点**:

- 优先硬件加速
- 最低性能评分 85
- 优选硬件加速的算法（AES-NI）

这些快捷方法只负责 backend requirement / auto-selection，不会替 client/server 决定 VerifyMode。
如果你最后走 `BuildServer`，仍需要显式写出当前 server verify 意图：

- 普通单向 TLS server：`.WithVerifyNone`
- mTLS server：`.WithMutualTLS(...)`

#### WithCompatibilityFirst

兼容性优先的快捷方法。

```pascal
Ctx := TSSLContextBuilder.Create
  .WithCompatibilityFirst
  .WithVerifyPeer
  .BuildClient;
```

**特点**:

- 支持 TLS 1.2 和 1.3
- 无特定算法要求
- 最低兼容性 85

### 显式指定方法

#### WithBackend

显式指定后端类型。

```pascal
Ctx := TSSLContextBuilder.Create
  .WithBackend(sslOpenSSL)  // 强制使用 OpenSSL
  .WithVerifyPeer
  .BuildClient;
```

**注意**: 使用 `WithBackend` 会禁用自动选择。

### 需求累加方法

#### RequireTLS13

要求支持 TLS 1.3。

```pascal
Ctx := TSSLContextBuilder.Create
  .RequireTLS13
  .WithVerifyPeer
  .BuildClient;
```

**行为**:

- 如果未启用自动选择，自动启用并创建默认需求
- 添加 TLS 1.3 到必需协议列表

#### RequireCipher

要求支持特定密码算法。

```pascal
Ctx := TSSLContextBuilder.Create
  .RequireCipher(sslCipherCHACHA20_POLY1305)
  .WithVerifyPeer
  .BuildClient;
```

**可用算法**:

- `sslCipherAES128`
- `sslCipherAES256`
- `sslCipherAES128GCM`
- `sslCipherAES256GCM`
- `sslCipherCHACHA20_POLY1305`

#### RequirePKCS11Support

要求当前已发布 PKCS#11 capability；若当前没有任何已注册 backend 发布 `SupportsPKCS11=True`，自动选择会失败。

在 OpenSSL 路径下，这又取决于 Provider / ENGINE runtime surface readiness。

```pascal
Ctx := TSSLContextBuilder.Create
  .RequirePKCS11Support
  .WithVerifyPeer
  .BuildClient;
```

#### PreferOSNative

优先选择 OS 原生实现。

```pascal
Ctx := TSSLContextBuilder.Create
  .PreferOSNative
  .WithVerifyPeer
  .BuildClient;
```

**效果**:

- Windows: 优先选择 WinSSL
- macOS: 优先选择 SecureTransport（如果实现）
- Linux: 优先选择系统 OpenSSL

### 链式组合

```pascal
// 复杂需求组合
Ctx := TSSLContextBuilder.Create
  .RequireTLS13                           // 1. TLS 1.3
  .RequireCipher(sslCipherCHACHA20_POLY1305)  // 2. ChaCha20
  .RequirePKCS11Support                   // 3. PKCS#11（取决于当前 runtime-aware capability）
  .PreferOSNative                         // 4. OS 原生
  .WithVerifyPeer                         // 5. 验证对端
  .WithSystemRoots                        // 6. 系统证书
  .BuildClient;                           // 7. 构建客户端
```

---

## 使用场景

### 场景 1: 通用 HTTPS 客户端

**需求**: 安全可靠的 HTTPS 连接。

```pascal
Ctx := TSSLContextBuilder.Create
  .WithSecurityFirst
  .WithVerifyPeer
  .WithSystemRoots
  .BuildClient;
```

### 场景 2: 高性能服务器

**需求**: 处理大量并发连接，性能优先。

```pascal
Ctx := TSSLContextBuilder.Create
  .WithPerformanceFirst
  .WithCertificate('server.crt')
  .WithPrivateKey('server.key')
  .WithVerifyNone  // 普通单向 TLS server；如需 mTLS 改用 WithMutualTLS(...)
  .BuildServer;
```

### 场景 3: 嵌入式设备

**需求**: 体积小，资源受限。

```pascal
Requirements := CreateDefaultRequirements(optSize);

Ctx := TSSLContextBuilder.Create
  .WithAutoBackendSelection(Requirements)
  .WithVerifyPeer
  .BuildClient;
```

**结果**: 可能选择 MbedTLS（体积最小）。

### 场景 4: 政府/金融系统

**需求**: FIPS 140-2 合规，PKCS#11 HSM 集成。

```pascal
Ctx := TSSLContextBuilder.Create
  .RequireTLS13
  .RequirePKCS11Support
  .WithVerifyPeer
  .BuildClient;
```

注意：这段代码表达的是需求，不保证当前默认 shipped backends 一定能自动满足。

OpenSSL 默认构建 capability 不发布 FIPS，WinSSL 当前 capability 不发布 PKCS#11；如需这条路线，必须先准备专门 OpenSSL FIPS 模块/构建，并确认 PKCS#11 runtime surface 已发布。

### 场景 5: Windows 应用

**需求**: 零依赖部署，系统集成。

```pascal
Ctx := TSSLContextBuilder.Create
  .PreferOSNative
  .WithVerifyPeer
  .WithSystemRoots
  .BuildClient;
```

**结果**: 优先选择 WinSSL。

注意：如果你的真实需求还包括：

- 把 session resumption / tickets 当成已稳定 runtime-proven 能力
- 需要 caller-provided server OCSP stapling
- 需要 Early Data / 更强的 protocol/runtime 控制

则不要只因为“Windows + 零依赖”就默认停在 WinSSL；这类路线当前仍应优先重新评估 OpenSSL。

### 场景 6: 跨平台应用

**需求**: 最大兼容性，支持旧版本 TLS。

```pascal
Ctx := TSSLContextBuilder.Create
  .WithCompatibilityFirst
  .WithVerifyPeer
  .BuildClient;
```

---

## 最佳实践

### 1. 优先使用 Builder API

✅ **推荐**:

```pascal
Ctx := TSSLContextBuilder.Create
  .WithSecurityFirst
  .WithVerifyPeer
  .BuildClient;
```

❌ **不推荐**:

```pascal
Requirements := CreateSecurityFirstRequirements;
SelectBestBackend(Requirements, BackendType, Score);
Ctx := TSSLFactory.CreateContext(sslCtxClient, BackendType);
```

**原因**: Builder API 更简洁，链式调用可读性好。

### 2. 先定义需求，后构建上下文

✅ **推荐**:

```pascal
Builder := TSSLContextBuilder.Create
  .WithSecurityFirst
  .WithVerifyPeer
  .WithSystemRoots;

// ... 其他配置 ...

Ctx := Builder.BuildClient;
```

### 3. 使用快捷方法

✅ **推荐**:

```pascal
Ctx := TSSLContextBuilder.Create
  .WithPerformanceFirst  // 简洁明了
  .BuildClient;
```

❌ **不推荐**:

```pascal
Requirements := CreateDefaultRequirements(optPerformance);
Requirements.MinPerformanceScore := 85;
// ... 手动配置各种字段 ...
Ctx := TSSLContextBuilder.Create
  .WithAutoBackendSelection(Requirements)
  .BuildClient;
```

### 4. 验证需求

在生产环境中，建议验证需求：

```pascal
var
  Requirements: TSSLRequirements;
  Errors: TStringArray;
begin
  Requirements := CreateSecurityFirstRequirements;

  if not ValidateRequirements(Requirements, Errors) then
  begin
    WriteLn('需求验证失败:');
    for Error in Errors do
      WriteLn('  - ', Error);
    Exit;
  end;

  Ctx := TSSLContextBuilder.Create
    .WithAutoBackendSelection(Requirements)
    .BuildClient;
end;
```

### 5. 处理选择失败

```pascal
try
  Ctx := TSSLContextBuilder.Create
    .WithSecurityFirst
    .BuildClient;
except
  on E: ESSLException do
  begin
    WriteLn('自动选择失败: ', E.Message);
    // 回退到默认后端
    Ctx := TSSLFactory.CreateContext(sslCtxClient, sslOpenSSL);
  end;
end;
```

### 6. 记录选择结果

```pascal
var
  Results: TSSLBackendMatchArray;
  i: Integer;
begin
  Requirements := CreateSecurityFirstRequirements;
  Results := SelectBestBackends(Requirements, 3);

  WriteLn('候选后端:');
  for i := 0 to High(Results) do
  begin
    WriteLn('  ', i + 1, '. ', Results[i].BackendName);
    WriteLn('     分数: ', Results[i].MatchScore, '/100');
    WriteLn('     原因: ', Results[i].RecommendationReason);
  end;
end;
```

---

## 常见问题

### Q1: 自动选择会比手动选择慢吗？

**A**: 不会。自动选择使用缓存的能力矩阵（10M+ ops/s），评分算法非常快（<1ms）。

### Q2: 我可以混合使用自动选择和显式指定吗？

**A**: 可以，但显式指定会覆盖自动选择：

```pascal
Ctx := TSSLContextBuilder.Create
  .WithSecurityFirst          // 启用自动选择
  .WithBackend(sslOpenSSL)    // 覆盖为 OpenSSL
  .BuildClient;
```

### Q3: 如果没有后端满足需求怎么办？

**A**: 抛出 `ESSLException` 异常：

```pascal
try
  Ctx := TSSLContextBuilder.Create
    .WithSecurityFirst
    .BuildClient;
except
  on E: ESSLException do
    WriteLn('错误: ', E.Message);
end;
```

### Q4: 默认的 optBalanced 是什么策略？

**A**:

- TLS 1.2/1.3 支持
- 最低安全评分 60
- 最低性能评分 60
- 权重: 安全 20%, 性能 20%, 平台 10%

### Q5: 我可以自定义评分权重吗？

**A**: v1.3.0 不支持，但可以通过 `OptimizationTarget` 间接调整：

- `optSecurity`: 安全 40%, 性能 10%
- `optPerformance`: 安全 10%, 性能 40%
- `optBalanced`: 安全 20%, 性能 20%

### Q6: RequireTLS13 和 WithTLS13 的区别？

**A**:

- `RequireTLS13`: 启用自动选择，要求后端支持 TLS 1.3
- `WithTLS13`: 配置上下文使用 TLS 1.3，不涉及后端选择

可以组合使用：

```pascal
Ctx := TSSLContextBuilder.Create
  .RequireTLS13      // 选择支持 TLS 1.3 的后端
  .WithTLS13         // 配置上下文使用 TLS 1.3
  .BuildClient;
```

### Q7: 如何查看所有可用后端的评分？

**A**:

```pascal
var
  Requirements: TSSLRequirements;
  Results: TSSLBackendMatchArray;
begin
  Requirements := CreateDefaultRequirements;
  Results := SelectBestBackends(Requirements, 10);  // 最多 10 个

  for Match in Results do
    WriteLn(Match.BackendName, ': ', Match.MatchScore, '/100');
end;
```

### Q8: 自动选择是否考虑后端可用性？

**A**: 是的。`SelectBestBackend` 只考虑 `TSSLFactory.GetAvailableLibraries` 返回的可用后端。

### Q9: 我可以强制使用某个后端吗？

**A**: 可以，使用 `WithBackend`:

```pascal
Ctx := TSSLContextBuilder.Create
  .WithBackend(sslWinSSL)  // 强制 WinSSL
  .BuildClient;
```

### Q10: 如何为特定平台优化？

**A**:

**Windows**:

```pascal
Ctx := TSSLContextBuilder.Create
  .PreferOSNative  // 优先 WinSSL
  .BuildClient;
```

**需要硬件加速**:

```pascal
Requirements := CreatePerformanceFirstRequirements;
Requirements.PlatformPreferences.PreferHardwareAccel := True;

Ctx := TSSLContextBuilder.Create
  .WithAutoBackendSelection(Requirements)
  .BuildClient;
```

---

## 参考

### 相关文档

- [能力矩阵指南](CAPABILITY_MATRIX_GUIDE.md)
- [API 参考](reference/API_REFERENCE.md)
- [迁移指南](MIGRATION_GUIDE_V1.1.md)

### 源代码

- `src/fafafa.ssl.backend.selector.pas` - 选择器实现
- `src/fafafa.ssl.context.builder.pas` - Builder 集成
- `tests/test_backend_selector_basic.pas` - 基础测试
- `tests/test_builder_integration.pas` - Builder 测试

---

**文档版本**: v1.5.0
**适用版本**: fafafa.ssl v1.5.0+
**更新日期**: 2026-05-21
