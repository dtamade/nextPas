# 能力矩阵使用指南

**版本**: v1.5.0
**适用范围**: fafafa.ssl v1.5.0+
**目标读者**: 中高级开发者

---

## 📋 目录

1. [简介](#简介)
2. [基础概念](#基础概念)
3. [快速开始](#快速开始)
4. [详细使用](#详细使用)
5. [最佳实践](#最佳实践)
6. [实战示例](#实战示例)
7. [常见问题](#常见问题)

---

## 简介

能力矩阵最早在 fafafa.ssl v1.2.0 引入；本文当前内容对齐 fafafa.ssl v1.5.0 shipped truth。它允许您：

- 🔍 **查询后端特性**: TLS 版本、算法支持、协议支持等
- 📊 **评估后端质量**: 安全评分、性能评分
- 🎯 **智能决策**: 基于能力自动选择最佳后端
- 📝 **自描述**: 自动生成后端能力文档

---

## 基础概念

### TSSLBackendCapabilities 记录

能力矩阵的核心数据结构，包含 40+ 个字段：

```pascal
type
  TSSLBackendCapabilities = record
    // === v1.1.0 保留字段（向后兼容）===
    SupportsTLS13: Boolean;
    SupportsALPN: Boolean;
    SupportsSNI: Boolean;
    // ... 其他 8 个字段

    // === v1.2.0 新增字段 ===
    BackendType: TSSLLibraryType;
    BackendImplType: TSSLBackendImplType;
    BackendVersion: string;
    SupportsDTLS: Boolean;

    // 功能支持级别
    SNISupport: TSSLFeatureSupportLevel;
    ALPNSupport: TSSLFeatureSupportLevel;
    // ... 其他 8 个功能级别字段

    // 算法支持
    SupportedCiphers: TSSLCipherSupport;
    SupportedHashes: TSSLHashSupport;
    SupportedKeyExchanges: TSSLKeyExchangeSupport;

    // 性能特性
    HasHardwareAcceleration: Boolean;
    HasSIMDOptimization: Boolean;
    HasAssemblyOptimization: Boolean;

    // 平台特性
    RequiresExternalLibrary: Boolean;
    SupportsSystemCertStore: Boolean;
    SupportsPKCS11: Boolean;
    SupportsTPM: Boolean;

    // 安全特性
    HasConstantTimeOperations: Boolean;
    SupportsFIPSMode: Boolean;
    HasSecureMemoryWipe: Boolean;

    // 兼容性
    CompatibilityLevel: Integer;  // 0-100
    KnownIssues: string;
  end;
```

能力字段读取优先级：

- 当 `SNISupport` / `ALPNSupport` / `OCSPStaplingSupport` / `CertTransparencySupport` / `SessionTicketsSupport` 存在时，它们是当前 capability truth；legacy `SupportsSNI` / `SupportsALPN` / `SupportsOCSPStapling` / `SupportsCertificateTransparency` / `SupportsSessionTickets` 只作为兼容投影。
- `SupportsTLS13` 仍然是主 bool truth，因为当前没有 `TLS13Support` 支持级别字段。

### 枚举类型

#### TSSLBackendImplType - 后端实现类型

```pascal
type
  TSSLBackendImplType = (
    sslImplNative,      // 纯 FreePascal 实现（无外部依赖）
    sslImplCLibrary,    // C 语言库绑定（OpenSSL, WolfSSL, MbedTLS）
    sslImplOSNative,    // 操作系统原生 API（WinSSL, SecureTransport）
    sslImplHybrid       // 混合实现
  );
```

#### TSSLFeatureSupportLevel - 功能成熟度

```pascal
type
  TSSLFeatureSupportLevel = (
    sslSupportNone,         // 不支持
    sslSupportExperimental, // 实验性（不推荐生产）
    sslSupportStable,       // 稳定（推荐生产）
    sslSupportDeprecated    // 已弃用（计划移除）
  );
```

---

## 快速开始

### 获取能力矩阵

```pascal
uses fafafa.ssl;

var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Caps: TSSLBackendCapabilities;
begin
  // 方式1: 通过工厂获取库
  Lib := TSSLFactory.GetLibraryInstance(sslOpenSSL);
  Caps := Lib.GetCapabilities;

  // 方式2: 通过上下文获取
  Ctx := TSSLFactory.CreateContext(sslCtxClient, sslOpenSSL);
  Caps := Ctx.GetLibrary.GetCapabilities;
end;
```

普通 capability / native-handle 查询不必再拆分回 `uses fafafa.ssl.base` / `fafafa.ssl.factory`；`fafafa.ssl` 已 re-export 当前所需的 capability helper surface。

### 基础查询

```pascal
// 查询 TLS 版本支持
if Caps.SupportsTLS13 then
  WriteLn('TLS 1.3 is supported');

// 查询后端版本
WriteLn('Backend: ', LibraryTypeToString(Caps.BackendType));
WriteLn('Version: ', Caps.BackendVersion);

// 查询算法支持
if IsCipherSupported(Caps, sslCipherCHACHA20_POLY1305) then
  WriteLn('ChaCha20-Poly1305 is available');
```

---

## 详细使用

### 1. 算法支持查询

#### 对称加密算法

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 查询单个算法
  if IsCipherSupported(Caps, sslCipherAES256GCM) then
    WriteLn('AES-256-GCM: Available');

  // 遍历所有支持的算法
  if sslCipherAES128 in Caps.SupportedCiphers then
    WriteLn('AES-128: Supported');
  if sslCipherAES256 in Caps.SupportedCiphers then
    WriteLn('AES-256: Supported');
  if sslCipherCHACHA20_POLY1305 in Caps.SupportedCiphers then
    WriteLn('ChaCha20-Poly1305: Supported');

  // 检查多个算法
  if [sslCipherAES128GCM, sslCipherAES256GCM] <= Caps.SupportedCiphers then
    WriteLn('Both AES-GCM modes are supported');
end;
```

#### 哈希算法

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 查询哈希算法
  if IsHashSupported(Caps, sslHashSHA256) then
    WriteLn('SHA-256: Available');

  if IsHashSupported(Caps, sslHashSHA512) then
    WriteLn('SHA-512: Available');

  // 检查是否支持现代哈希算法
  if [sslHashSHA256, sslHashSHA384, sslHashSHA512] <= Caps.SupportedHashes then
    WriteLn('All SHA-2 family hashes are supported');
end;
```

#### 密钥交换算法

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 查询密钥交换
  if IsKeyExchangeSupported(Caps, sslKexECDHE_RSA) then
    WriteLn('ECDHE-RSA: Available');

  if IsKeyExchangeSupported(Caps, sslKexECDHE_ECDSA) then
    WriteLn('ECDHE-ECDSA: Available');

  // 检查是否支持前向保密
  if [sslKexECDHE_RSA, sslKexECDHE_ECDSA] * Caps.SupportedKeyExchanges <> [] then
    WriteLn('Forward secrecy is supported (ECDHE available)');
end;
```

### 2. 功能成熟度评估

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 检查功能是否稳定
  case Caps.ALPNSupport of
    sslSupportNone:
      WriteLn('ALPN: Not supported');
    sslSupportExperimental:
      WriteLn('ALPN: Available (experimental, use with caution)');
    sslSupportStable:
      WriteLn('ALPN: Production-ready');
    sslSupportDeprecated:
      WriteLn('ALPN: Deprecated (migrate to alternatives)');
  end;

  // 使用辅助函数
  if IsFeatureStable(Caps.SNISupport) then
    WriteLn('SNI is production-ready');

  if IsFeatureUsable(Caps.OCSPStaplingSupport) and
     not IsFeatureDeprecated(Caps.OCSPStaplingSupport) then
    WriteLn('OCSP Stapling can be used');
end;
```

### 3. 后端类型判断

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 判断实现类型
  case Caps.BackendImplType of
    sslImplNative:
      WriteLn('Pure FreePascal implementation (no dependencies)');
    sslImplCLibrary:
      WriteLn('C library binding (requires external library)');
    sslImplOSNative:
      WriteLn('OS native API (uses system TLS)');
    sslImplHybrid:
      WriteLn('Hybrid implementation');
  end;

  // 使用辅助函数
  if IsNativeBackend(Caps) then
    WriteLn('This is a pure Pascal backend');

  if IsCLibraryBackend(Caps) then
    WriteLn('This backend wraps a C library');

  if RequiresExternalDependencies(Caps) then
    WriteLn('External library required');
end;
```

### 4. 平台特性查询

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 系统集成特性
  if Caps.SupportsSystemCertStore then
    WriteLn('Can use system certificate store (e.g., Windows Certificate Store)');

  if Caps.SupportsPKCS11 then
    WriteLn('Can use PKCS#11 hardware tokens');

  if Caps.SupportsTPM then
    WriteLn('Can use Trusted Platform Module (TPM)');

  // Windows 平台推荐
  {$IFDEF WINDOWS}
  if Caps.SupportsSystemCertStore then
    WriteLn('Recommended for Windows: system certificate integration available');
  {$ENDIF}
end;
```

### 5. 安全特性查询

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 安全特性
  if Caps.HasConstantTimeOperations then
    WriteLn('Protected against timing attacks');

  if Caps.SupportsFIPSMode then
    WriteLn('Can operate in FIPS 140-2 mode');

  if Caps.HasSecureMemoryWipe then
    WriteLn('Securely wipes sensitive data from memory');

  // 计算安全评分
  WriteLn('Security Score: ', GetSecurityScore(Caps), '/100');
end;
```

### 6. 性能特性查询

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 性能特性
  if Caps.HasHardwareAcceleration then
    WriteLn('Uses hardware acceleration (e.g., AES-NI)');

  if Caps.HasSIMDOptimization then
    WriteLn('Uses SIMD optimizations (e.g., SSE, AVX)');

  if Caps.HasAssemblyOptimization then
    WriteLn('Uses hand-optimized assembly code');

  // 计算性能评分
  WriteLn('Performance Score: ', GetPerformanceScore(Caps), '/100');
end;
```

### 7. 完整能力描述

```pascal
var
  Caps: TSSLBackendCapabilities;
  Desc: string;
begin
  Caps := Lib.GetCapabilities;

  // 生成完整描述
  Desc := GetCapabilitiesDescription(Caps);
  WriteLn(Desc);

  // 输出示例:
  // Backend: OpenSSL
  // Version: OpenSSL 3.5.4 30 Sep 2025
  // Implementation: C Library Binding
  // TLS Versions: TLS 1.0 - TLS 1.3
  // DTLS: Supported
  // Dependencies: External library required
  // Platform Features:
  //   - PKCS#11 hardware tokens
  // Security Score: 90/100
  // Performance Score: 100/100
end;
```

---

## 最佳实践

### 1. 条件功能使用

```pascal
procedure ConfigureConnection(Conn: ISSLConnection);
var
  Caps: TSSLBackendCapabilities;
  ConnInfo: ISSLConnectionInfo;
  ClientConn: ISSLClientConnection;
begin
  if not Supports(Conn, ISSLConnectionInfo, ConnInfo) then
    Exit;

  Caps := ConnInfo.GetContext.GetLibrary.GetCapabilities;

  // 只在支持时启用 ALPN
  if IsFeatureStable(Caps.ALPNSupport) then
  begin
    Conn.SetALPNProtocols(['h2', 'http/1.1']);
    WriteLn('ALPN configured');
  end;

  // 只在支持时启用 SNI
  if IsFeatureStable(Caps.SNISupport) and
     Supports(Conn, ISSLClientConnection, ClientConn) then
  begin
    ClientConn.SetServerName('example.com');
    WriteLn('SNI configured');
  end;
end;
```

### 2. 算法协商

```pascal
function SelectBestCipher(const ACaps: TSSLBackendCapabilities): TSSLCipher;
const
  PreferredCiphers: array[0..3] of TSSLCipher = (
    sslCipherCHACHA20_POLY1305,  // 首选：现代、快速
    sslCipherAES256GCM,          // 次选：AES-GCM 256
    sslCipherAES128GCM,          // 备选：AES-GCM 128
    sslCipherAES256              // 后备：AES-CBC 256
  );
var
  I: Integer;
begin
  for I := Low(PreferredCiphers) to High(PreferredCiphers) do
  begin
    if IsCipherSupported(ACaps, PreferredCiphers[I]) then
      Exit(PreferredCiphers[I]);
  end;

  raise Exception.Create('No suitable cipher found');
end;
```

### 3. 智能后端选择

```pascal
function SelectBackendForUseCase(const AUseCase: string): TSSLLibraryType;
var
  Caps: TSSLBackendCapabilities;
begin
  case AUseCase of
    'windows-desktop':
    begin
      // Windows 桌面：优先使用 WinSSL（系统集成）
      Caps := TSSLFactory.GetLibraryInstance(sslWinSSL).GetCapabilities;
      if Caps.SupportsSystemCertStore and (not Caps.RequiresExternalLibrary) then
        Exit(sslWinSSL);
    end;

    'pascal-first':
    begin
      // Pascal-first / 零外部 SSL 动态库：优先使用 FreePascal backend
      Caps := TSSLFactory.GetLibraryInstance(sslFreePascal).GetCapabilities;
      if not Caps.RequiresExternalLibrary then
        Exit(sslFreePascal);
    end;

    'feature-complete':
    begin
      // 功能完整度优先：优先使用 OpenSSL
      Caps := TSSLFactory.GetLibraryInstance(sslOpenSSL).GetCapabilities;
      if Caps.SupportsTLS13 and
         IsFeatureStable(Caps.ALPNSupport) and
         IsFeatureStable(Caps.SNISupport) then
        Exit(sslOpenSSL);
    end;
  end;

  // 默认：交回工厂按当前注册优先级与可用性选择
  Result := TSSLFactory.DetectBestLibrary;
end;
```

### 4. 验证后端要求

```pascal
function ValidateBackendRequirements(ABackend: TSSLLibraryType): Boolean;
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := TSSLFactory.GetLibraryInstance(ABackend).GetCapabilities;

  // 检查必需特性
  Result := Caps.SupportsTLS13 and
            IsFeatureStable(Caps.ALPNSupport) and
            IsFeatureStable(Caps.SNISupport) and
            IsCipherSupported(Caps, sslCipherAES256GCM) and
            IsHashSupported(Caps, sslHashSHA256);

  if not Result then
  begin
    WriteLn('Backend does not meet minimum requirements:');
    WriteLn('  TLS 1.3: ', Caps.SupportsTLS13);
    WriteLn('  ALPN: ', IsFeatureStable(Caps.ALPNSupport));
    WriteLn('  SNI: ', IsFeatureStable(Caps.SNISupport));
    WriteLn('  AES-256-GCM: ', IsCipherSupported(Caps, sslCipherAES256GCM));
  end;
end;
```

---

## 实战示例

### 示例1: 后端对比工具

```pascal
program backend_compare;

uses
  SysUtils, fafafa.ssl;

procedure CompareBackends;
var
  AvailableBackends: TSSLLibraryTypes;
  Backend: TSSLLibraryType;
  Lib: ISSLLibrary;
  Caps: TSSLBackendCapabilities;
begin
  WriteLn('Backend Comparison:');
  WriteLn('==========================================');

  AvailableBackends := TSSLFactory.GetAvailableLibraries;

  for Backend := Low(TSSLLibraryType) to High(TSSLLibraryType) do
  begin
    if not (Backend in AvailableBackends) then
      Continue;

    try
      Lib := TSSLFactory.GetLibraryInstance(Backend);
      if not Assigned(Lib) then
      begin
        WriteLn(LibraryTypeToString(Backend), ': Not available');
        Continue;
      end;

      Caps := Lib.GetCapabilities;

      WriteLn;
      WriteLn('Backend: ', LibraryTypeToString(Caps.BackendType));
      WriteLn('Version: ', Caps.BackendVersion);
      WriteLn('Security Score: ', GetSecurityScore(Caps), '/100');
      WriteLn('Performance Score: ', GetPerformanceScore(Caps), '/100');
      WriteLn('TLS 1.3: ', Caps.SupportsTLS13);
      WriteLn('DTLS: ', Caps.SupportsDTLS);
      WriteLn('Hardware Accel: ', Caps.HasHardwareAcceleration);
      WriteLn('System Certs: ', Caps.SupportsSystemCertStore);
    except
      on E: Exception do
        WriteLn(LibraryTypeToString(Backend), ': Error - ', E.Message);
    end;
  end;
end;

begin
  try
    CompareBackends;
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
end.
```

### 示例2: 智能配置生成器

```pascal
procedure GenerateOptimalConfig(ABackend: TSSLLibraryType);
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := TSSLFactory.GetLibraryInstance(ABackend).GetCapabilities;

  WriteLn('Optimal Configuration for ', LibraryTypeToString(ABackend));
  WriteLn('==========================================');

  // TLS 版本
  WriteLn('TLS Versions:');
  Write('  Minimum: ');
  case Caps.MinTLSVersion of
    sslProtocolTLS10: WriteLn('TLS 1.0 (consider upgrading to TLS 1.2+)');
    sslProtocolTLS11: WriteLn('TLS 1.1 (consider upgrading to TLS 1.2+)');
    sslProtocolTLS12: WriteLn('TLS 1.2 (good)');
    sslProtocolTLS13: WriteLn('TLS 1.3 (excellent)');
  end;
  WriteLn('  Maximum: TLS ', Ord(Caps.MaxTLSVersion) - Ord(sslProtocolTLS10) + 1, '.',
          (Ord(Caps.MaxTLSVersion) - Ord(sslProtocolTLS10)) mod 10);

  // 推荐的密码套件
  WriteLn;
  WriteLn('Recommended Ciphers:');
  if IsCipherSupported(Caps, sslCipherCHACHA20_POLY1305) then
    WriteLn('  - TLS_CHACHA20_POLY1305_SHA256 (modern, fast)');
  if IsCipherSupported(Caps, sslCipherAES256GCM) then
    WriteLn('  - TLS_AES_256_GCM_SHA384 (strong)');
  if IsCipherSupported(Caps, sslCipherAES128GCM) then
    WriteLn('  - TLS_AES_128_GCM_SHA256 (fast)');

  // 平台建议
  WriteLn;
  WriteLn('Platform Recommendations:');
  if Caps.SupportsSystemCertStore then
    WriteLn('  ✓ Enable system certificate store');
  if Caps.SupportsPKCS11 then
    WriteLn('  ✓ Consider PKCS#11 hardware tokens for key storage');
  if Caps.HasHardwareAcceleration then
    WriteLn('  ✓ Hardware acceleration is available');

  // 安全建议
  WriteLn;
  WriteLn('Security Recommendations:');
  if Caps.HasConstantTimeOperations then
    WriteLn('  ✓ Timing attack protection is enabled');
  if Caps.SupportsFIPSMode then
    WriteLn('  ✓ Consider FIPS mode for compliance');
  if GetSecurityScore(Caps) < 80 then
    WriteLn('  ⚠ Security score is below 80, consider alternatives');
end;
```

### 示例3: 运行时能力检查

```pascal
function InitializeSSL(out ALib: ISSLLibrary;
                       out AContext: ISSLContext): Boolean;
var
  AvailableBackends: TSSLLibraryTypes;
  Backend: TSSLLibraryType;
  Caps: TSSLBackendCapabilities;
begin
  Result := False;

  // 读取当前真正可用的 backend 集合（会自动覆盖 sslFreePascal / optional backends）
  AvailableBackends := TSSLFactory.GetAvailableLibraries;

  for Backend := Low(TSSLLibraryType) to High(TSSLLibraryType) do
  begin
    if not (Backend in AvailableBackends) then
      Continue;

    try
      WriteLn('Trying backend: ', LibraryTypeToString(Backend));

      ALib := TSSLFactory.GetLibraryInstance(Backend);
      if not Assigned(ALib) then
      begin
        WriteLn('  Not available');
        Continue;
      end;

      // 检查能力
      Caps := ALib.GetCapabilities;

      // 验证最低要求
      if not Caps.SupportsTLS13 then
      begin
        WriteLn('  TLS 1.3 not supported, skipping');
        Continue;
      end;

      if not IsCipherSupported(Caps, sslCipherAES256GCM) then
      begin
        WriteLn('  AES-256-GCM not supported, skipping');
        Continue;
      end;

      // 创建上下文
      AContext := ALib.CreateContext(sslCtxClient);
      WriteLn('  Successfully initialized');
      WriteLn('  Security Score: ', GetSecurityScore(Caps), '/100');
      WriteLn('  Performance Score: ', GetPerformanceScore(Caps), '/100');

      Result := True;
      Exit;
    except
      on E: Exception do
        WriteLn('  Error: ', E.Message);
    end;
  end;

  if not Result then
    WriteLn('Failed to initialize any SSL backend');
end;
```

---

## 常见问题

### Q1: 能力矩阵是否有运行时开销？

**A**: 几乎没有。`GetCapabilities()` 返回的是静态信息（编译时或初始化时确定），查询辅助函数的开销极小（<1ns 到 ~1μs）。

### Q2: 如何判断后端是否支持某个特定的密码套件组合？

**A**: 使用集合运算：

```pascal
const
  RequiredCiphers: TSSLCipherSupport =
    [sslCipherAES256GCM, sslCipherCHACHA20_POLY1305];
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  // 检查是否支持所有必需的密码
  if RequiredCiphers <= Caps.SupportedCiphers then
    WriteLn('All required ciphers are supported')
  else
    WriteLn('Some required ciphers are missing');
end;
```

### Q3: GetSecurityScore 和 GetPerformanceScore 的评分标准是什么？

**A**: 评分基于多个因素：

**安全评分 (0-100)**:
- TLS 1.3 支持: +20
- 恒定时间操作: +20
- FIPS 模式: +15
- 安全内存擦除: +15
- 现代算法支持: +30

**性能评分 (0-100)**:
- 硬件加速: +40
- SIMD 优化: +30
- 汇编优化: +30

### Q4: 不同后端的 CompatibilityLevel 是如何计算的？

**A**: CompatibilityLevel (0-100) 表示当前 backend 相对 OpenSSL public surface 的兼容程度。当前 shipped 值示例：
- **OpenSSL**: 100% (基准)
- **WinSSL**: 90% (大部分功能兼容)
- **WolfSSL**: 85% (部分功能需要配置)
- **MbedTLS**: 75% (针对嵌入式，功能精简)
- **FreePascal**: 64% (Pascal-first / pure TLS core path)

真正做决策时，请优先读取运行时 `Caps.CompatibilityLevel`，不要把这些数字当成永远不变的固定 truth。

### Q5: 如何处理后端的 KnownIssues？

**A**: `KnownIssues` 字段包含后端的已知限制：

```pascal
var
  Caps: TSSLBackendCapabilities;
begin
  Caps := Lib.GetCapabilities;

  if Caps.KnownIssues <> '' then
  begin
    WriteLn('Known Issues:');
    WriteLn(Caps.KnownIssues);
    WriteLn;
    WriteLn('Do you want to continue? (y/n)');
    // ... 处理用户确认
  end;
end;
```

### Q6: 能力矩阵会自动更新吗（如库升级后）？

**A**: 能力矩阵在库初始化时生成，反映当前已加载库的版本。如果库文件升级（如 OpenSSL 1.1 → 3.0），重新初始化库即可获取更新的能力矩阵。

### Q7: 如何为新后端实现能力矩阵？

**A**: 在您的后端库类中实现 `GetCapabilities()` 方法：

```pascal
function TMyBackend.GetCapabilities: TSSLBackendCapabilities;
begin
  FillChar(Result, SizeOf(Result), 0);

  // 独立布尔真相
  Result.SupportsTLS13 := True;

  // paired feature 优先写 support-level 真相
  Result.SNISupport := sslSupportStable;
  Result.ALPNSupport := sslSupportStable;
  Result.OCSPStaplingSupport := sslSupportExperimental;

  // v1.2.0 字段
  Result.BackendType := sslMyBackend;
  Result.BackendImplType := sslImplNative;  // 或其他类型
  Result.BackendVersion := '1.0.0';

  // 用 support-level 真相回填 legacy boolean 兼容视图
  NormalizeLegacyCapabilityBooleans(Result);
end;
```

参考现有后端的实现（`src/fafafa.ssl.openssl.backed.pas` 等）。

---

## 相关文档

- **API 参考**: `docs/reference/API_REFERENCE.md` - 完整 API 文档
- **迁移指南**: `docs/guides/MIGRATION_GUIDE.md` - 当前迁移主线
- **原生句柄指南**: `docs/NATIVE_HANDLE_QUICK_REF.md` - 原生句柄使用
- **架构文档**: `docs/ARCHITECTURE.md` - 架构设计

---

## 反馈与支持

如有问题或建议，请：
- 提交 Issue: https://github.com/dtamade/fafafa.ssl/issues
- 查看示例: `examples/` 目录
- 查看测试: `tests/test_capability_matrix_*.pas`

---

**文档版本**: v1.5.0
**最后更新**: 2026-05-21
**作者**: fafafa.ssl 团队
