{
  nextpas.core.tls.openssl.backed - OpenSSL 库管理实现
  
  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-11-02
  
  描述:
    实现 ISSLLibrary 接口的 OpenSSL 后端。
    负责 OpenSSL 的初始化、配置和上下文创建。
    支持 Linux, macOS, Android 等平台。
}
 
unit nextpas.core.tls.openssl.backed;

{$mode ObjFPC}{$H+}
{$IFDEF UNIX}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  DynLibs,
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.tls.base,
  nextpas.core.tls.errors, // Rust-quality: Raise helpers
  nextpas.core.tls.exceptions, // Rust-quality: Typed exceptions
  nextpas.core.tls.openssl.errors, // OpenSSL-specific raise helpers
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader, // P0-1.1: 使用统一的加载器
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.asn1,
  nextpas.core.tls.openssl.api.x509v3,
  nextpas.core.tls.openssl.api.hmac,
  nextpas.core.tls.openssl.api.ts,
  nextpas.core.tls.openssl.api.pkcs,
  nextpas.core.tls.openssl.api.pkcs12,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.certificate;

type
  { TOpenSSLLibraryPaths - 自定义库路径配置 }
  TOpenSSLLibraryPaths = record
    CryptoLibPath: string;  // 自定义 libcrypto 路径
    SSLLibPath: string;     // 自定义 libssl 路径
  end;

  { TOpenSSLLibrary - OpenSSL 库管理类 }
  TOpenSSLLibrary = class(TInterfacedObject, ISSLLibrary)
  private
    FInitialized: Boolean;
    FDefaultConfig: TSSLConfig;
    FStatistics: TSSLStatistics;
    FLastError: Integer;
    FLastErrorString: string;
    FLogCallback: TSSLLogCallback;
    FLogLevel: TSSLLogLevel;
    // P0-1.1: 移除 FLibSSLHandle 和 FLibCryptoHandle
    // 现在通过 TOpenSSLLoader 获取
    FVersionString: string;
    FVersionNumber: Cardinal;
    // v1.2.0: 能力矩阵缓存
    FCapabilitiesCached: Boolean;
    FCapabilitiesCache: TSSLBackendCapabilities;

    { 内部方法 }
    procedure InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
    function LoadOpenSSLLibraries: Boolean;
    procedure UnloadOpenSSLLibraries;
    function DetectOpenSSLVersion: Boolean;
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
  end;

{ 全局变量 - 自定义库路径配置 }
var
  CustomLibraryPaths: TOpenSSLLibraryPaths;
  UseCustomPaths: Boolean = False;

{ 全局函数 - 库路径配置 }
procedure SetCustomLibraryPaths(const ACryptoPath, ASSLPath: string);
function GetCustomLibraryPaths: TOpenSSLLibraryPaths;
function IsUsingCustomPaths: Boolean;
procedure ClearCustomLibraryPaths;

{ 全局工厂函数 }
function CreateOpenSSLLibrary: ISSLLibrary;

procedure RegisterOpenSSLBackend;
procedure UnregisterOpenSSLBackend;

implementation

uses nextpas.core.tls.context.config, nextpas.core.tls.openssl.context, nextpas.core.tls.openssl.certstore, nextpas.core.tls.pkcs11.backend, nextpas.core.tls.openssl.api.bio, nextpas.core.tls.openssl.api.pem, nextpas.core.tls.factory;

// ============================================================================
// 全局函数 - 库路径配置
// ============================================================================

procedure SetCustomLibraryPaths(const ACryptoPath, ASSLPath: string);
begin
  CustomLibraryPaths.CryptoLibPath := ACryptoPath;
  CustomLibraryPaths.SSLLibPath := ASSLPath;
  UseCustomPaths := (ACryptoPath <> '') or (ASSLPath <> '');
end;

function GetCustomLibraryPaths: TOpenSSLLibraryPaths;
begin
  Result := CustomLibraryPaths;
end;

function IsUsingCustomPaths: Boolean;
begin
  Result := UseCustomPaths;
end;

procedure ClearCustomLibraryPaths;
begin
  CustomLibraryPaths.CryptoLibPath := '';
  CustomLibraryPaths.SSLLibPath := '';
  UseCustomPaths := False;
end;

// ============================================================================
// 全局工厂函数
// ============================================================================

function CreateOpenSSLLibrary: ISSLLibrary;
begin
  Result := TOpenSSLLibrary.Create;
end;

// ============================================================================
// TOpenSSLLibrary - 构造和析构
// ============================================================================

constructor TOpenSSLLibrary.Create;
begin
  inherited Create;
  FInitialized := False;
  FLastError := 0;
  FLastErrorString := '';
  FLogCallback := nil;
  FLogLevel := sslLogError;
  // P0-1.1: 移除 FLibSSLHandle 和 FLibCryptoHandle 初始化
  // 现在通过 TOpenSSLLoader 管理
  FVersionString := '';
  FVersionNumber := 0;
  // v1.2.0: 初始化能力矩阵缓存
  FCapabilitiesCached := False;
  FillChar(FCapabilitiesCache, SizeOf(FCapabilitiesCache), 0);

  // 初始化默认配置
  FillChar(FDefaultConfig, SizeOf(FDefaultConfig), 0);
  with FDefaultConfig do
  begin
    LibraryType := sslOpenSSL;
    ContextType := sslCtxClient;
    ProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
    PreferredVersion := sslProtocolTLS13;
    VerifyMode := [sslVerifyPeer];
    VerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
    CipherList := SSL_DEFAULT_CIPHER_LIST;
    CipherSuites := SSL_DEFAULT_TLS13_CIPHERSUITES;
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

  // Normalize options derived from booleans (EnableSessionTickets, EnableCompression, etc.)
  // to keep ISSLLibrary.CreateContext consistent with TSSLFactory.NormalizeConfig.
  TSSLFactory.NormalizeConfig(FDefaultConfig);

  // 初始化统计信息
  FillChar(FStatistics, SizeOf(FStatistics), 0);
end;

destructor TOpenSSLLibrary.Destroy;
begin
  if FInitialized then
    Finalize;
  UnloadOpenSSLLibraries;
  inherited Destroy;
end;

// ============================================================================
// 内部方法实现
// ============================================================================

procedure TOpenSSLLibrary.InternalLog(ALevel: TSSLLogLevel; const AMessage: string);
begin
  if Assigned(FLogCallback) and (ALevel <= FLogLevel) then
    FLogCallback(ALevel, AMessage);
end;

function TOpenSSLLibrary.LoadOpenSSLLibraries: Boolean;
var
  CryptoHandle, SSLHandle: TLibHandle;
begin
  // P0-1.1: 委托给 TOpenSSLLoader 进行加载
  Result := False;

  InternalLog(sslLogInfo, 'Loading OpenSSL libraries via TOpenSSLLoader...');

  // 触发 TOpenSSLLoader 加载库
  CryptoHandle := TOpenSSLLoader.GetLibraryHandle(osslLibCrypto);
  SSLHandle := TOpenSSLLoader.GetLibraryHandle(osslLibSSL);

  if CryptoHandle = 0 then
  begin
    SetError(-1, 'Failed to load libcrypto via TOpenSSLLoader');
    InternalLog(sslLogError, FLastErrorString);
    Exit;
  end;

  if SSLHandle = 0 then
  begin
    SetError(-1, 'Failed to load libssl via TOpenSSLLoader');
    InternalLog(sslLogError, FLastErrorString);
    Exit;
  end;

  InternalLog(sslLogInfo, 'OpenSSL libraries loaded successfully via TOpenSSLLoader');

  // Note: API functions will be loaded on-demand by the api modules
  // No need to explicitly load all functions here

  Result := True;
end;

procedure TOpenSSLLibrary.UnloadOpenSSLLibraries;
begin
  // P0-1.1: 委托给 TOpenSSLLoader 卸载库
  // 注意: 不在此处卸载，因为 TOpenSSLLoader 是全局共享的
  // 卸载应该由 TOpenSSLLoader.UnloadLibraries 处理
  InternalLog(sslLogInfo, 'UnloadOpenSSLLibraries called (delegated to TOpenSSLLoader)');
end;

function TOpenSSLLibrary.DetectOpenSSLVersion: Boolean;
var
  LInfo: TOpenSSLVersionInfo;
  LVersionStr: PAnsiChar;
begin
  Result := False;
  FVersionNumber := 0;
  FVersionString := '';

  try
    // Ensure core bindings are loaded (OpenSSL_version_num/OpenSSL_version).
    if not TOpenSSLLoader.IsModuleLoaded(osmCore) then
      LoadOpenSSLCore;

    // Prefer OpenSSL runtime version functions.
    if Assigned(OpenSSL_version_num) then
      FVersionNumber := OpenSSL_version_num();

    if Assigned(OpenSSL_version) then
    begin
      // OPENSSL_VERSION = 0 (avoid name collision with OpenSSL_version symbol in Pascal)
      LVersionStr := OpenSSL_version(0);
      if LVersionStr <> nil then
        FVersionString := string(LVersionStr);
    end;

    // Fallback to loader-detected version string when core API doesn't provide it.
    if FVersionString = '' then
    begin
      LInfo := TOpenSSLLoader.GetVersionInfo;
      FVersionString := LInfo.VersionString;
    end;

    if FVersionString = '' then
      FVersionString := GetOpenSSLVersionString;

    if FVersionNumber <> 0 then
      InternalLog(sslLogInfo,
        Format('OpenSSL version: %s (0x%s)', [FVersionString, IntToHex(FVersionNumber, 8)]))
    else
      InternalLog(sslLogInfo, Format('OpenSSL version: %s', [FVersionString]));

    Result := True;
  except
    on E: Exception do
    begin
      SetError(-1, Format('OpenSSL version detection failed: %s', [E.Message]));
      InternalLog(sslLogWarning, FLastErrorString);
    end;
  end;
end;

procedure TOpenSSLLibrary.SetError(AError: Integer; const AErrorMsg: string);
begin
  FLastError := AError;
  FLastErrorString := AErrorMsg;
end;

procedure TOpenSSLLibrary.ClearInternalError;
begin
  FLastError := 0;
  FLastErrorString := '';
end;

// v1.2.0: 能力矩阵缓存失效
procedure TOpenSSLLibrary.InvalidateCapabilitiesCache;
begin
  FCapabilitiesCached := False;
  FillChar(FCapabilitiesCache, SizeOf(FCapabilitiesCache), 0);
end;

function OpenSSLEarlyDataSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_CTX_set_max_early_data) and
    Assigned(SSL_CTX_get_max_early_data) and
    Assigned(SSL_set_max_early_data) and
    Assigned(SSL_get_max_early_data) and
    Assigned(SSL_get_early_data_status);
end;

function OpenSSLChaChaPolySurfaceReady: Boolean;
const
  CHACHA_TLS13_CIPHERSUITE = 'TLS_CHACHA20_POLY1305_SHA256';
var
  LCipherAnsi: AnsiString;
  LMethod: PSSL_METHOD;
  LCtx: PSSL_CTX;
begin
  Result := False;

  if not Assigned(TLS_method) or not Assigned(SSL_CTX_new) then
    Exit;

  LMethod := TLS_method();
  if LMethod = nil then
    Exit;

  LCtx := SSL_CTX_new(LMethod);
  if LCtx = nil then
    Exit;

  try
    LCipherAnsi := AnsiString(CHACHA_TLS13_CIPHERSUITE);

    if Assigned(SSL_CTX_set_cipher_list) then
      Result := SSL_CTX_set_cipher_list(LCtx, PAnsiChar(LCipherAnsi)) = 1;

    if (not Result) and Assigned(SSL_CTX_set_ciphersuites) then
      Result := SSL_CTX_set_ciphersuites(LCtx, PAnsiChar(LCipherAnsi)) = 1;
  finally
    if Assigned(SSL_CTX_free) then
      SSL_CTX_free(LCtx);
  end;
end;

function OpenSSLSNISurfaceReady: Boolean;
begin
  Result := Assigned(SSL_set_tlsext_host_name) or
    Assigned(SSL_CTX_set_tlsext_servername_callback);
end;

function OpenSSLALPNSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_CTX_set_alpn_protos) and
    Assigned(SSL_get0_alpn_selected);
end;

function OpenSSLSessionTicketSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_CTX_set_tlsext_ticket_key_cb) or
    Assigned(SSL_set_session_ticket_ext_cb);
end;

function OpenSSLSessionCacheSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_CTX_set_session_cache_mode) and
    Assigned(SSL_CTX_get_session_cache_mode);
end;

function OpenSSLRenegotiationSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_renegotiate);
end;

function OpenSSLOCSPStaplingSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_CTX_set_tlsext_status_type) and
    Assigned(SSL_CTX_set_tlsext_status_cb);
end;

function OpenSSLPostHandshakeAuthSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_CTX_set_post_handshake_auth) and
    Assigned(SSL_set_post_handshake_auth) and
    Assigned(SSL_verify_client_post_handshake);
end;

function OpenSSLPKCS12SurfaceReady: Boolean;
begin
  Result := Assigned(PKCS12_create) and
    Assigned(PKCS12_parse) and
    Assigned(d2i_PKCS12_bio) and
    Assigned(i2d_PKCS12_bio);
end;

function OpenSSLPrivateKeyFileSurfaceReady: Boolean;
begin
  Result := Assigned(SSL_CTX_use_PrivateKey_file);
end;

function OpenSSLPrivateKeyReadSurfaceReady: Boolean;
begin
  if (not Assigned(PEM_read_bio_PrivateKey)) and
    (not TOpenSSLLoader.IsModuleLoaded(osmPEM)) then
    LoadOpenSSLPEM(GetCryptoLibHandle);

  Result := Assigned(PEM_read_bio_PrivateKey) and
    Assigned(BIO_free) and
    (Assigned(BIO_new_file) or Assigned(BIO_new_mem_buf));
end;

function OpenSSLPasswordProtectedKeySurfaceReady: Boolean;
begin
  Result := OpenSSLPrivateKeyReadSurfaceReady;
end;

function OpenSSLDERPKCS8PrivateKeySurfaceReady: Boolean;
begin
  if ((not Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO)) or
      (not Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY))) and
    (not TOpenSSLLoader.IsModuleLoaded(osmPKCS)) then
    LoadOpenSSLPKCS(GetCryptoLibHandle);

  Result := Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO) and
    Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY);
end;

function OpenSSLEncryptedDERPKCS8PrivateKeySurfaceReady: Boolean;
begin
  if ((not Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG)) or
      (not Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY))) and
    (not TOpenSSLLoader.IsModuleLoaded(osmPKCS)) then
    LoadOpenSSLPKCS(GetCryptoLibHandle);

  if (not Assigned(nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt)) and
    (not TOpenSSLLoader.IsModuleLoaded(osmPKCS12)) then
    LoadPKCS12Module(GetCryptoLibHandle);

  Result := Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG) and
    Assigned(nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt) and
    Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY);
end;

function OpenSSLDERPKCS1PrivateKeySurfaceReady: Boolean;
begin
  if (not Assigned(d2i_RSAPrivateKey)) and
    (not TOpenSSLLoader.IsModuleLoaded(osmRSA)) then
    LoadOpenSSLRSA;

  if ((not Assigned(EVP_PKEY_new)) or
      (not Assigned(EVP_PKEY_set1_RSA))) and
    (not TOpenSSLLoader.IsModuleLoaded(osmEVP)) then
    LoadEVP(GetCryptoLibHandle);

  Result := Assigned(d2i_RSAPrivateKey) and
    Assigned(EVP_PKEY_new) and
    Assigned(EVP_PKEY_set1_RSA);
end;

function OpenSSLDERSEC1ECPrivateKeySurfaceReady: Boolean;
begin
  if (not Assigned(d2i_ECPrivateKey)) and
    (not TOpenSSLLoader.IsModuleLoaded(osmEC)) then
    LoadECFunctions(GetCryptoLibHandle);

  if ((not Assigned(EVP_PKEY_new)) or
      (not Assigned(EVP_PKEY_set1_EC_KEY))) and
    (not TOpenSSLLoader.IsModuleLoaded(osmEVP)) then
    LoadEVP(GetCryptoLibHandle);

  Result := Assigned(d2i_ECPrivateKey) and
    Assigned(EC_KEY_free) and
    Assigned(EVP_PKEY_new) and
    Assigned(EVP_PKEY_set1_EC_KEY);
end;

function OpenSSLDERPrivateKeySurfaceReady: Boolean;
begin
  Result := OpenSSLDERPKCS8PrivateKeySurfaceReady or
    OpenSSLEncryptedDERPKCS8PrivateKeySurfaceReady or
    OpenSSLDERPKCS1PrivateKeySurfaceReady or
    OpenSSLDERSEC1ECPrivateKeySurfaceReady;
end;

// ============================================================================
// ISSLLibrary - 初始化和清理
// ============================================================================

function TOpenSSLLibrary.Initialize: Boolean;
begin
  Result := False;
  
  if FInitialized then
  begin
    InternalLog(sslLogWarning, 'OpenSSL library already initialized');
    Exit(True);
  end;
  
  InternalLog(sslLogInfo, 'Initializing OpenSSL library...');
  ClearInternalError;
  
  // 加载OpenSSL动态库
  if not LoadOpenSSLLibraries then
    Exit(False);

  try
    LoadOpenSSLCore;
  except
    on E: Exception do
    begin
      SetError(-1, Format('OpenSSL core initialization failed: %s', [E.Message]));
      InternalLog(sslLogError, FLastErrorString);
      Exit(False);
    end;
  end;
  
  // 检测OpenSSL版本
  if not DetectOpenSSLVersion then
    Exit(False);
  
  // 初始化OpenSSL
  try
    // OpenSSL will auto-initialize on first use in modern versions
    // For older versions, initialization is handled by api modules
    
    // 加载所有必需的 API 模块
    InternalLog(sslLogInfo, 'Loading OpenSSL API modules...');
    LoadOpenSSLBIO;    // 加载 BIO API (I/O 操作需要)
    LoadOpenSSLX509;   // 加载 X509 API (证书操作需要)
    LoadEVP(GetCryptoLibHandle);          // 加载 EVP 摘要/加密 API（指纹等功能需要）
    LoadOpenSSLASN1(GetCryptoLibHandle);  // 加载 ASN1 API（时间与字符串解析需要）
    LoadX509V3Functions(GetCryptoLibHandle);
    LoadOpenSSLSSL;    // 加载 SSL 高层 API (状态、ALPN、Cipher 列表等)
    LoadOpenSSLERR;    // 加载错误处理 API (ERR_get_error 等)
    LoadOpenSSLHMAC;   // 加载 HMAC API (HKDF 等密钥派生功能需要)
    LoadTSFunctions;   // 加载 TSA API (时间戳功能需要)
    LoadPKCS12Module(GetCryptoLibHandle); // 加载 PKCS#12 API
    LoadOpenSSLOCSP(GetCryptoLibHandle);  // 加载 OCSP API
    
    FInitialized := True;
    InternalLog(sslLogInfo, 'OpenSSL library initialized successfully');
    Result := True;
  except
    on E: Exception do
    begin
      SetError(-1, Format('OpenSSL initialization failed: %s', [E.Message]));
      InternalLog(sslLogError, FLastErrorString);
    end;
  end;
end;

procedure TOpenSSLLibrary.Finalize;
begin
  if not FInitialized then
    Exit;

  InternalLog(sslLogInfo, 'Finalizing OpenSSL library...');

  // v1.2.0: 失效能力矩阵缓存
  InvalidateCapabilitiesCache;

  // OpenSSL 1.1.0+ auto-cleans on exit
  // Manual cleanup not required

  FInitialized := False;
  InternalLog(sslLogInfo, 'OpenSSL library finalized');
end;

function TOpenSSLLibrary.IsInitialized: Boolean;
begin
  Result := FInitialized;
end;

// ============================================================================
// ISSLLibrary - 版本信息
// ============================================================================

function TOpenSSLLibrary.GetLibraryType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TOpenSSLLibrary.GetVersionString: string;
begin
  Result := FVersionString;
end;

function TOpenSSLLibrary.GetVersionNumber: Cardinal;
begin
  Result := FVersionNumber;
end;

function TOpenSSLLibrary.GetCompileFlags: string;
begin
  Result := 'OpenSSL';
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
  {$IFDEF LINUX}
  Result := Result + ', Linux';
  {$ENDIF}
  {$IFDEF DARWIN}
  Result := Result + ', macOS';
  {$ENDIF}
  {$IFDEF ANDROID}
  Result := Result + ', Android';
  {$ENDIF}
end;

// ============================================================================
// ISSLLibrary - 功能支持查询
// ============================================================================


function ProtocolToOpenSSLVersion(AProtocol: TSSLProtocolVersion): Integer;
const
  OSSL_TLS1_VERSION = $0301;
  OSSL_TLS1_1_VERSION = $0302;
  OSSL_TLS1_2_VERSION = $0303;
  OSSL_TLS1_3_VERSION = $0304;
  OSSL_DTLS1_VERSION = $FEFF;
  OSSL_DTLS1_2_VERSION = $FEFD;
begin
  case AProtocol of
    sslProtocolTLS10: Result := OSSL_TLS1_VERSION;
    sslProtocolTLS11: Result := OSSL_TLS1_1_VERSION;
    sslProtocolTLS12: Result := OSSL_TLS1_2_VERSION;
    sslProtocolTLS13: Result := OSSL_TLS1_3_VERSION;
    sslProtocolDTLS10: Result := OSSL_DTLS1_VERSION;
    sslProtocolDTLS12: Result := OSSL_DTLS1_2_VERSION;
  else
    Result := 0;
  end;
end;

function RuntimeProbeMethodForProtocol(AProtocol: TSSLProtocolVersion): PSSL_METHOD;
begin
  Result := nil;

  case AProtocol of
    sslProtocolTLS10,
    sslProtocolTLS11,
    sslProtocolTLS12,
    sslProtocolTLS13:
      if Assigned(TLS_method) then
        Result := TLS_method();

    sslProtocolDTLS10,
    sslProtocolDTLS12:
      begin
        if Assigned(DTLS_method) then
          Result := DTLS_method();
        if (Result = nil) and Assigned(DTLS_client_method) then
          Result := DTLS_client_method();
        if (Result = nil) and Assigned(DTLS_server_method) then
          Result := DTLS_server_method();
      end;
  else
    Result := nil;
  end;
end;

function RuntimeProbeProtocolSupport(AProtocol: TSSLProtocolVersion; AVersionNumber: Cardinal): Boolean;
var
  LMethod: PSSL_METHOD;
  LCtx: PSSL_CTX;
  LProtocolVersion: Integer;
begin
  Result := False;

  LProtocolVersion := ProtocolToOpenSSLVersion(AProtocol);
  if LProtocolVersion = 0 then
    Exit;

  case AProtocol of
    sslProtocolTLS10,
    sslProtocolTLS11,
    sslProtocolTLS12,
    sslProtocolTLS13:
      begin
        if not Assigned(TLS_method) or not Assigned(SSL_CTX_new) or not Assigned(SSL_CTX_free) then
        begin
          case AProtocol of
            sslProtocolTLS10:
              Result := (AVersionNumber >= $10000000);
            sslProtocolTLS11,
            sslProtocolTLS12:
              Result := (AVersionNumber >= $10001000);
            sslProtocolTLS13:
              Result := (AVersionNumber >= $1010100F);
          else
            Result := False;
          end;
          Exit;
        end;
      end;

    sslProtocolDTLS10,
    sslProtocolDTLS12:
      begin
        if not Assigned(SSL_CTX_new) or not Assigned(SSL_CTX_free) then
          Exit;
      end;
  else
    Exit;
  end;

  LMethod := RuntimeProbeMethodForProtocol(AProtocol);
  if LMethod = nil then
    Exit;

  LCtx := SSL_CTX_new(LMethod);
  if LCtx = nil then
    Exit;

  try
    if Assigned(SSL_CTX_set_min_proto_version) and
      (SSL_CTX_set_min_proto_version(LCtx, LProtocolVersion) <> 1) then
      Exit;

    if Assigned(SSL_CTX_set_max_proto_version) and
      (SSL_CTX_set_max_proto_version(LCtx, LProtocolVersion) <> 1) then
      Exit;

    Result := True;
  finally
    SSL_CTX_free(LCtx);
  end;
end;

function TOpenSSLLibrary.IsProtocolSupported(AProtocol: TSSLProtocolVersion): Boolean;
begin
  Result := False;

  if not FInitialized then
    Exit;

  case AProtocol of
    sslProtocolSSL2,
    sslProtocolSSL3:
      Result := False;  // SSL 2.0/3.0 已废弃

    sslProtocolTLS10,
    sslProtocolTLS11,
    sslProtocolTLS12,
    sslProtocolTLS13,
    sslProtocolDTLS10,
    sslProtocolDTLS12:
      Result := RuntimeProbeProtocolSupport(AProtocol, FVersionNumber);
  else
    Result := False;
  end;
end;
function TOpenSSLLibrary.IsCipherSupported(const ACipherName: string): Boolean;
var
  LCipherName: string;
  LCipherAnsi: AnsiString;
  LMethod: PSSL_METHOD;
  LCtx: PSSL_CTX;
begin
  Result := False;

  if not FInitialized then
    Exit;

  LCipherName := Trim(ACipherName);
  if LCipherName = '' then
    Exit;

  // Runtime-accurate check: ask OpenSSL parser instead of keyword heuristics
  if not Assigned(TLS_method) or not Assigned(SSL_CTX_new) then
    Exit;

  LMethod := TLS_method();
  if LMethod = nil then
    Exit;

  LCtx := SSL_CTX_new(LMethod);
  if LCtx = nil then
    Exit;

  try
    LCipherAnsi := AnsiString(LCipherName);

    if Assigned(SSL_CTX_set_cipher_list) then
      Result := SSL_CTX_set_cipher_list(LCtx, PAnsiChar(LCipherAnsi)) = 1;

    // TLS 1.3 ciphersuites use a dedicated parser API
    if (not Result) and Assigned(SSL_CTX_set_ciphersuites) then
      Result := SSL_CTX_set_ciphersuites(LCtx, PAnsiChar(LCipherAnsi)) = 1;
  finally
    if Assigned(SSL_CTX_free) then
      SSL_CTX_free(LCtx);
  end;
end;

{ 类型安全版本（Phase 1.3 - Rust质量标准） }
{$WARN 6018 OFF}
function TOpenSSLLibrary.IsFeatureSupported(AFeature: TSSLFeature): Boolean;
begin
  if not FInitialized then
    Exit(False);

  case AFeature of
    sslFeatSNI:
      Result := Assigned(SSL_set_tlsext_host_name) or
        Assigned(SSL_CTX_set_tlsext_servername_callback);

    sslFeatALPN:
      Result := Assigned(SSL_CTX_set_alpn_protos) and
        Assigned(SSL_get0_alpn_selected);

    sslFeatSessionCache:
      Result := Assigned(SSL_CTX_set_session_cache_mode) and
        Assigned(SSL_CTX_get_session_cache_mode);

    sslFeatSessionTickets:
      Result := Assigned(SSL_CTX_set_tlsext_ticket_key_cb) or
        Assigned(SSL_set_session_ticket_ext_cb);

    sslFeatRenegotiation:
      Result := Assigned(SSL_renegotiate);

    sslFeatOCSPStapling:
      Result := Assigned(SSL_CTX_set_tlsext_status_type) and
        Assigned(SSL_CTX_set_tlsext_status_cb);

    sslFeatCertificateTransparency:
      Result := False;
  else
    Result := False;
  end;

  InternalLog(sslLogDebug, Format('Feature support check (type-safe): %d = %s',
    [Ord(AFeature), BoolToStr(Result, True)]));
end;
{$WARN 6018 ON}
function TOpenSSLLibrary.GetCapabilities: TSSLBackendCapabilities;
var
  LTLS13Ready: Boolean;
  LDTLS10Ready: Boolean;
  LDTLS12Ready: Boolean;
  LSNIReady: Boolean;
  LALPNReady: Boolean;
  LSessionTicketsReady: Boolean;
  LSessionCacheReady: Boolean;
  LRenegotiationReady: Boolean;
  LOCSPStaplingReady: Boolean;
  LChaChaPolyReady: Boolean;
  LPKCS12Ready: Boolean;
  LPrivateKeyFileReady: Boolean;
  LPrivateKeyReadReady: Boolean;
  LPEMPrivateKeyReady: Boolean;
  LDERPKCS8PrivateKeyReady: Boolean;
  LEncryptedDERPKCS8PrivateKeyReady: Boolean;
  LDERPrivateKeyReady: Boolean;
  LPKCS8PrivateKeyReady: Boolean;
  LPasswordProtectedKeysReady: Boolean;
  LPKCS11Ready: Boolean;
begin
  // P2-2 + v1.2: 返回 OpenSSL 后端完整能力矩阵（带缓存）

  // v1.2.0: 如果已缓存，直接返回缓存值
  if FCapabilitiesCached then
  begin
    Result := FCapabilitiesCache;
    Exit;
  end;

  // 生成能力矩阵
  FillChar(Result, SizeOf(Result), 0);

  LTLS13Ready := IsProtocolSupported(sslProtocolTLS13);
  LDTLS10Ready := IsProtocolSupported(sslProtocolDTLS10);
  LDTLS12Ready := IsProtocolSupported(sslProtocolDTLS12);
  LSNIReady := OpenSSLSNISurfaceReady;
  LALPNReady := OpenSSLALPNSurfaceReady;
  LSessionTicketsReady := OpenSSLSessionTicketSurfaceReady;
  LSessionCacheReady := OpenSSLSessionCacheSurfaceReady;
  LRenegotiationReady := OpenSSLRenegotiationSurfaceReady;
  LOCSPStaplingReady := OpenSSLOCSPStaplingSurfaceReady;
  LChaChaPolyReady := OpenSSLChaChaPolySurfaceReady;
  LPKCS12Ready := OpenSSLPKCS12SurfaceReady;
  LPrivateKeyFileReady := OpenSSLPrivateKeyFileSurfaceReady;
  LPrivateKeyReadReady := OpenSSLPrivateKeyReadSurfaceReady;
  LPEMPrivateKeyReady := LPrivateKeyFileReady or LPrivateKeyReadReady;
  LDERPKCS8PrivateKeyReady := OpenSSLDERPKCS8PrivateKeySurfaceReady;
  LEncryptedDERPKCS8PrivateKeyReady := OpenSSLEncryptedDERPKCS8PrivateKeySurfaceReady;
  LDERPrivateKeyReady := LDERPKCS8PrivateKeyReady or
    LEncryptedDERPKCS8PrivateKeyReady or
    OpenSSLDERPKCS1PrivateKeySurfaceReady or
    OpenSSLDERSEC1ECPrivateKeySurfaceReady;
  LPKCS8PrivateKeyReady := LPEMPrivateKeyReady or
    LDERPKCS8PrivateKeyReady or
    LEncryptedDERPKCS8PrivateKeyReady;
  LPasswordProtectedKeysReady := OpenSSLPasswordProtectedKeySurfaceReady or
    LEncryptedDERPKCS8PrivateKeyReady;
  LPKCS11Ready := TPKCS11BackendFactory.IsBackendAvailable(btAuto);

  // ===== v1.1.0 保留字段（向后兼容）=====

  // TLS 1.3 support must follow the runtime protocol probe
  Result.SupportsTLS13 := LTLS13Ready;

  // OpenSSL 原生支持的特性
  Result.SupportsECDHE := True;

  // ChaCha20-Poly1305 需要真实 ciphersuite parser ready
  Result.SupportsChaChaPoly := LChaChaPolyReady;

  // 私钥格式支持要跟随当前真实加载表面，不能再按 OpenSSL 品牌静态发布
  Result.SupportsPEMPrivateKey := LPEMPrivateKeyReady;

  // 支持的协议版本范围
  Result.MinTLSVersion := sslProtocolTLS10;  // 可通过配置禁用
  if LTLS13Ready then
    Result.MaxTLSVersion := sslProtocolTLS13
  else
    Result.MaxTLSVersion := sslProtocolTLS12;

  // ===== v1.2.0 新增字段 =====

  // ----- 基础信息 -----
  Result.BackendType := sslOpenSSL;
  Result.BackendImplType := sslImplCLibrary;  // OpenSSL 是 C 库绑定
  Result.BackendVersion := GetVersionString;

  // ----- 协议支持 -----
  Result.SupportsDTLS := LDTLS10Ready or LDTLS12Ready;

  // ----- 高级特性支持（带支持级别）-----
  if LSNIReady then
    Result.SNISupport := sslSupportStable
  else
    Result.SNISupport := sslSupportNone;

  if LALPNReady then
    Result.ALPNSupport := sslSupportStable
  else
    Result.ALPNSupport := sslSupportNone;

  if LOCSPStaplingReady then
    Result.OCSPStaplingSupport := sslSupportStable
  else
    Result.OCSPStaplingSupport := sslSupportNone;

  // 当前默认 OpenSSL backend 还没有发布 connection-level CT / validation public surface
  Result.CertTransparencySupport := sslSupportNone;

  if LSessionTicketsReady then
    Result.SessionTicketsSupport := sslSupportStable
  else
    Result.SessionTicketsSupport := sslSupportNone;

  if LSessionCacheReady then
    Result.SessionCacheSupport := sslSupportStable
  else
    Result.SessionCacheSupport := sslSupportNone;

  // 0-RTT 和 Early Data（仅 TLS 1.3）
  if LTLS13Ready and OpenSSLEarlyDataSurfaceReady then
  begin
    Result.ZeroRTTSupport := sslSupportStable;
    Result.EarlyDataSupport := sslSupportStable;
  end
  else
  begin
    Result.ZeroRTTSupport := sslSupportNone;
    Result.EarlyDataSupport := sslSupportNone;
  end;

  // 重新协商（TLS 1.2）- OpenSSL 3.0 已弃用
  if not LRenegotiationReady then
    Result.RenegotiationSupport := sslSupportNone
  else if FVersionNumber >= $30000000 then
    Result.RenegotiationSupport := sslSupportDeprecated
  else
    Result.RenegotiationSupport := sslSupportStable;

  // 握手后认证（TLS 1.3）
  if LTLS13Ready and OpenSSLPostHandshakeAuthSurfaceReady then
    Result.PostHandshakeAuthSupport := sslSupportStable
  else
    Result.PostHandshakeAuthSupport := sslSupportNone;

  // ----- 算法支持（细粒度）-----
  Result.SupportedCiphers := [
    sslCipherAES128, sslCipherAES256,
    sslCipherAES128GCM, sslCipherAES256GCM
  ];

  // 3DES 已弃用但仍支持（向后兼容）
  if FVersionNumber < $30000000 then
    Result.SupportedCiphers := Result.SupportedCiphers + [sslCipher3DES];

  // ChaCha20-Poly1305 需要 OpenSSL 1.1.0+
  if Result.SupportsChaChaPoly then
    Result.SupportedCiphers := Result.SupportedCiphers + [sslCipherCHACHA20_POLY1305];

  // RC4 和 DES 在 OpenSSL 3.0+ 中不再支持
  if FVersionNumber < $30000000 then
    Result.SupportedCiphers := Result.SupportedCiphers + [sslCipherRC4, sslCipherDES];

  Result.SupportedHashes := [
    sslHashSHA1,      // 已弃用但支持
    sslHashSHA224,
    sslHashSHA256, sslHashSHA384, sslHashSHA512
  ];

  // SHA3 和 BLAKE2 需要 OpenSSL 1.1.1+
  if FVersionNumber >= $1010100F then
    Result.SupportedHashes := Result.SupportedHashes +
      [sslHashSHA3_256, sslHashSHA3_512, sslHashBLAKE2b];

  // MD5 在 OpenSSL 3.0+ 中受限
  if FVersionNumber < $30000000 then
    Result.SupportedHashes := Result.SupportedHashes + [sslHashMD5];

  Result.SupportedKeyExchanges := [
    sslKexRSA,           // TLS 1.2 及以下，TLS 1.3 不支持
    sslKexDHE_RSA,
    sslKexECDHE_RSA,
    sslKexDHE_DSS,
    sslKexECDHE_ECDSA
  ];

  // ----- 性能特性 -----
  // 硬件加速：需要运行时检测 AES-NI 等
  Result.HasHardwareAcceleration := True;  // OpenSSL 自动检测并使用
  Result.HasSIMDOptimization := True;      // OpenSSL 包含 SIMD 优化
  Result.HasAssemblyOptimization := True;  // OpenSSL 包含汇编优化

  // ----- 平台特性 -----
  Result.RequiresExternalLibrary := True;  // 需要 libssl.so / libssl.dll
  {$IFDEF WINDOWS}
  Result.SupportsSystemCertStore := True;  // Windows 可访问系统证书
  {$ELSE}
  Result.SupportsSystemCertStore := False;
  {$ENDIF}
  Result.SupportsPKCS11 := LPKCS11Ready;   // shipped loader path exists, but capability must follow backend readiness
  Result.SupportsTPM := False;             // current backend does not publish a TPM public/runtime path

  // ----- 安全特性 -----
  Result.HasConstantTimeOperations := True;   // OpenSSL 实现恒定时间算法
  Result.SupportsFIPSMode := False;           // 默认构建不启用，需要 FIPS 模块
  Result.HasSecureMemoryWipe := True;         // OPENSSL_cleanse

  // ----- 证书和密钥支持 -----
  Result.SupportsDERPrivateKey := LDERPrivateKeyReady;
  Result.SupportsPKCS8PrivateKey := LPKCS8PrivateKeyReady;
  Result.SupportsPKCS12 := LPKCS12Ready;
  Result.SupportsPasswordProtectedKeys := LPasswordProtectedKeysReady;

  // ----- 扩展性 -----
  Result.SupportsCustomCipherSuites := OpenSSLPublishedCustomCipherSurfaceReady;
  Result.SupportsCallbacks := OpenSSLPublishedContextCallbackSurfaceReady;

  // ----- 兼容性和质量 -----
  Result.CompatibilityLevel := 100;  // OpenSSL 是参考实现，完全兼容
  Result.KnownIssues := '';

  NormalizeLegacyCapabilityBooleans(Result);

  InternalLog(sslLogDebug, Format('GetCapabilities: TLS1.3=%s, ALPN=%s, SNI=%s',
    [
      BoolToStr(Result.SupportsTLS13, True),
      BoolToStr(Result.SupportsALPN, True),
      BoolToStr(Result.SupportsSNI, True)
    ]));

  // v1.2.0: 缓存能力矩阵
  FCapabilitiesCache := Result;
  FCapabilitiesCached := True;
end;

// ============================================================================
// ISSLLibrary - 库配置
// ============================================================================

procedure TOpenSSLLibrary.SetDefaultConfig(const AConfig: TSSLConfig);
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

function TOpenSSLLibrary.GetDefaultConfig: TSSLConfig;
begin
  Result := FDefaultConfig;
end;

// ============================================================================
// ISSLLibrary - 错误处理
// ============================================================================

function TOpenSSLLibrary.GetLastError: Integer;
var
  LErr: Cardinal;
begin
  Result := FLastError;

  if Result = 0 then
  begin
    if not Assigned(ERR_peek_last_error) then
      LoadOpenSSLERR;

    if Assigned(ERR_peek_last_error) then
    begin
      try
        LErr := ERR_peek_last_error();
        if LErr <> 0 then
        begin
          FLastError := Integer(LErr);
          Result := FLastError;
        end;
      except
        on E: Exception do
          InternalLog(sslLogWarning, Format('Exception in GetLastError: %s', [E.Message]));
      end;
    end;
  end;
end;

function TOpenSSLLibrary.GetLastErrorString: string;
var
  ErrCode: Cardinal;
  ErrBuf: array[0..255] of AnsiChar;
  OpenSSLErrors: string;
begin
  Result := FLastErrorString;
  
  // Check OpenSSL error queue
  OpenSSLErrors := '';
  if Assigned(ERR_get_error) and Assigned(ERR_error_string_n) then
  begin
    ErrCode := ERR_get_error();
    while ErrCode <> 0 do
    begin
      ERR_error_string_n(ErrCode, @ErrBuf[0], SizeOf(ErrBuf));
      if OpenSSLErrors <> '' then
        OpenSSLErrors := OpenSSLErrors + ' | ';
      OpenSSLErrors := OpenSSLErrors + StrPas(@ErrBuf[0]);
      ErrCode := ERR_get_error();
    end;
  end;
  
  if OpenSSLErrors <> '' then
  begin
    if Result <> '' then
      Result := Result + ' | ' + OpenSSLErrors
    else
      Result := OpenSSLErrors;
  end;
  
  if Result = '' then
    Result := 'No SSL errors';
end;

procedure TOpenSSLLibrary.ClearError;
begin
  ClearInternalError;
  if Assigned(ERR_clear_error) then
    ERR_clear_error();
end;

// ============================================================================
// ISSLLibrary - 统计信息
// ============================================================================

function TOpenSSLLibrary.GetStatistics: TSSLStatistics;
begin
  Result := FStatistics;
end;

procedure TOpenSSLLibrary.ResetStatistics;
begin
  FillChar(FStatistics, SizeOf(FStatistics), 0);
  InternalLog(sslLogInfo, 'Statistics reset');
end;

// ============================================================================
// ISSLLibrary - 日志
// ============================================================================

procedure TOpenSSLLibrary.SetLogCallback(ACallback: TSSLLogCallback);
begin
  FLogCallback := ACallback;
  FDefaultConfig.LogCallback := ACallback;
end;

procedure TOpenSSLLibrary.Log(ALevel: TSSLLogLevel; const AMessage: string);
begin
  InternalLog(ALevel, AMessage);
end;

// ============================================================================
// ISSLLibrary - 工厂方法
// ============================================================================

function TOpenSSLLibrary.CreateContext(AType: TSSLContextType): ISSLContext;
var
  LConfig: TSSLConfig;
  LExposeEarlyData: Boolean;
  LExposeServerOCSP: Boolean;
  LVerifyMode: TSSLVerifyModes;
  Store: ISSLCertificateStore;
begin
  // Rust-quality: Explicit error handling instead of returning nil
  if not FInitialized then
    RaiseSSLInitError(
      'Cannot create context: OpenSSL library not initialized',
      'TOpenSSLLibrary.CreateContext'
    );

  LConfig := FDefaultConfig;
  LConfig.ContextType := AType;

  ValidateDirectLibraryConnectionScope(
    LConfig,
    'TOpenSSLLibrary.CreateContext'
  );

  if (AType = sslCtxServer) and (Trim(LConfig.ServerName) <> '') then
    raise ESSLConfigurationException.CreateWithContext(
      'ServerName is client-scoped. Server-side connections ignore context-level ServerName; ' +
      'remove it from TOpenSSLLibrary.CreateContext when creating server contexts.',
      sslErrConfiguration,
      'TOpenSSLLibrary.CreateContext',
      0,
      sslOpenSSL
    );

  ValidateContextReplayStoreConfigScope(
    LConfig,
    AType,
    'TOpenSSLLibrary.CreateContext'
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

  // Let exceptions propagate - caller must handle errors explicitly
  if LExposeEarlyData and LExposeServerOCSP then
    Result := TOpenSSLAdvancedContext.Create(Self, AType)
  else if LExposeEarlyData then
    Result := TOpenSSLEarlyDataContext.Create(Self, AType)
  else if LExposeServerOCSP then
    Result := TOpenSSLServerOCSPContext.Create(Self, AType)
  else
    Result := TOpenSSLContext.Create(Self, AType);

  // Apply default config (already normalized in constructor/SetDefaultConfig)
  if Result <> nil then
  begin
    if (LConfig.ProtocolVersions <> []) and (LConfig.ProtocolVersions <> Result.GetProtocolVersions) then
      Result.SetProtocolVersions(LConfig.ProtocolVersions);

    if (LConfig.PreferredVersion <> sslProtocolUnknown) and
      (LConfig.PreferredVersion <> Result.GetPreferredVersion) then
      Result.SetPreferredVersion(LConfig.PreferredVersion);

    if LVerifyMode <> Result.GetVerifyMode then
      Result.SetVerifyMode(LVerifyMode);

    if (LConfig.VerifyDepth > 0) and (LConfig.VerifyDepth <> Result.GetVerifyDepth) then
      Result.SetVerifyDepth(LConfig.VerifyDepth);

    if (LConfig.CipherList <> '') and (LConfig.CipherList <> Result.GetCipherList) then
      Result.SetCipherList(LConfig.CipherList);

    if (LConfig.CipherSuites <> '') and (LConfig.CipherSuites <> Result.GetCipherSuites) then
      Result.SetCipherSuites(LConfig.CipherSuites);

    if (LConfig.Options <> []) and (LConfig.Options <> Result.GetOptions) then
      Result.SetOptions(LConfig.Options);

    if (LConfig.SessionCacheSize > 0) and (LConfig.SessionCacheSize <> Result.GetSessionCacheSize) then
      Result.SetSessionCacheSize(LConfig.SessionCacheSize);

    if (LConfig.SessionTimeout > 0) and (LConfig.SessionTimeout <> Result.GetSessionTimeout) then
      Result.SetSessionTimeout(LConfig.SessionTimeout);

    if (ssoEnableSessionCache in LConfig.Options) <> Result.GetSessionCacheMode then
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
        'TOpenSSLLibrary.CreateContext received TSSLConfig.ServerName as deprecated context-level ' +
        'SNI compatibility; CreateContext ignores it for new contexts; prefer per-connection SNI via ' +
        'ISSLClientConnection.SetServerName or TSSLConnector.Connect*(..., ServerName).'
      );

    if (LConfig.ALPNProtocols <> '') and (LConfig.ALPNProtocols <> Result.GetALPNProtocols) then
      Result.SetALPNProtocols(LConfig.ALPNProtocols);

    ApplyEarlyDataContextConfig(Result, LConfig);
    ApplyEarlyDataReplayStoreConfig(Result, LConfig,
      'TOpenSSLLibrary.CreateContext');
  end;

  Inc(FStatistics.ConnectionsTotal);
  if AType = sslCtxClient then
    InternalLog(sslLogInfo, 'Created client context')
  else
    InternalLog(sslLogInfo, 'Created server context');
end;

function TOpenSSLLibrary.CreateCertificate: ISSLCertificate;
var
  LCert: PX509;
begin
  // Rust-quality: Explicit error handling
  if not FInitialized then
    RaiseSSLInitError(
      'Cannot create certificate: OpenSSL library not initialized',
      'TOpenSSLLibrary.CreateCertificate'
    );

  // Create a new empty X509 certificate
  LCert := X509_new();
  if LCert = nil then
    RaiseMemoryError('create X509 certificate');

  Result := TOpenSSLCertificate.Create(LCert, True);
end;

function TOpenSSLLibrary.CreateCertificateStore: ISSLCertificateStore;
begin
  // Rust-quality: Explicit error handling
  if not FInitialized then
    RaiseSSLInitError(
      'Cannot create certificate store: OpenSSL library not initialized',
      'TOpenSSLLibrary.CreateCertificateStore'
    );

  // Let exceptions propagate - caller must handle errors explicitly
  Result := TOpenSSLCertificateStore.Create;
end;

// ============================================================================
// 注册 OpenSSL 后端到工厂
// ============================================================================

procedure RegisterOpenSSLBackend;
begin
  // 在非Windows平台上注册 OpenSSL 后端
  // 优先级设为 100，作为默认选择
  TSSLFactory.RegisterLibrary(sslOpenSSL, @CreateOpenSSLLibrary,
    'OpenSSL (Cross-platform SSL/TLS)', 100);
end;

procedure UnregisterOpenSSLBackend;
begin
  TSSLFactory.UnregisterLibrary(sslOpenSSL);
end;

initialization
  RegisterOpenSSLBackend;

finalization
  UnregisterOpenSSLBackend;

end.
