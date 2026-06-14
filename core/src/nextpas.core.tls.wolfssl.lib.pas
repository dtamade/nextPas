{**
 * Unit: nextpas.core.tls.wolfssl.lib
 * Purpose: WolfSSL 后端库管理实现
 *
 * P2-7: WolfSSL 后端框架 - ISSLLibrary 实现
 *
 * 实现策略：
 * - 最小子集：仅实现 TLS Client/Server + 证书验证主链路
 * - 能力门控：不支持的功能通过 TSSLBackendCapabilities 显式标记
 * - 统一语义：与 OpenSSL/WinSSL 后端保持一致的失败语义（fail-fast）
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-09
 *}

unit nextpas.core.tls.wolfssl.lib;

{$mode objfpc}{$H+}

interface

uses SysUtils, nextpas.core.tls.base, nextpas.core.tls.wolfssl.base, nextpas.core.tls.wolfssl.api;

type
  { TWolfSSLLibrary - WolfSSL 库管理类 }
  TWolfSSLLibrary = class(TInterfacedObject, ISSLLibrary)
  private
    FInitialized: Boolean;
    FDefaultConfig: TSSLConfig;
    FStatistics: TSSLStatistics;
    FLastError: Integer;
    FLastErrorString: string;
    FLogCallback: TSSLLogCallback;
    FLogLevel: TSSLLogLevel;
    FCapabilities: TWolfSSLCapabilities;

    { v1.2.0: 能力矩阵缓存 }
    FCapabilitiesCached: Boolean;
    FCapabilitiesCache: TSSLBackendCapabilities;

    procedure InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
    procedure SetError(AError: Integer; const AErrorMsg: string);
    procedure ClearInternalError;
    function DetectCapabilities: Boolean;
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
    function GetCapabilities: TSSLBackendCapabilities;

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
  end;

{ 全局工厂函数 }
function CreateWolfSSLLibrary: ISSLLibrary;

{ 手动注册/注销函数 }
procedure RegisterWolfSSLBackend;
procedure UnregisterWolfSSLBackend;

implementation

uses nextpas.core.tls.context.config, nextpas.core.tls.errors, nextpas.core.tls.exceptions, nextpas.core.tls.factory, nextpas.core.tls.wolfssl.context, nextpas.core.tls.wolfssl.certificate;

var
  GSkipFinalizeOnDestroy: Boolean = False;

function CreateWolfSSLLibrary: ISSLLibrary;
begin
  Result := TWolfSSLLibrary.Create;
end;

{ TWolfSSLLibrary }

constructor TWolfSSLLibrary.Create;
begin
  inherited Create;
  FInitialized := False;
  FLastError := 0;
  FLastErrorString := '';
  FLogCallback := nil;
  FLogLevel := sslLogError;

  FillChar(FDefaultConfig, SizeOf(FDefaultConfig), 0);
  with FDefaultConfig do
  begin
    LibraryType := sslWolfSSL;
    ContextType := sslCtxClient;
    ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
    PreferredVersion := sslProtocolTLS13;
    VerifyMode := [sslVerifyPeer];
    VerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
    Options := [ssoEnableSNI];
    BufferSize := SSL_DEFAULT_BUFFER_SIZE;
    HandshakeTimeout := SSL_DEFAULT_HANDSHAKE_TIMEOUT;
    SessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;
    SessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
    EnableCompression := False;
    EnableSessionTickets := False;
    EnableOCSPStapling := False;
    LogLevel := sslLogError;
  end;

  TSSLFactory.NormalizeConfig(FDefaultConfig);

  FillChar(FStatistics, SizeOf(FStatistics), 0);
  FillChar(FCapabilities, SizeOf(FCapabilities), 0);

  { v1.2.0: 初始化能力矩阵缓存 }
  FCapabilitiesCached := False;
  FCapabilitiesCache := Default(TSSLBackendCapabilities);
end;

destructor TWolfSSLLibrary.Destroy;
begin
  if FInitialized and (not GSkipFinalizeOnDestroy) then
    Finalize;
  inherited Destroy;
end;

procedure TWolfSSLLibrary.InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  if Assigned(FLogCallback) and (ALevel <= FLogLevel) then
    FLogCallback(ALevel, '[WolfSSL] ' + AMessage);
end;

procedure TWolfSSLLibrary.SetError(AError: Integer; const AErrorMsg: string);
begin
  FLastError := AError;
  FLastErrorString := AErrorMsg;
  InternalLog(sslLogError, AErrorMsg);
end;

procedure TWolfSSLLibrary.ClearInternalError;
begin
  FLastError := 0;
  FLastErrorString := '';
end;

function TWolfSSLLibrary.DetectCapabilities: Boolean;
var
  LVer: string;
  LMajor, LMinor, LPatch: Integer;
begin
  Result := False;

  if not IsWolfSSLLoaded then
    Exit;

  // 检测版本
  if Assigned(wolfSSL_lib_version) then
    FCapabilities.VersionString := string(wolfSSL_lib_version())
  else
    FCapabilities.VersionString := 'Unknown';

  // 解析版本号 (例如 "5.7.2" -> 50702)
  LVer := FCapabilities.VersionString;
  LMajor := 0;
  LMinor := 0;
  LPatch := 0;

  // 简单解析 major.minor.patch
  if Pos('.', LVer) > 0 then
  begin
    LMajor := StrToIntDef(Copy(LVer, 1, Pos('.', LVer) - 1), 0);
    Delete(LVer, 1, Pos('.', LVer));
    if Pos('.', LVer) > 0 then
    begin
      LMinor := StrToIntDef(Copy(LVer, 1, Pos('.', LVer) - 1), 0);
      Delete(LVer, 1, Pos('.', LVer));
      LPatch := StrToIntDef(LVer, 0);
    end
    else
      LMinor := StrToIntDef(LVer, 0);
  end;
  FCapabilities.VersionNumber := LMajor * 10000 + LMinor * 100 + LPatch;

  // 检测 TLS 1.3 支持
  FCapabilities.HasTLS13 := Assigned(wolfTLSv1_3_client_method);

  // 检测 SNI 支持
  FCapabilities.HasSNI := Assigned(wolfSSL_UseSNI);

  // WolfSSL 默认支持的功能
  FCapabilities.HasALPN :=
    Assigned(wolfSSL_UseALPN) and
    Assigned(wolfSSL_ALPN_GetProtocol);
  FCapabilities.HasSessionTickets :=
    Assigned(wolfSSL_get_session) and
    Assigned(wolfSSL_set_session);
  FCapabilities.HasECDHE := True;
  FCapabilities.HasChaCha20 := True;
  FCapabilities.HasOCSP :=
    (Assigned(wolfSSL_CTX_EnableOCSPStapling) and
    Assigned(wolfSSL_UseOCSPStapling) and
    Assigned(wolfSSL_GetOCSP_Response)) or
    (Assigned(wolfSSL_CTX_set_tlsext_status_cb) and
    Assigned(wolfSSL_CTX_set_tlsext_status_arg) and
    Assigned(wolfSSL_set_tlsext_status_ocsp_resp));

  Result := True;
end;

function TWolfSSLLibrary.Initialize: Boolean;
begin
  Result := False;

  if FInitialized then
    Exit(True);

  ClearInternalError;

  // 加载 WolfSSL 库
  if not LoadWolfSSLLibrary then
  begin
    SetError(-1, 'Failed to load WolfSSL library: ' + WOLFSSL_LIB_NAME);
    Exit(False);
  end;

  // 初始化 WolfSSL
  if Assigned(wolfssl_init) then
  begin
    if wolfssl_init() <> WOLFSSL_SUCCESS then
    begin
      SetError(-2, 'wolfSSL_Init() failed');
      UnloadWolfSSLLibrary;
      Exit(False);
    end;
  end;

  // 检测能力
  if not DetectCapabilities then
  begin
    SetError(-3, 'Failed to detect WolfSSL capabilities');
    UnloadWolfSSLLibrary;
    Exit(False);
  end;

  FInitialized := True;
  InternalLog(sslLogInfo, Format('WolfSSL initialized: %s', [FCapabilities.VersionString]));
  Result := True;
end;

procedure TWolfSSLLibrary.Finalize;
begin
  if not FInitialized then
    Exit;

  { v1.2.0: 使缓存失效 }
  InvalidateCapabilitiesCache;

  if Assigned(wolfssl_cleanup) then
    wolfssl_cleanup();

  UnloadWolfSSLLibrary;
  FInitialized := False;
  InternalLog(sslLogInfo, 'WolfSSL finalized');
end;

function TWolfSSLLibrary.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

function TWolfSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslWolfSSL;
end;

function TWolfSSLLibrary.GetVersionString: string;
begin
  if FInitialized then
    Result := 'WolfSSL ' + FCapabilities.VersionString
  else
    Result := 'WolfSSL (not initialized)';
end;

function TWolfSSLLibrary.GetVersionNumber: Cardinal;
begin
  Result := FCapabilities.VersionNumber;
end;

function TWolfSSLLibrary.GetCompileFlags: string;
begin
  Result := 'WolfSSL';
  {$IFDEF CPU64}
  Result := Result + ', x64';
  {$ELSE}
  Result := Result + ', x86';
  {$ENDIF}
end;

function TWolfSSLLibrary.IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := False;
  if not FInitialized then Exit;

  case AProtocol of
    sslProtocolSSL2, sslProtocolSSL3: Result := False;  // 不支持废弃协议
    sslProtocolTLS10: Result := False;  // WolfSSL 默认禁用
    sslProtocolTLS11: Result := False;  // WolfSSL 默认禁用
    sslProtocolTLS12: Result := True;
    sslProtocolTLS13: Result := FCapabilities.HasTLS13;
    sslProtocolDTLS10, sslProtocolDTLS12: Result := False;  // 暂不支持
  else
    Result := False;
  end;
end;

function TWolfSSLLibrary.IsCipherSupported(const ACipherName: string): Boolean;
var
  LCipher: string;
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

  if (not Result) and FCapabilities.HasChaCha20 then
    Result :=
      (LCipher = 'TLS_CHACHA20_POLY1305_SHA256') or
      (LCipher = 'CHACHA20_POLY1305') or
      (LCipher = 'CHACHA20-POLY1305');
end;

{$WARN 6018 OFF}
function TWolfSSLLibrary.IsFeatureSupported(AFeature: TSSLFeature): Boolean;
begin
  if not FInitialized then
    Exit(False);

  case AFeature of
    sslFeatSNI: Result := FCapabilities.HasSNI;
    sslFeatALPN: Result := FCapabilities.HasALPN;
    sslFeatSessionCache: Result := True;
    sslFeatSessionTickets: Result := FCapabilities.HasSessionTickets;
    sslFeatRenegotiation: Result := False;  // 安全考虑，默认禁用
    sslFeatOCSPStapling: Result := FCapabilities.HasOCSP;
    sslFeatCertificateTransparency: Result := False;
  else
    Result := False;
  end;
end;
{$WARN 6018 ON}

function TWolfSSLLibrary.GetCapabilities: TSSLBackendCapabilities;
begin
  { v1.2.0: 如果已缓存，直接返回缓存值 }
  if FCapabilitiesCached then
  begin
    Result := FCapabilitiesCache;
    Exit;
  end;

  Result := Default(TSSLBackendCapabilities);

  if not FInitialized then
    Exit;

  // v1.1.0 字段（向后兼容）
  Result.SupportsTLS13 := FCapabilities.HasTLS13;
  Result.SupportsECDHE := FCapabilities.HasECDHE;
  Result.SupportsChaChaPoly := FCapabilities.HasChaCha20;
  Result.SupportsPEMPrivateKey := True;
  Result.MinTLSVersion := sslProtocolTLS12;

  if FCapabilities.HasTLS13 then
    Result.MaxTLSVersion := sslProtocolTLS13
  else
    Result.MaxTLSVersion := sslProtocolTLS12;

  // v1.2.0 新增字段
  Result.BackendType := sslWolfSSL;
  Result.BackendImplType := sslImplCLibrary;
  Result.BackendVersion := GetVersionString;
  Result.SupportsDTLS :=
    IsProtocolSupported(sslProtocolDTLS10) or IsProtocolSupported(sslProtocolDTLS12);

  // 功能支持级别
  if FCapabilities.HasSNI then
    Result.SNISupport := sslSupportStable
  else
    Result.SNISupport := sslSupportNone;
  if FCapabilities.HasALPN then
    Result.ALPNSupport := sslSupportStable
  else
    Result.ALPNSupport := sslSupportNone;
  if FCapabilities.HasOCSP then
    Result.OCSPStaplingSupport := sslSupportExperimental
  else
    Result.OCSPStaplingSupport := sslSupportNone;
  Result.CertTransparencySupport := sslSupportNone;
  if FCapabilities.HasSessionTickets then
    Result.SessionTicketsSupport := sslSupportStable
  else
    Result.SessionTicketsSupport := sslSupportNone;
  Result.SessionCacheSupport := sslSupportStable;
  if FCapabilities.HasTLS13 and Assigned(wolfSSL_write_early_data) and
    Assigned(wolfSSL_get_early_data_status) and
    Assigned(wolfSSL_CTX_set_max_early_data) and
    Assigned(wolfSSL_CTX_get_max_early_data) then
  begin
    Result.ZeroRTTSupport := sslSupportExperimental;
    Result.EarlyDataSupport := sslSupportExperimental;
  end
  else
  begin
    Result.ZeroRTTSupport := sslSupportNone;
    Result.EarlyDataSupport := sslSupportNone;
  end;

  // 密码算法支持
  Result.SupportedCiphers := [
    sslCipherAES128, sslCipherAES256, sslCipherAES128GCM, sslCipherAES256GCM
  ];
  if FCapabilities.HasChaCha20 then
    Result.SupportedCiphers := Result.SupportedCiphers + [sslCipherCHACHA20_POLY1305];

  // 哈希算法支持
  Result.SupportedHashes := [
    sslHashSHA1, sslHashSHA256, sslHashSHA384, sslHashSHA512
  ];

  // 密钥交换算法支持
  Result.SupportedKeyExchanges := [
    sslKexRSA, sslKexDHE_RSA, sslKexECDHE_RSA, sslKexECDHE_ECDSA
  ];

  // 性能特性（WolfSSL 针对嵌入式优化）
  Result.HasHardwareAcceleration := True;  // 支持硬件加速
  Result.HasSIMDOptimization := True;      // 支持 SIMD
  Result.HasAssemblyOptimization := True;  // 有汇编优化

  // 平台特性
  Result.RequiresExternalLibrary := True;
  Result.SupportsSystemCertStore := False;  // WolfSSL 通常不使用系统证书存储
  Result.SupportsPKCS11 := False;           // 需要特殊配置
  Result.SupportsTPM := False;

  // 安全特性
  Result.HasConstantTimeOperations := True;  // WolfSSL 注重恒定时间操作
  Result.SupportsFIPSMode := False;          // 需要 FIPS 版本
  Result.HasSecureMemoryWipe := True;

  // 证书和密钥格式支持
  Result.SupportsDERPrivateKey := True;
  Result.SupportsPKCS8PrivateKey := True;
  Result.SupportsPKCS12 := False;  // no shipped PKCS#12/PFX bundle create/parse/import surface on current WolfSSL runtime paths
  Result.SupportsPasswordProtectedKeys := False;  // no shipped password bridge consumes non-empty APassword on current WolfSSL runtime paths

  // 扩展性
  Result.SupportsCustomCipherSuites := False;  // custom non-default cipher overrides are not wired into the current WolfSSL runtime path
  Result.SupportsCallbacks := False;  // verify/password/info setters are not wired into WolfSSL runtime paths yet

  // 兼容性（WolfSSL 与 OpenSSL 兼容性较好）
  Result.CompatibilityLevel := 85;  // 85% 兼容性
  Result.KnownIssues :=
    'Feature availability depends on build/runtime helpers; early-data may degrade to none ' +
    'when required helpers are unavailable; OCSP stapling remains experimental.';

  NormalizeLegacyCapabilityBooleans(Result);

  { v1.2.0: 缓存能力矩阵 }
  FCapabilitiesCache := Result;
  FCapabilitiesCached := True;
end;

procedure TWolfSSLLibrary.SetDefaultConfig(const AConfig: TSSLConfig);
var
  LConfig: TSSLConfig;
begin
  LConfig := AConfig;
  TSSLFactory.NormalizeConfig(LConfig);

  FLogLevel := LConfig.LogLevel;
  LConfig.LogCallback := FLogCallback;
  FDefaultConfig := LConfig;
end;

function TWolfSSLLibrary.GetDefaultConfig: TSSLConfig;
begin
  Result := FDefaultConfig;
end;

function TWolfSSLLibrary.GetLastError: Integer;
begin
  Result := FLastError;
end;

function TWolfSSLLibrary.GetLastErrorString: string;
begin
  Result := FLastErrorString;
end;

procedure TWolfSSLLibrary.ClearError;
begin
  ClearInternalError;
end;

function TWolfSSLLibrary.GetStatistics: TSSLStatistics;
begin
  Result := FStatistics;
end;

procedure TWolfSSLLibrary.ResetStatistics;
begin
  FillChar(FStatistics, SizeOf(FStatistics), 0);
end;

procedure TWolfSSLLibrary.SetLogCallback(ACallback: TSSLLogCallback);
begin
  FLogCallback := ACallback;
  FDefaultConfig.LogCallback := ACallback;
end;

procedure TWolfSSLLibrary.Log(ALevel: TSSLLogLevel; const AMessage: string);
begin
  InternalLog(ALevel, AMessage);
end;

function TWolfSSLLibrary.CreateContext(AType: TSSLContextType): ISSLContext;
var
  LConfig: TSSLConfig;
  LExposeEarlyData: Boolean;
  LExposeServerOCSP: Boolean;
  LVerifyMode: TSSLVerifyModes;
  Store: ISSLCertificateStore;
begin
  // P0 后端语义统一：与 OpenSSL/WinSSL 后端保持一致的失败语义
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create context: WolfSSL library not initialized');

  LConfig := FDefaultConfig;
  LConfig.ContextType := AType;

  ValidateDirectLibraryConnectionScope(
    LConfig,
    'TWolfSSLLibrary.CreateContext'
  );

  if (AType = sslCtxServer) and (Trim(LConfig.ServerName) <> '') then
    raise ESSLConfigurationException.CreateWithContext(
      'ServerName is client-scoped. Server-side connections ignore context-level ServerName; ' +
      'remove it from TWolfSSLLibrary.CreateContext when creating server contexts.',
      sslErrConfiguration,
      'TWolfSSLLibrary.CreateContext',
      0,
      sslWolfSSL
    );

  ValidateContextReplayStoreConfigScope(
    LConfig,
    AType,
    'TWolfSSLLibrary.CreateContext'
  );

  LExposeEarlyData := GetCapabilities.EarlyDataSupport <> sslSupportNone;
  LExposeServerOCSP := (AType in [sslCtxServer, sslCtxBoth]) and
    (GetCapabilities.OCSPStaplingSupport <> sslSupportNone);
  LVerifyMode := LConfig.VerifyMode;
  if (AType = sslCtxServer) and
    (LVerifyMode = [sslVerifyPeer]) and
    (Trim(LConfig.CAFile) = '') and
    (Trim(LConfig.CAPath) = '') and
    (not LConfig.UseSystemRoots) then
    LVerifyMode := [];

  if LExposeEarlyData and LExposeServerOCSP then
    Result := TWolfSSLAdvancedContext.Create(Self, AType)
  else if LExposeEarlyData then
    Result := TWolfSSLEarlyDataContext.Create(Self, AType)
  else if LExposeServerOCSP then
    Result := TWolfSSLOCSPStaplingContext.Create(Self, AType)
  else
    Result := TWolfSSLContext.Create(Self, AType);

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
        'TWolfSSLLibrary.CreateContext received TSSLConfig.ServerName as deprecated context-level ' +
        'SNI compatibility; CreateContext ignores it for new contexts; prefer per-connection SNI via ' +
        'ISSLClientConnection.SetServerName or TSSLConnector.Connect*(..., ServerName).'
      );

    if LConfig.ALPNProtocols <> '' then
      Result.SetALPNProtocols(LConfig.ALPNProtocols);

    ApplyEarlyDataContextConfig(Result, LConfig);
    ApplyEarlyDataReplayStoreConfig(Result, LConfig,
      'TWolfSSLLibrary.CreateContext');
  end;
end;

function TWolfSSLLibrary.CreateCertificate: ISSLCertificate;
begin
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create certificate: WolfSSL library not initialized');

  Result := TWolfSSLCertificate.Create;
end;

function TWolfSSLLibrary.CreateCertificateStore: ISSLCertificateStore;
begin
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create certificate store: WolfSSL library not initialized');

  Result := TWolfSSLCertificateStore.Create;
end;

{ v1.2.0: 能力矩阵缓存管理 }

procedure TWolfSSLLibrary.InvalidateCapabilitiesCache;
begin
  FCapabilitiesCached := False;
  FCapabilitiesCache := Default(TSSLBackendCapabilities);
end;

{ 注册函数 }

procedure RegisterWolfSSLBackend;
begin
  try
    // 注册 WolfSSL 后端，优先级 150（介于 OpenSSL 100 和 WinSSL 200 之间）
    TSSLFactory.RegisterLibrary(sslWolfSSL, @CreateWolfSSLLibrary,
      'WolfSSL (Lightweight TLS)', 150);
  except
    // 注册失败时静默处理
  end;
end;

procedure UnregisterWolfSSLBackend;
begin
  TSSLFactory.UnregisterLibrary(sslWolfSSL);
end;

procedure UnregisterWolfSSLBackendForProcessShutdown;
begin
  GSkipFinalizeOnDestroy := True;
  TSSLFactory.UnregisterLibraryForProcessShutdown(sslWolfSSL);
end;

initialization
  RegisterWolfSSLBackend;

finalization
  UnregisterWolfSSLBackendForProcessShutdown;

end.
