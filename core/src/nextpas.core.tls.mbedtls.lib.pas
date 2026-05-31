{**
 * Unit: nextpas.core.tls.mbedtls.lib
 * Purpose: MbedTLS 后端库管理实现
 *
 * P3-9: MbedTLS 后端框架 - ISSLLibrary 实现
 *
 * 实现策略：
 * - 最小子集：仅实现 TLS Client/Server + 证书验证主链路
 * - 能力门控：不支持的功能通过 TSSLBackendCapabilities 显式标记
 * - 统一语义：与 OpenSSL/WinSSL/WolfSSL 后端保持一致的失败语义（fail-fast）
 *
 * MbedTLS 特殊处理：
 * - 需要管理全局熵源和随机数生成器
 * - 这些资源在 Initialize 时创建，供所有上下文共享
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-09
 *}

unit nextpas.core.tls.mbedtls.lib;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.api;

type
  { TMbedTLSLibrary - MbedTLS 库管理类 }
  TMbedTLSLibrary = class(TInterfacedObject, ISSLLibrary)
  private
    FInitialized: Boolean;
    FDefaultConfig: TSSLConfig;
    FStatistics: TSSLStatistics;
    FLastError: Integer;
    FLastErrorString: string;
    FLogCallback: TSSLLogCallback;
    FLogLevel: TSSLLogLevel;
    FCapabilities: TMbedTLSCapabilities;

    // MbedTLS 特有：全局熵源和随机数生成器
    FEntropyContext: Pmbedtls_entropy_context;
    FCtrDrbgContext: Pmbedtls_ctr_drbg_context;

    { v1.2.0: 能力矩阵缓存 }
    FCapabilitiesCached: Boolean;
    FCapabilitiesCache: TSSLBackendCapabilities;

    procedure InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
    procedure SetError(AError: Integer; const AErrorMsg: string);
    procedure ClearInternalError;
    function DetectCapabilities: Boolean;
    function InitializeRNG: Boolean;
    procedure FinalizeRNG;
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

    { MbedTLS 特有：获取随机数生成器上下文 }
    function GetCtrDrbgContext: Pmbedtls_ctr_drbg_context;
  end;

{ 全局工厂函数 }
function CreateMbedTLSLibrary: ISSLLibrary;

{ 手动注册/注销函数 }
procedure RegisterMbedTLSBackend;
procedure UnregisterMbedTLSBackend;

implementation

uses
  nextpas.core.tls.context.config,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.factory,
  nextpas.core.tls.mbedtls.context,
  nextpas.core.tls.mbedtls.certificate;

var
  GSkipFinalizeOnDestroy: Boolean = False;

const
  // MbedTLS 上下文结构体大小（估算值，实际大小取决于编译配置）
  // Use large buffers for safety - MbedTLS 3.x structures can be quite large
  MBEDTLS_ENTROPY_CONTEXT_SIZE = 4096;
  MBEDTLS_CTR_DRBG_CONTEXT_SIZE = 2048;

function CreateMbedTLSLibrary: ISSLLibrary;
begin
  Result := TMbedTLSLibrary.Create;
end;

{ TMbedTLSLibrary }

constructor TMbedTLSLibrary.Create;
begin
  inherited Create;
  FInitialized := False;
  FLastError := 0;
  FLastErrorString := '';
  FLogCallback := nil;
  FLogLevel := sslLogError;
  FEntropyContext := nil;
  FCtrDrbgContext := nil;

  FillChar(FDefaultConfig, SizeOf(FDefaultConfig), 0);
  with FDefaultConfig do
  begin
    LibraryType := sslMbedTLS;
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
  FillChar(FCapabilitiesCache, SizeOf(FCapabilitiesCache), 0);
end;

destructor TMbedTLSLibrary.Destroy;
begin
  if FInitialized and (not GSkipFinalizeOnDestroy) then
    Finalize;
  inherited Destroy;
end;

procedure TMbedTLSLibrary.InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  if Assigned(FLogCallback) and (ALevel <= FLogLevel) then
    FLogCallback(ALevel, '[MbedTLS] ' + AMessage);
end;

procedure TMbedTLSLibrary.SetError(AError: Integer; const AErrorMsg: string);
begin
  FLastError := AError;
  FLastErrorString := AErrorMsg;
  InternalLog(sslLogError, AErrorMsg);
end;

procedure TMbedTLSLibrary.ClearInternalError;
begin
  FLastError := 0;
  FLastErrorString := '';
end;

function TMbedTLSLibrary.DetectCapabilities: Boolean;
var
  LVersionBuf: array[0..31] of AnsiChar;
begin
  Result := False;

  if not IsMbedTLSLoaded then
    Exit;

  // 检测版本
  if Assigned(mbedtls_version_get_string) then
  begin
    FillChar(LVersionBuf, SizeOf(LVersionBuf), 0);
    mbedtls_version_get_string(@LVersionBuf[0]);
    FCapabilities.VersionString := string(LVersionBuf);
  end
  else
    FCapabilities.VersionString := 'Unknown';

  if Assigned(mbedtls_version_get_number) then
    FCapabilities.VersionNumber := mbedtls_version_get_number()
  else
    FCapabilities.VersionNumber := 0;

  // MbedTLS 3.x 支持 TLS 1.3
  FCapabilities.HasTLS12 := True;
  FCapabilities.HasTLS13 := FCapabilities.VersionNumber >= MBEDTLS_MIN_VERSION;

  // MbedTLS 默认支持的功能
  FCapabilities.HasSNI := Assigned(mbedtls_ssl_set_hostname);
  FCapabilities.HasALPN :=
    Assigned(mbedtls_ssl_conf_alpn_protocols) and
    Assigned(mbedtls_ssl_get_alpn_protocol);
  FCapabilities.HasSessionTickets :=
    Assigned(mbedtls_ssl_get_session) and
    Assigned(mbedtls_ssl_set_session);
  FCapabilities.HasECDHE := True;
  FCapabilities.HasChaCha20 := True;
  FCapabilities.HasAESNI := True;

  Result := True;
end;

function TMbedTLSLibrary.InitializeRNG: Boolean;
var
  LRet: Integer;
begin
  Result := False;

  // 分配熵源上下文
  GetMem(FEntropyContext, MBEDTLS_ENTROPY_CONTEXT_SIZE);
  FillChar(FEntropyContext^, MBEDTLS_ENTROPY_CONTEXT_SIZE, 0);

  // 分配随机数生成器上下文
  GetMem(FCtrDrbgContext, MBEDTLS_CTR_DRBG_CONTEXT_SIZE);
  FillChar(FCtrDrbgContext^, MBEDTLS_CTR_DRBG_CONTEXT_SIZE, 0);

  // 初始化熵源
  if Assigned(mbedtls_entropy_init) then
    mbedtls_entropy_init(FEntropyContext);

  // 初始化随机数生成器
  if Assigned(mbedtls_ctr_drbg_init) then
    mbedtls_ctr_drbg_init(FCtrDrbgContext);

  // 种子随机数生成器
  if Assigned(mbedtls_ctr_drbg_seed) and Assigned(mbedtls_entropy_func) then
  begin
    LRet := mbedtls_ctr_drbg_seed(FCtrDrbgContext,
      mbedtls_entropy_func, FEntropyContext, nil, 0);
    if LRet <> 0 then
    begin
      SetError(LRet, Format('mbedtls_ctr_drbg_seed failed: 0x%04X', [-LRet]));
      FinalizeRNG;
      Exit(False);
    end;
  end
  else
  begin
    SetError(-1, 'Required RNG functions not available');
    FinalizeRNG;
    Exit(False);
  end;

  Result := True;
end;

procedure TMbedTLSLibrary.FinalizeRNG;
begin
  if FCtrDrbgContext <> nil then
  begin
    if Assigned(mbedtls_ctr_drbg_free) then
      mbedtls_ctr_drbg_free(FCtrDrbgContext);
    FreeMem(FCtrDrbgContext);
    FCtrDrbgContext := nil;
  end;

  if FEntropyContext <> nil then
  begin
    if Assigned(mbedtls_entropy_free) then
      mbedtls_entropy_free(FEntropyContext);
    FreeMem(FEntropyContext);
    FEntropyContext := nil;
  end;
end;

function TMbedTLSLibrary.Initialize: Boolean;
begin
  Result := False;

  if FInitialized then
    Exit(True);

  ClearInternalError;

  // 加载 MbedTLS 库
  if not LoadMbedTLSLibrary then
  begin
    SetError(-1, 'Failed to load MbedTLS libraries');
    Exit(False);
  end;

  // 检测能力
  if not DetectCapabilities then
  begin
    SetError(-2, 'Failed to detect MbedTLS capabilities');
    UnloadMbedTLSLibrary;
    Exit(False);
  end;

  // 初始化随机数生成器（MbedTLS 特有）
  if not InitializeRNG then
  begin
    UnloadMbedTLSLibrary;
    Exit(False);
  end;

  FInitialized := True;
  InternalLog(sslLogInfo, Format('MbedTLS initialized: %s', [FCapabilities.VersionString]));
  Result := True;
end;

procedure TMbedTLSLibrary.Finalize;
begin
  if not FInitialized then
    Exit;

  { v1.2.0: 使缓存失效 }
  InvalidateCapabilitiesCache;

  FinalizeRNG;
  UnloadMbedTLSLibrary;
  FInitialized := False;
  InternalLog(sslLogInfo, 'MbedTLS finalized');
end;

function TMbedTLSLibrary.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

function TMbedTLSLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TMbedTLSLibrary.GetVersionString: string;
begin
  if FInitialized then
    Result := 'MbedTLS ' + FCapabilities.VersionString
  else
    Result := 'MbedTLS (not initialized)';
end;

function TMbedTLSLibrary.GetVersionNumber: Cardinal;
begin
  Result := FCapabilities.VersionNumber;
end;

function TMbedTLSLibrary.GetCompileFlags: string;
begin
  Result := 'MbedTLS';
  {$IFDEF CPU64}
  Result := Result + ', x64';
  {$ELSE}
  Result := Result + ', x86';
  {$ENDIF}
end;

function TMbedTLSLibrary.IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := False;
  if not FInitialized then Exit;

  case AProtocol of
    sslProtocolSSL2, sslProtocolSSL3: Result := False;  // 不支持废弃协议
    sslProtocolTLS10: Result := False;  // MbedTLS 3.x 默认禁用
    sslProtocolTLS11: Result := False;  // MbedTLS 3.x 默认禁用
    sslProtocolTLS12: Result := FCapabilities.HasTLS12;
    sslProtocolTLS13: Result := FCapabilities.HasTLS13;
    sslProtocolDTLS10, sslProtocolDTLS12: Result := False;  // 暂不支持
  else
    Result := False;  // 未知协议
  end;
end;

function TMbedTLSLibrary.IsCipherSupported(const ACipherName: string): Boolean;
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
function TMbedTLSLibrary.IsFeatureSupported(AFeature: TSSLFeature): Boolean;
begin
  if not FInitialized then
    Exit(False);

  case AFeature of
    sslFeatSNI: Result := FCapabilities.HasSNI;
    sslFeatALPN: Result := FCapabilities.HasALPN;
    sslFeatSessionCache: Result := True;
    sslFeatSessionTickets: Result := FCapabilities.HasSessionTickets;
    sslFeatRenegotiation: Result := False;  // 安全考虑，默认禁用
    sslFeatOCSPStapling: Result := False;   // 需要手动实现
    sslFeatCertificateTransparency: Result := False;
  else
    Result := False;
  end;
end;
{$WARN 6018 ON}

function TMbedTLSLibrary.GetCapabilities: TSSLBackendCapabilities;
begin
  { v1.2.0: 如果已缓存，直接返回缓存值 }
  if FCapabilitiesCached then
  begin
    Result := FCapabilitiesCache;
    Exit;
  end;

  FillChar(Result, SizeOf(Result), 0);

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
  Result.BackendType := sslMbedTLS;
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
  Result.OCSPStaplingSupport := sslSupportNone;  // 需要手动实现
  Result.CertTransparencySupport := sslSupportNone;
  if FCapabilities.HasSessionTickets then
    Result.SessionTicketsSupport := sslSupportStable
  else
    Result.SessionTicketsSupport := sslSupportNone;
  Result.SessionCacheSupport := sslSupportStable;

  // 密码算法支持（MbedTLS 主要针对嵌入式，算法精简）
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

  // 性能特性（MbedTLS 针对嵌入式和IoT优化）
  Result.HasHardwareAcceleration := True;   // 支持硬件加速
  Result.HasSIMDOptimization := False;      // 通常不使用 SIMD（嵌入式）
  Result.HasAssemblyOptimization := True;   // 部分汇编优化

  // 平台特性
  Result.RequiresExternalLibrary := True;
  Result.SupportsSystemCertStore := False;  // 嵌入式通常不使用系统证书
  Result.SupportsPKCS11 := False;           // 需要特殊配置
  Result.SupportsTPM := False;

  // 安全特性（MbedTLS 注重嵌入式安全）
  Result.HasConstantTimeOperations := True;
  Result.SupportsFIPSMode := False;         // 不支持 FIPS
  Result.HasSecureMemoryWipe := True;

  // 证书和密钥格式支持
  Result.SupportsDERPrivateKey := True;
  Result.SupportsPKCS8PrivateKey := True;
  Result.SupportsPKCS12 := False;  // no shipped PKCS#12/PFX bundle create/parse/import surface on current MbedTLS runtime paths
  Result.SupportsPasswordProtectedKeys := True;

  // 扩展性
  Result.SupportsCustomCipherSuites := False;  // custom non-default cipher overrides are not wired into the current MbedTLS runtime path
  Result.SupportsCallbacks := False;  // verify/password/info setters are not wired into MbedTLS runtime paths yet

  // 兼容性（MbedTLS 与 OpenSSL 兼容性中等，部分功能需要适配）
  Result.CompatibilityLevel := 75;  // 75% 兼容性
  Result.KnownIssues :=
    'Optimized for embedded systems; early-data, OCSP stapling, and certificate transparency ' +
    'are not currently supported.';

  NormalizeLegacyCapabilityBooleans(Result);

  { v1.2.0: 缓存能力矩阵 }
  FCapabilitiesCache := Result;
  FCapabilitiesCached := True;
end;

procedure TMbedTLSLibrary.SetDefaultConfig(const AConfig: TSSLConfig);
var
  LConfig: TSSLConfig;
begin
  LConfig := AConfig;
  TSSLFactory.NormalizeConfig(LConfig);

  FLogLevel := LConfig.LogLevel;
  LConfig.LogCallback := FLogCallback;
  FDefaultConfig := LConfig;
end;

function TMbedTLSLibrary.GetDefaultConfig: TSSLConfig;
begin
  Result := FDefaultConfig;
end;

function TMbedTLSLibrary.GetLastError: Integer;
begin
  Result := FLastError;
end;

function TMbedTLSLibrary.GetLastErrorString: string;
begin
  Result := FLastErrorString;
end;

procedure TMbedTLSLibrary.ClearError;
begin
  ClearInternalError;
end;

function TMbedTLSLibrary.GetStatistics: TSSLStatistics;
begin
  Result := FStatistics;
end;

procedure TMbedTLSLibrary.ResetStatistics;
begin
  FillChar(FStatistics, SizeOf(FStatistics), 0);
end;

procedure TMbedTLSLibrary.SetLogCallback(ACallback: TSSLLogCallback);
begin
  FLogCallback := ACallback;
  FDefaultConfig.LogCallback := ACallback;
end;

procedure TMbedTLSLibrary.Log(ALevel: TSSLLogLevel; const AMessage: string);
begin
  InternalLog(ALevel, AMessage);
end;

function TMbedTLSLibrary.CreateContext(AType: TSSLContextType): ISSLContext;
var
  LConfig: TSSLConfig;
  LVerifyMode: TSSLVerifyModes;
  Store: ISSLCertificateStore;
begin
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create context: MbedTLS library not initialized');

  LConfig := FDefaultConfig;
  LConfig.ContextType := AType;

  ValidateDirectLibraryConnectionScope(
    LConfig,
    'TMbedTLSLibrary.CreateContext'
  );

  if (AType = sslCtxServer) and (Trim(LConfig.ServerName) <> '') then
    raise ESSLConfigurationException.CreateWithContext(
      'ServerName is client-scoped. Server-side connections ignore context-level ServerName; ' +
      'remove it from TMbedTLSLibrary.CreateContext when creating server contexts.',
      sslErrConfiguration,
      'TMbedTLSLibrary.CreateContext',
      0,
      sslMbedTLS
    );

  ValidateContextReplayStoreConfigScope(
    LConfig,
    AType,
    'TMbedTLSLibrary.CreateContext'
  );
  LVerifyMode := LConfig.VerifyMode;
  if (AType = sslCtxServer) and
    (LVerifyMode = [sslVerifyPeer]) and
    (Trim(LConfig.CAFile) = '') and
    (Trim(LConfig.CAPath) = '') and
    (not LConfig.UseSystemRoots) then
    LVerifyMode := [];

  Result := TMbedTLSContext.Create(Self, AType);
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
        'TMbedTLSLibrary.CreateContext received TSSLConfig.ServerName as deprecated context-level ' +
        'SNI compatibility; CreateContext ignores it for new contexts; prefer per-connection SNI via ' +
        'ISSLClientConnection.SetServerName or TSSLConnector.Connect*(..., ServerName).'
      );

    if LConfig.ALPNProtocols <> '' then
      Result.SetALPNProtocols(LConfig.ALPNProtocols);

    ApplyEarlyDataContextConfig(Result, LConfig);
    ApplyEarlyDataReplayStoreConfig(Result, LConfig,
      'TMbedTLSLibrary.CreateContext');
  end;
  InternalLog(sslLogDebug, 'Created MbedTLS context');
end;

function TMbedTLSLibrary.CreateCertificate: ISSLCertificate;
begin
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create certificate: MbedTLS library not initialized');

  Result := TMbedTLSCertificate.Create;
end;

function TMbedTLSLibrary.CreateCertificateStore: ISSLCertificateStore;
begin
  if not FInitialized then
    raise ESSLInitError.Create('Cannot create certificate store: MbedTLS library not initialized');

  Result := TMbedTLSCertificateStore.Create;
end;

function TMbedTLSLibrary.GetCtrDrbgContext: Pmbedtls_ctr_drbg_context;
begin
  Result := FCtrDrbgContext;
end;

{ v1.2.0: 能力矩阵缓存管理 }

procedure TMbedTLSLibrary.InvalidateCapabilitiesCache;
begin
  FCapabilitiesCached := False;
  FillChar(FCapabilitiesCache, SizeOf(FCapabilitiesCache), 0);
end;

{ 注册函数 }

procedure RegisterMbedTLSBackend;
begin
  try
    TSSLFactory.RegisterLibrary(sslMbedTLS, @CreateMbedTLSLibrary,
      'MbedTLS (Embedded TLS)', 175);
  except
  end;
end;

procedure UnregisterMbedTLSBackend;
begin
  TSSLFactory.UnregisterLibrary(sslMbedTLS);
end;

procedure UnregisterMbedTLSBackendForProcessShutdown;
begin
  GSkipFinalizeOnDestroy := True;
  TSSLFactory.UnregisterLibraryForProcessShutdown(sslMbedTLS);
end;

initialization
  RegisterMbedTLSBackend;

finalization
  UnregisterMbedTLSBackendForProcessShutdown;

end.
