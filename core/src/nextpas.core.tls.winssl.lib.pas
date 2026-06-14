{
  nextpas.core.tls.winssl.library - WinSSL 库管理实现
  
  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-10-06
  
  描述:
    实现 ISSLLibrary 接口的 WinSSL 后端。
    负责 Windows Schannel 的初始化、配置和上下文创建。
}

unit nextpas.core.tls.winssl.lib;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses Windows, SysUtils, nextpas.core.tls.base, nextpas.core.tls.exceptions, // nextpas.core.tls.factory 移到 implementation 以避免循环依赖 nextpas.core.tls.winssl.base, nextpas.core.tls.winssl.api, nextpas.core.tls.winssl.utils;

type
  { TWinSSLLibrary - Windows Schannel 库管理类 }
  TWinSSLLibrary = class(TInterfacedObject, ISSLLibrary, IWinSSLLibraryStatsAccess)
  private
    FInitialized: Boolean;
    FDefaultConfig: TSSLConfig;
    FStatistics: TSSLStatistics;
    FLastError: Integer;
    FLastErrorString: string;
    FLogCallback: TSSLLogCallback;
    FLogLevel: TSSLLogLevel;
    FWindowsVersion: record
      Major: DWORD;
      Minor: DWORD;
      Build: DWORD;
      IsServer: Boolean;
    end;

    // Phase 3.3: 线程安全的统计更新
    FStatisticsLock: TRTLCriticalSection;

    { v1.2.0: 能力矩阵缓存 }
    FCapabilitiesCached: Boolean;
    FCapabilitiesCache: TSSLBackendCapabilities;

    { 内部方法 }
    procedure InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
    function DetectWindowsVersion: Boolean;
    function CheckSchannelSupport: Boolean;
    procedure SetError(AError: Integer; const AErrorMsg: string);
    procedure ClearInternalError;
    procedure InvalidateCapabilitiesCache;  // v1.2.0: 缓存失效

  public
    constructor Create;
    destructor Destroy; override;

    { ISSLLibrary - 初始化和清理 }
    function Initialize: Boolean;
    procedure Finalize;
    function IsInitialized: Boolean;
    
    { ISSLLibrary - 版本信息 }
    function GetLibraryType: TSSLLibraryType;
    function GetVersionString: string;
    function GetVersionNumber: Cardinal;
    function GetCompileFlags: string;
    
    { ISSLLibrary - 功能支持查询 }
    function IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
    function IsCipherSupported(const ACipherName: string): Boolean;
    function IsFeatureSupported(AFeature: TSSLFeature): Boolean;
    function GetCapabilities: TSSLBackendCapabilities;  // P2-2

    { ISSLLibrary - 库配置 }
    procedure SetDefaultConfig(const AConfig: TSSLConfig);
    function GetDefaultConfig: TSSLConfig;
    
    { ISSLLibrary - 错误处理 }
    function GetLastError: Integer;
    function GetLastErrorString: string;
    procedure ClearError;
    
    { ISSLLibrary - 统计信息 }
    function GetStatistics: TSSLStatistics;
    procedure ResetStatistics;
    
    { ISSLLibrary - 日志 }
    procedure SetLogCallback(ACallback: TSSLLogCallback);
    procedure Log(ALevel: TSSLLogLevel; const AMessage: string);
    
    { ISSLLibrary - 工厂方法 }
    function CreateContext(AType: TSSLContextType): ISSLContext;
    function CreateCertificate: ISSLCertificate;
    function CreateCertificateStore: ISSLCertificateStore;

    { Phase 3.3: 公共统计更新方法 }
    procedure UpdateHandshakeStatistics(AHandshakeDuration: Integer; ASuccess: Boolean);
    procedure UpdateSessionStatistics(ASessionReused: Boolean);
  end;

{ 全局工厂函数 }
function CreateWinSSLLibrary: ISSLLibrary;

{ 后端注册函数 - 供 nextpas.core.tls.winssl.autoregister 使用 }
procedure RegisterWinSSLBackend;
procedure UnregisterWinSSLBackend;

implementation

uses nextpas.core.tls.winssl.context, nextpas.core.tls.winssl.certificate, nextpas.core.tls.winssl.certstore, nextpas.core.tls.context.config, nextpas.core.tls.errors, // P0 后端语义统一：引入统一的错误抛出函数 nextpas.core.tls.factory; // 在 implementation 中导入以调用 RegisterLibrary;

// ============================================================================
// 全局工厂函数
// ============================================================================

function CreateWinSSLLibrary: ISSLLibrary;
begin
  Result := TWinSSLLibrary.Create;
end;

// ============================================================================
// TWinSSLLibrary - 构造和析构
// ============================================================================

constructor TWinSSLLibrary.Create;
begin
  inherited Create;
  FInitialized := False;
  FLastError := 0;
  FLastErrorString := '';
  FLogCallback := nil;
  FLogLevel := sslLogError;
  
  // 初始化默认配置
  FillChar(FDefaultConfig, SizeOf(FDefaultConfig), 0);
  with FDefaultConfig do
  begin
    LibraryType := sslWinSSL;
    ContextType := sslCtxClient;
    ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
    PreferredVersion := sslProtocolTLS13;
    VerifyMode := [sslVerifyPeer];
    VerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
    CipherList := '';  // 使用 Windows 默认
    CipherSuites := ''; // 使用 Windows 默认
    Options := [ssoEnableSNI, ssoEnableALPN];
    BufferSize := SSL_DEFAULT_BUFFER_SIZE;
    HandshakeTimeout := SSL_DEFAULT_HANDSHAKE_TIMEOUT;
    SessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;
    SessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
    ServerName := '';
    ALPNProtocols := '';
    EnableCompression := False;
    EnableSessionTickets := True;
    EnableOCSPStapling := False;
    LogLevel := sslLogError;
    LogCallback := nil;
  end;

  TSSLFactory.NormalizeConfig(FDefaultConfig);
  
  // 初始化统计信息
  FillChar(FStatistics, SizeOf(FStatistics), 0);

  // Phase 3.3: 初始化统计锁
  InitializeCriticalSection(FStatisticsLock);

  // 初始化 Windows 版本信息
  FillChar(FWindowsVersion, SizeOf(FWindowsVersion), 0);

  { v1.2.0: 初始化能力矩阵缓存 }
  FCapabilitiesCached := False;
  FillChar(FCapabilitiesCache, SizeOf(FCapabilitiesCache), 0);
end;


destructor TWinSSLLibrary.Destroy;
begin
  if FInitialized then
    Finalize;

  // Phase 3.3: 清理统计锁
  DeleteCriticalSection(FStatisticsLock);

  inherited Destroy;
end;

// ============================================================================
// 内部方法实现
// ============================================================================

procedure TWinSSLLibrary.InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  if Assigned(FLogCallback) and (ALevel <= FLogLevel) then
    FLogCallback(ALevel, AMessage);
end;

function TWinSSLLibrary.DetectWindowsVersion: Boolean;
var
  VersionInfo: OSVERSIONINFO;
begin
  Result := False;
  FillChar(VersionInfo, SizeOf(VersionInfo), 0);
  VersionInfo.dwOSVersionInfoSize := SizeOf(OSVERSIONINFO);
  
  if GetVersionEx(VersionInfo) then
  begin
    FWindowsVersion.Major := VersionInfo.dwMajorVersion;
    FWindowsVersion.Minor := VersionInfo.dwMinorVersion;
    FWindowsVersion.Build := VersionInfo.dwBuildNumber and $FFFF;
    FWindowsVersion.IsServer := False; // Simplified: can't detect with basic OSVERSIONINFO
    Result := True;
    
    InternalLog(sslLogInfo, Format('Windows version detected: %d.%d Build %d (%s)',
      [FWindowsVersion.Major, FWindowsVersion.Minor, FWindowsVersion.Build,
      'Workstation'])); // Simplified log
  end
  else
  begin
    SetError(GetLastError, 'Failed to detect Windows version');
    InternalLog(sslLogError, 'Failed to detect Windows version');
  end;
end;

function TWinSSLLibrary.CheckSchannelSupport: Boolean;
var
  CredHandle: TSecHandle;
  TimeStamp: TTimeStamp;
  Status: SECURITY_STATUS;
  SchannelCred: SCHANNEL_CRED;
begin
  Result := False;
  
  // 尝试获取一个简单的 Schannel 凭据
  FillChar(SchannelCred, SizeOf(SchannelCred), 0);
  SchannelCred.dwVersion := SCHANNEL_CRED_VERSION;
  SchannelCred.dwFlags := SCH_CRED_NO_DEFAULT_CREDS or SCH_CRED_MANUAL_CRED_VALIDATION;
  
  InitSecHandle(CredHandle);
  
  Status := AcquireCredentialsHandleW(
    nil,
    PWideChar(WideString('Microsoft Unified Security Protocol Provider')),
    SECPKG_CRED_OUTBOUND,
    nil,
    @SchannelCred,
    nil,
    nil,
    @CredHandle,
    @TimeStamp
  );
  
  if IsSuccess(Status) then
  begin
    Result := True;
    FreeCredentialsHandle(@CredHandle);
    InternalLog(sslLogInfo, 'Schannel support verified');
  end
  else
  begin
    SetError(Status, Format('Schannel not available: %s', 
      [GetSchannelErrorString(Status)]));
    InternalLog(sslLogError, Format('Schannel support check failed: %s',
      [GetSchannelErrorString(Status)]));
  end;
end;

procedure TWinSSLLibrary.SetError(AError: Integer; const AErrorMsg: string);
begin
  FLastError := AError;
  FLastErrorString := AErrorMsg;
end;

procedure TWinSSLLibrary.ClearInternalError;
begin
  FLastError := 0;
  FLastErrorString := '';
end;

// ============================================================================
// ISSLLibrary - 初始化和清理
// ============================================================================

function TWinSSLLibrary.Initialize: Boolean;
begin
  Result := False;
  
  if FInitialized then
  begin
    InternalLog(sslLogWarning, 'WinSSL library already initialized');
    Exit(True);
  end;
  
  InternalLog(sslLogInfo, 'Initializing WinSSL library...');
  ClearInternalError;
  
  // 检测 Windows 版本
  if not DetectWindowsVersion then
    Exit(False);
    
  // 检查 Windows 版本是否支持 Schannel
  // Windows Vista (6.0) 及以上支持 Schannel
  if (FWindowsVersion.Major < 6) then
  begin
    SetError(-1, 'Windows version too old. Schannel requires Windows Vista or later.');
    InternalLog(sslLogError, FLastErrorString);
    Exit(False);
  end;
  
  // 检查 Schannel 支持
  if not CheckSchannelSupport then
    Exit(False);
  
  FInitialized := True;
  InternalLog(sslLogInfo, 'WinSSL library initialized successfully');
  Result := True;
end;

procedure TWinSSLLibrary.Finalize;
begin
  if not FInitialized then
    Exit;
    
  
  { v1.2.0: 使缓存失效 }
  InvalidateCapabilitiesCache;
  InternalLog(sslLogInfo, 'Finalizing WinSSL library...');
  
  // WinSSL 不需要特殊的清理操作
  // Schannel 是 Windows 系统组件，由操作系统管理
  
  FInitialized := False;
  InternalLog(sslLogInfo, 'WinSSL library finalized');
end;

function TWinSSLLibrary.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

// ============================================================================
// ISSLLibrary - 版本信息
// ============================================================================

function TWinSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslWinSSL;
end;

function TWinSSLLibrary.GetVersionString: string;
begin
  // Windows Schannel 版本与 Windows 版本对应
  if FInitialized then
    Result := Format('Windows Schannel %d.%d (Build %d)',
      [FWindowsVersion.Major, FWindowsVersion.Minor, FWindowsVersion.Build])
  else
    Result := 'Windows Schannel (not initialized)';
end;

function TWinSSLLibrary.GetVersionNumber: Cardinal;
begin
  // 返回 Windows 版本号
  // 格式: Major.Minor.Build -> 转换为 Cardinal
  if FInitialized then
    Result := (FWindowsVersion.Major shl 16) or FWindowsVersion.Minor
  else
    Result := 0;
end;

function TWinSSLLibrary.GetCompileFlags: string;
begin
  // Schannel 编译标志由 Windows 系统决定
  Result := 'Native Windows Schannel';
  {$IFDEF CPU64}
  Result := Result + ', x64';
  {$ELSE}
  Result := Result + ', x86';
  {$ENDIF}
  {$IFDEF DEBUG}
  Result := Result + ', Debug';
  {$ELSE}
  Result := Result + ', Release';
  {$ENDIF}
end;

// ============================================================================
// ISSLLibrary - 功能支持查询
// ============================================================================

function TWinSSLLibrary.IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := False;
  
  if not FInitialized then
    Exit;
  
  // Windows 版本与 TLS 支持对应关系
  case AProtocol of
    sslProtocolSSL2,
    sslProtocolSSL3:
      Result := False;  // SSL 2.0/3.0 已废弃
      
    sslProtocolTLS10:
      Result := (FWindowsVersion.Major >= 6);  // Vista+
      
    sslProtocolTLS11:
      Result := (FWindowsVersion.Major > 6) or 
                ((FWindowsVersion.Major = 6) and (FWindowsVersion.Minor >= 1));  // Win 7+
      
    sslProtocolTLS12:
      Result := (FWindowsVersion.Major > 6) or
                ((FWindowsVersion.Major = 6) and (FWindowsVersion.Minor >= 1));  // Win 7+
      
    sslProtocolTLS13:
      // TLS 1.3 在 Windows 10 Build 18362+ / Windows 11+ 支持
      Result := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 18362);
      
    sslProtocolDTLS10,
    sslProtocolDTLS12:
      Result := False;  // Schannel 不直接支持 DTLS
  end;
end;

function TWinSSLLibrary.IsCipherSupported(const ACipherName: string): Boolean;
var
  LCipher: string;
  LSupportsChaCha: Boolean;
begin
  if not FInitialized then
    Exit(False);

  LCipher := UpperCase(Trim(ACipherName));
  if LCipher = '' then
    Exit(False);

  Result :=
    (LCipher = 'TLS_AES_128_GCM_SHA256') or
    (LCipher = 'TLS_AES_256_GCM_SHA384') or
    (LCipher = 'AES128') or
    (LCipher = 'AES256') or
    (LCipher = 'AES128-GCM') or
    (LCipher = 'AES256-GCM') or
    (LCipher = 'AES128_GCM') or
    (LCipher = 'AES256_GCM');

  LSupportsChaCha := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 18362);
  if (not Result) and LSupportsChaCha then
    Result :=
      (LCipher = 'TLS_CHACHA20_POLY1305_SHA256') or
      (LCipher = 'CHACHA20_POLY1305') or
      (LCipher = 'CHACHA20-POLY1305');

  InternalLog(sslLogDebug, Format('Cipher support check: %s = %s', [
    ACipherName, BoolToStr(Result, True)
  ]));
end;

{ 类型安全版本（Phase 1.3 - Rust质量标准） }
function TWinSSLLibrary.IsFeatureSupported(AFeature: TSSLFeature): Boolean;
begin
  case AFeature of
    sslFeatSNI:
      Result := True;  // Windows Schannel原生支持SNI
    sslFeatALPN:
      // ALPN需要Windows 8+或Windows 10+
      Result := (FWindowsVersion.Major >= 10) or
                ((FWindowsVersion.Major = 6) and (FWindowsVersion.Minor >= 2));
    sslFeatSessionCache:
      Result := True;  // Windows Schannel原生支持会话缓存
    sslFeatSessionTickets:
      Result := True;  // Windows Schannel原生支持会话票据
    sslFeatRenegotiation:
      Result := False;  // P0-5: Windows Schannel 不完全支持 TLS 重协商，实际会抛异常
    sslFeatOCSPStapling:
      Result := False;  // 需要手动实现OCSP装订
    sslFeatCertificateTransparency:
      Result := False;  // Windows Schannel不原生支持证书透明度
  else
    Result := False;
  end;

  InternalLog(sslLogDebug, Format('Feature support check (type-safe): %d = %s',
    [Ord(AFeature), BoolToStr(Result, True)]));
end;

function TWinSSLLibrary.GetCapabilities: TSSLBackendCapabilities;
var
  LALPNReady: Boolean;
begin
  { v1.2.0: 如果已缓存，直接返回缓存值 }
  if FCapabilitiesCached then
  begin
    Result := FCapabilitiesCache;
    Exit;
  end;

  // P2-2: 返回 WinSSL (Schannel) 后端能力矩阵
  FillChar(Result, SizeOf(Result), 0);

  // v1.1.0 字段（向后兼容）
  // TLS 1.3 支持需要 Windows 10 版本 1903+ 或 Windows Server 2022+
  Result.SupportsTLS13 := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 18362);

  // ALPN 需要 Windows 8+ (版本 6.2+) 或 Windows 10+
  LALPNReady := (FWindowsVersion.Major >= 10) or
    ((FWindowsVersion.Major = 6) and (FWindowsVersion.Minor >= 2));

  // ECDHE 需要 Windows Vista+ (版本 6.0+)
  Result.SupportsECDHE := (FWindowsVersion.Major >= 6);

  // ChaCha20-Poly1305 需要 Windows 10 版本 1903+
  Result.SupportsChaChaPoly := (FWindowsVersion.Major >= 10) and (FWindowsVersion.Build >= 18362);

  // WinSSL/Schannel 当前只发布 PKCS#12/PFX bundle import path；
  // bare PEM/DER private-key loading is not a shipped public capability.
  Result.SupportsPEMPrivateKey := False;

  // 支持的协议版本范围
  Result.MinTLSVersion := sslProtocolTLS10;  // Windows Vista+
  if Result.SupportsTLS13 then
    Result.MaxTLSVersion := sslProtocolTLS13
  else
    Result.MaxTLSVersion := sslProtocolTLS12;

  // v1.2.0 新增字段
  Result.BackendType := sslWinSSL;
  Result.BackendImplType := sslImplOSNative;  // WinSSL 使用操作系统原生 API
  Result.BackendVersion := Format('Windows %d.%d.%d',
    [FWindowsVersion.Major, FWindowsVersion.Minor, FWindowsVersion.Build]);
  Result.SupportsDTLS := False;  // Schannel 不支持 DTLS

  // 功能支持级别
  Result.SNISupport := sslSupportStable;
  if LALPNReady then
    Result.ALPNSupport := sslSupportStable
  else
    Result.ALPNSupport := sslSupportNone;
  Result.OCSPStaplingSupport := sslSupportNone;
  Result.CertTransparencySupport := sslSupportNone;
  Result.SessionTicketsSupport := sslSupportExperimental;
  // `SessionCacheSupport` 在 WinSSL 上当前表示 context-level cache/control
  // surface 已发布且已接线，不等于已 runtime-proven 的 resumed handshake。
  Result.SessionCacheSupport := sslSupportStable;
  Result.ZeroRTTSupport := sslSupportNone;
  Result.EarlyDataSupport := sslSupportNone;
  Result.RenegotiationSupport := sslSupportNone;
  Result.PostHandshakeAuthSupport := sslSupportNone;

  // 密码算法支持（Schannel 由系统决定）
  Result.SupportedCiphers := [
    sslCipherAES128, sslCipherAES256, sslCipherAES128GCM, sslCipherAES256GCM
  ];
  if Result.SupportsChaChaPoly then
    Result.SupportedCiphers := Result.SupportedCiphers + [sslCipherCHACHA20_POLY1305];

  // 哈希算法支持
  Result.SupportedHashes := [
    sslHashSHA1, sslHashSHA256, sslHashSHA384, sslHashSHA512
  ];

  // 密钥交换算法支持
  Result.SupportedKeyExchanges := [
    sslKexRSA, sslKexDHE_RSA
  ];
  if Result.SupportsECDHE then
  begin
    Result.SupportedKeyExchanges := Result.SupportedKeyExchanges +
      [sslKexECDHE_RSA, sslKexECDHE_ECDSA];
  end;

  // 性能特性（Schannel 高度优化）
  Result.HasHardwareAcceleration := True;  // 使用系统硬件加速
  Result.HasSIMDOptimization := True;      // 系统级 SIMD
  Result.HasAssemblyOptimization := True;  // 系统级汇编优化

  // 平台特性
  Result.RequiresExternalLibrary := False;  // Schannel 是系统内置
  Result.SupportsSystemCertStore := True;   // WinSSL 的核心优势
  Result.SupportsPKCS11 := False;           // current WinSSL backend does not publish a PKCS#11 loading/runtime path
  Result.SupportsTPM := False;              // platform potential is not a shipped TPM public capability

  // 安全特性
  Result.HasConstantTimeOperations := True;  // 系统级实现
  Result.SupportsFIPSMode := False;          // current WinSSL surface only exposes Windows FIPS policy/helper detection, not a published backend capability
  Result.HasSecureMemoryWipe := True;        // CNG 提供

  // 证书和密钥格式支持（WinSSL 偏好 Windows 格式）
  Result.SupportsDERPrivateKey := False;     // no shipped bare DER private-key load path
  Result.SupportsPKCS8PrivateKey := False;   // no shipped bare PKCS#8 private-key load path
  Result.SupportsPKCS12 := True;             // current published private-key path is PKCS#12/PFX import
  Result.SupportsPasswordProtectedKeys := True;  // current published path is password-protected PFX/P12 import; PEM private-key password path remains unsupported

  // 扩展性
  Result.SupportsCustomCipherSuites := False;  // current WinSSL runtime follows Schannel/system policy and does not publish custom non-default cipher overrides
  Result.SupportsCallbacks := True;  // verify/info callback runtime paths are consumed by the WinSSL connection layer

  // 兼容性（WinSSL 行为依赖 Windows 版本）
  Result.CompatibilityLevel := 90;  // 90% 兼容性
  Result.KnownIssues :=
    'Feature availability depends on Windows version; session resumption / session tickets remain experimental ' +
    'in fafafa.ssl WinSSL runtime proof (current dedicated Windows CI recorded observed_reuse=false with session_configured=true); ' +
    'does not support PEM private keys directly';

  NormalizeLegacyCapabilityBooleans(Result);

  InternalLog(sslLogDebug, Format('GetCapabilities: TLS1.3=%s, ALPN=%s, SNI=%s (Win %d.%d.%d)',
    [
      BoolToStr(Result.SupportsTLS13, True),
      BoolToStr(Result.SupportsALPN, True),
      BoolToStr(Result.SupportsSNI, True),
      FWindowsVersion.Major,
      FWindowsVersion.Minor,
      FWindowsVersion.Build
    ]));
  
  { v1.2.0: 缓存能力矩阵 }
  FCapabilitiesCache := Result;
  FCapabilitiesCached := True;
end;

// ============================================================================
// ISSLLibrary - 库配置
// ============================================================================

procedure TWinSSLLibrary.SetDefaultConfig(const AConfig: TSSLConfig);
var
  LConfig: TSSLConfig;
begin
  LConfig := AConfig;
  TSSLFactory.NormalizeConfig(LConfig);

  FLogLevel := LConfig.LogLevel;
  LConfig.LogCallback := FLogCallback;
  FDefaultConfig := LConfig;
  InternalLog(sslLogInfo, 'Default configuration updated');
end;

function TWinSSLLibrary.GetDefaultConfig: TSSLConfig;
begin
  Result := FDefaultConfig;
end;

// ============================================================================
// ISSLLibrary - 错误处理
// ============================================================================

function TWinSSLLibrary.GetLastError: Integer;
begin
  Result := FLastError;
end;

function TWinSSLLibrary.GetLastErrorString: string;
begin
  Result := FLastErrorString;
end;

procedure TWinSSLLibrary.ClearError;
begin
  ClearInternalError;
end;

// ============================================================================
// ISSLLibrary - 统计信息
// ============================================================================

function TWinSSLLibrary.GetStatistics: TSSLStatistics;
begin
  Result := FStatistics;
end;

procedure TWinSSLLibrary.ResetStatistics;
begin
  // Phase 3.3: 线程安全的统计重置
  EnterCriticalSection(FStatisticsLock);
  try
    FillChar(FStatistics, SizeOf(FStatistics), 0);
    // 初始化最小握手时间为最大值
    FStatistics.HandshakeTimeMin := High(Integer);
  finally
    LeaveCriticalSection(FStatisticsLock);
  end;
  InternalLog(sslLogInfo, 'Statistics reset');
end;

// ============================================================================
// Phase 3.3: 统计更新方法实现
// ============================================================================

procedure TWinSSLLibrary.UpdateHandshakeStatistics(AHandshakeDuration: Integer; ASuccess: Boolean);
begin
  EnterCriticalSection(FStatisticsLock);
  try
    if ASuccess then
    begin
      Inc(FStatistics.HandshakesSuccessful);

      // 更新握手时间统计
      Inc(FStatistics.HandshakeTimeTotal, AHandshakeDuration);

      // 更新最小握手时间
      if (FStatistics.HandshakeTimeMin = 0) or (AHandshakeDuration < FStatistics.HandshakeTimeMin) then
        FStatistics.HandshakeTimeMin := AHandshakeDuration;

      // 更新最大握手时间
      if AHandshakeDuration > FStatistics.HandshakeTimeMax then
        FStatistics.HandshakeTimeMax := AHandshakeDuration;

      // 计算平均握手时间
      if FStatistics.HandshakesSuccessful > 0 then
        FStatistics.HandshakeTimeAvg := Integer(FStatistics.HandshakeTimeTotal div FStatistics.HandshakesSuccessful);
    end
    else
      Inc(FStatistics.HandshakesFailed);
  finally
    LeaveCriticalSection(FStatisticsLock);
  end;
end;

procedure TWinSSLLibrary.UpdateSessionStatistics(ASessionReused: Boolean);
begin
  EnterCriticalSection(FStatisticsLock);
  try
    if ASessionReused then
    begin
      Inc(FStatistics.SessionsReused);
      Inc(FStatistics.SessionCacheHits);
    end
    else
    begin
      Inc(FStatistics.SessionsCreated);
      Inc(FStatistics.SessionCacheMisses);
    end;

    // 计算 Session 复用率（百分比）
    if (FStatistics.SessionsReused + FStatistics.SessionsCreated) > 0 then
      FStatistics.SessionReuseRate := (FStatistics.SessionsReused * 100.0) / (FStatistics.SessionsReused + FStatistics.SessionsCreated)
    else
      FStatistics.SessionReuseRate := 0.0;
  finally
    LeaveCriticalSection(FStatisticsLock);
  end;
end;

// ============================================================================
// ISSLLibrary - 日志
// ============================================================================

procedure TWinSSLLibrary.SetLogCallback(ACallback: TSSLLogCallback);
begin
  FLogCallback := ACallback;
  FDefaultConfig.LogCallback := ACallback;
end;

procedure TWinSSLLibrary.Log(ALevel: TSSLLogLevel; const AMessage: string);
begin
  InternalLog(ALevel, AMessage);
end;

// ============================================================================
// ISSLLibrary - 工厂方法
// ============================================================================

function TWinSSLLibrary.CreateContext(AType: TSSLContextType): ISSLContext;
var
  LConfig: TSSLConfig;
  LVerifyMode: TSSLVerifyModes;
  Store: ISSLCertificateStore;
begin
  // P0 后端语义统一：与 OpenSSL 后端保持一致的失败语义
  // 未初始化时抛出异常，而不是返回 nil
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create context: WinSSL library not initialized');

  LConfig := FDefaultConfig;
  LConfig.ContextType := AType;

  ValidateDirectLibraryConnectionScope(
    LConfig,
    'TWinSSLLibrary.CreateContext'
  );

  if (AType = sslCtxServer) and (Trim(LConfig.ServerName) <> '') then
    raise ESSLConfigurationException.CreateWithContext(
      'ServerName is client-scoped. Server-side connections ignore context-level ServerName; ' +
      'remove it from TWinSSLLibrary.CreateContext when creating server contexts.',
      sslErrConfiguration,
      'TWinSSLLibrary.CreateContext',
      0,
      sslWinSSL
    );

  ValidateContextReplayStoreConfigScope(
    LConfig,
    AType,
    'TWinSSLLibrary.CreateContext'
  );
  LVerifyMode := LConfig.VerifyMode;
  if (AType = sslCtxServer) and
    (LVerifyMode = [sslVerifyPeer]) and
    (Trim(LConfig.CAFile) = '') and
    (Trim(LConfig.CAPath) = '') and
    (not LConfig.UseSystemRoots) then
    LVerifyMode := [];

  // 让异常传播 - 调用方必须显式处理错误
  Result := TWinSSLContext.Create(Self, AType);

  if Result <> nil then
  begin
    if LConfig.ProtocolVersions <> [] then
      Result.SetProtocolVersions(LConfig.ProtocolVersions);

    if LConfig.PreferredVersion <> sslProtocolUnknown then
      Result.SetPreferredVersion(LConfig.PreferredVersion);

    Result.SetVerifyMode(LVerifyMode);

    if LConfig.VerifyDepth > 0 then
      Result.SetVerifyDepth(LConfig.VerifyDepth);

    if LConfig.CipherList <> '' then
      Result.SetCipherList(LConfig.CipherList);

    if LConfig.CipherSuites <> '' then
      Result.SetCipherSuites(LConfig.CipherSuites);

    Result.SetOptions(LConfig.Options);
    Result.SetSessionCacheSize(LConfig.SessionCacheSize);
    Result.SetSessionTimeout(LConfig.SessionTimeout);
    Result.SetSessionCacheMode(ssoEnableSessionCache in LConfig.Options);

    if LConfig.UseSystemRoots then
    begin
      Store := TSSLFactory.CreateCertificateStore(GetLibraryType);
      if Store <> nil then
      begin
        Store.LoadSystemStore;
        Result.SetCertificateStore(Store);
      end;
    end;

    if LConfig.CAFile <> '' then
      Result.LoadCAFile(LConfig.CAFile);

    if LConfig.CAPath <> '' then
      Result.LoadCAPath(LConfig.CAPath);

    if LConfig.ServerName <> '' then
      InternalLog(
        sslLogWarning,
        'TWinSSLLibrary.CreateContext received TSSLConfig.ServerName as deprecated context-level ' +
        'SNI compatibility; CreateContext ignores it for new contexts; prefer per-connection SNI via ' +
        'ISSLClientConnection.SetServerName or TSSLConnector.Connect*(..., ServerName).'
      );

    if LConfig.ALPNProtocols <> '' then
      Result.SetALPNProtocols(LConfig.ALPNProtocols);

    ApplyEarlyDataContextConfig(Result, LConfig);
    ApplyEarlyDataReplayStoreConfig(Result, LConfig,
      'TWinSSLLibrary.CreateContext');
  end;

  Inc(FStatistics.ConnectionsTotal);
  if AType = sslCtxClient then
    InternalLog(sslLogInfo, 'Created client context')
  else
    InternalLog(sslLogInfo, 'Created server context');
end;

function TWinSSLLibrary.CreateCertificate: ISSLCertificate;
begin
  // P0 后端语义统一：与 OpenSSL 后端保持一致的失败语义
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create certificate: WinSSL library not initialized');

  // 创建空证书对象，调用方可通过 LoadFromFile/LoadFromStream 等方法加载实际证书
  Result := TWinSSLCertificate.Create(nil, False);
end;

function TWinSSLLibrary.CreateCertificateStore: ISSLCertificateStore;
begin
  // P0 后端语义统一：与 OpenSSL 后端保持一致的失败语义
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create certificate store: WinSSL library not initialized');

  // 默认创建受信任根证书存储，调用方可根据需要重新打开其他系统存储
  Result := TWinSSLCertificateStore.Create(SSL_STORE_ROOT);
end;


{ v1.2.0: 能力矩阵缓存管理 }

procedure TWinSSLLibrary.InvalidateCapabilitiesCache;
begin
  FCapabilitiesCached := False;
  FillChar(FCapabilitiesCache, SizeOf(FCapabilitiesCache), 0);
end;

// ============================================================================
// 注册 WinSSL 后端到工厂
// ============================================================================

procedure RegisterWinSSLBackend;
begin
  {$IFDEF WINDOWS}
  try
    // 在 Windows 平台上注册 WinSSL 后端
    // 优先级设为 200，高于 OpenSSL 的 100，使其成为 Windows 上的默认选择
    TSSLFactory.RegisterLibrary(sslWinSSL, @CreateWinSSLLibrary,
      'Windows Schannel (Native SSL/TLS)', 200);
  except
    on E: Exception do
    begin
      // 初始化失败时静默处理，避免程序崩溃
      // 用户可以通过 IsLibraryAvailable 检查 WinSSL 是否可用
    end;
  end;
  {$ENDIF}
end;

procedure UnregisterWinSSLBackend;
begin
  {$IFDEF WINDOWS}
  try
    TSSLFactory.UnregisterLibrary(sslWinSSL);
  except
    // 清理失败时静默处理
  end;
  {$ENDIF}
end;

initialization
  {$IFDEF WINDOWS}
  // 延迟注册：不在初始化时自动注册
  // 用户需要在程序启动后手动调用 RegisterWinSSLBackend
  // 或者使用 nextpas.core.tls.winssl.autoregister 单元
  {$ENDIF}

finalization
  {$IFDEF WINDOWS}
  // 清理时取消注册（如果已注册）
  // 注意：UnregisterWinSSLBackend 内部有 try-except 保护
  // UnregisterWinSSLBackend;  // 暂时禁用，由 autoregister 单元处理
  {$ENDIF}

end.
