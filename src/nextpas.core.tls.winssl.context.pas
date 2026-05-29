{
  nextpas.core.tls.winssl.context - WinSSL 上下文实现
  
  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-10-06
  
  描述:
    实现 ISSLContext 接口的 WinSSL 后端。
    负责 Schannel 凭据管理和连接创建。
}

unit nextpas.core.tls.winssl.context;

{$mode ObjFPC}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  Windows, SysUtils, Classes, StrUtils,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,      // 添加：RaiseInvalidParameter
  nextpas.core.tls.exceptions,  // 新增：类型化异常
  nextpas.core.tls.secure,      // 安全常量与 GetFileSizeByName
  nextpas.core.tls.logging,     // P1: 废弃协议警告
  nextpas.core.tls.winssl.base,
  nextpas.core.tls.winssl.api,
  nextpas.core.tls.winssl.utils,
  nextpas.core.tls.winssl.native_handle,
  nextpas.core.tls.cert.pinning;

type
  { TWinSSLContext - Windows Schannel 上下文类 }
  TWinSSLContext = class(TInterfacedObject, ISSLContext, ISSLNativeHandleAccess,
    IWinSSLContextAccess)
  private
    FLibrary: ISSLLibrary;
    FContextType: TSSLContextType;
    FCredHandle: CredHandle;
    FProtocolVersions: TSSLProtocolVersions;
    FPreferredVersion: TSSLProtocolVersion;
    FVerifyMode: TSSLVerifyModes;
    FVerifyDepth: Integer;
    FServerName: string;
    FCipherList: string;
    FCipherSuites: string;
    FALPNProtocols: string;
    FInitialized: Boolean;
    FOptions: TSSLOptions;
    FCertVerifyFlags: TSSLCertVerifyFlags;

    // 证书相关
    FCertContext: PCCERT_CONTEXT;
    FCertStore: HCERTSTORE;
    FCAStore: HCERTSTORE;  // P0-2: CA 证书内存存储
    FExternalCertStore: ISSLCertificateStore;  // 保持外部证书存储的引用
    FSessionCacheEnabled: Boolean;
    FSessionTimeout: Integer;
    FSessionCacheSize: Integer;

    // 回调
    FVerifyCallback: TSSLVerifyCallback;
    FPasswordCallback: TSSLPasswordCallback;
    FInfoCallback: TSSLInfoCallback;

    // P0-1: 延迟初始化支持
    FCredentialsNeedRebuild: Boolean;  // 标记凭据需要重建
    FCredentialsAcquired: Boolean;     // 凭据是否已获取
    
    // 证书固定
    FPinValidator: TPinValidator;
    FPinningEnabled: Boolean;

    procedure CleanupCertificate;
    procedure ApplyOptions;
    { P0-1: 延迟凭据获取 - 确保证书加载后才获取凭据 }
    procedure EnsureCredentialsAcquired;
    { P1: 统一上下文验证模式 - 与 OpenSSL 保持一致 }
    procedure RequireValidContext(const AMethodName: string);
    { P1: PEM→DER 转换 - 消除跨平台差异 }
    function PEMToDER(const APEM: string): TBytes;
    procedure RejectUnsupportedCallbackAssignment(
      const AFeature, AMethodName: string);
    procedure RejectUnsupportedCustomCipherAssignment(
      const AFeature, AMethodName: string);

  public
    constructor Create(ALibrary: ISSLLibrary; AType: TSSLContextType);
    destructor Destroy; override;
    
    { ISSLContext - 基本配置 }
    function GetContextType: TSSLContextType;
    procedure SetProtocolVersions(AVersions: TSSLProtocolVersions);
    function GetProtocolVersions: TSSLProtocolVersions;
    procedure SetPreferredVersion(AVersion: TSSLProtocolVersion);
    function GetPreferredVersion: TSSLProtocolVersion;
    
    { ISSLContext - 证书和密钥管理 }
    procedure LoadCertificate(const AFileName: string); overload;
    procedure LoadCertificate(AStream: TStream); overload;
    procedure LoadCertificate(ACert: ISSLCertificate); overload;
    procedure LoadPrivateKey(const AFileName: string; const APassword: string = ''); overload;
    procedure LoadPrivateKey(AStream: TStream; const APassword: string = ''); overload;
    procedure LoadCertificatePEM(const APEM: string);
    procedure LoadPrivateKeyPEM(const APEM: string; const APassword: string = '');
    procedure LoadCAFile(const AFileName: string);
    procedure LoadCAPath(const APath: string);
    procedure SetCertificateStore(AStore: ISSLCertificateStore);
    
    { ISSLContext - 验证配置 }
    procedure SetVerifyMode(AMode: TSSLVerifyModes);
    function GetVerifyMode: TSSLVerifyModes;
    procedure SetVerifyDepth(ADepth: Integer);
    function GetVerifyDepth: Integer;
    procedure SetVerifyCallback(ACallback: TSSLVerifyCallback);
    
    { ISSLContext - 密码套件配置 }
    procedure SetCipherList(const ACipherList: string);
    function GetCipherList: string;
    procedure SetCipherSuites(const ACipherSuites: string);
    function GetCipherSuites: string;
    
    { ISSLContext - 会话管理 }
    procedure SetSessionCacheMode(AEnabled: Boolean);
    function GetSessionCacheMode: Boolean;
    procedure SetSessionTimeout(ATimeout: Integer);
    function GetSessionTimeout: Integer;
    procedure SetSessionCacheSize(ASize: Integer);
    function GetSessionCacheSize: Integer;
    
    { ISSLContext - 高级选项 }
    procedure SetOptions(const AOptions: TSSLOptions);
    function GetOptions: TSSLOptions;
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;
    procedure SetALPNProtocols(const AProtocols: string);
    function GetALPNProtocols: string;

    { ISSLContext - 证书验证标志 }
    procedure SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
    function GetCertVerifyFlags: TSSLCertVerifyFlags;

    { ISSLContext - 回调设置 }
    procedure SetPasswordCallback(ACallback: TSSLPasswordCallback);
    procedure SetInfoCallback(ACallback: TSSLInfoCallback);

    { P1-7: 回调获取（供连接使用） }
    function GetVerifyCallback: TSSLVerifyCallback;
    function GetInfoCallback: TSSLInfoCallback;
    
    { ISSLContext - 证书固定 }
    procedure AddCertificatePin(const AHash: TBytes; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure SetCertificatePinningEnabled(AEnabled: Boolean);
    function GetCertificatePinningEnabled: Boolean;
    procedure ClearCertificatePins;

    { ISSLContext - 创建连接 }
    function CreateConnection(ASocket: THandle): ISSLConnection; overload;
    function CreateConnection(AStream: TStream): ISSLConnection; overload;
    
    { ISSLContext - 状态查询 }
    function IsValid: Boolean;

    { ISSLNativeHandleAccess implementation }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    { P0-2: 获取 CA 证书存储句柄（供连接验证使用） }
    function GetCAStoreHandle: HCERTSTORE;

    { Phase 3.3: 获取库实例（供连接更新统计使用） }
    function GetLibrary: ISSLLibrary;

    { WinSSL 内部 access interface }
    function GetWinSSLVerifyCallback: TSSLVerifyCallback;
    function GetWinSSLInfoCallback: TSSLInfoCallback;
    function GetWinSSLCAStoreHandle: Pointer;
    function GetWinSSLLibrary: ISSLLibrary;
  end;

implementation

uses
  nextpas.core.tls.winssl.connection;

// ============================================================================
// TWinSSLContext - 构造和析构
// ============================================================================

constructor TWinSSLContext.Create(ALibrary: ISSLLibrary; AType: TSSLContextType);
begin
  inherited Create;
  FLibrary := ALibrary;
  FContextType := AType;
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FPreferredVersion := sslProtocolTLS13;
  FVerifyMode := [sslVerifyPeer];
  FVerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  FServerName := '';
  FCipherList := '';
  FCipherSuites := '';
  FALPNProtocols := '';
  FInitialized := False;
  FOptions := [ssoEnableSessionCache, ssoEnableSessionTickets];
  FCertVerifyFlags := [sslCertVerifyDefault];

  // 证书相关初始化
  FCertContext := nil;
  FCertStore := nil;
  FCAStore := nil;  // P0-2: CA 证书内存存储
  FExternalCertStore := nil;
  FSessionCacheEnabled := True;
  FSessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FSessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;

  // 回调初始化
  FVerifyCallback := nil;
  FPasswordCallback := nil;
  FInfoCallback := nil;

  // 初始化证书固定
  FPinValidator := TPinValidator.Create;
  FPinningEnabled := False;

  // P0-1: 延迟初始化 - 不在构造函数中获取凭据
  // 凭据将在 CreateConnection 或 GetNativeHandle 时获取
  FCredentialsAcquired := False;
  FCredentialsNeedRebuild := True;  // 标记需要构建凭据

  InitSecHandle(FCredHandle);

  // P0-1: 移除立即获取凭据的代码
  // 凭据获取移至 EnsureCredentialsAcquired 方法
  FInitialized := True;  // 上下文已初始化，但凭据尚未获取
  ApplyOptions;
end;

destructor TWinSSLContext.Destroy;
begin
  CleanupCertificate;
  // P0-1: 只有在凭据已获取时才释放
  if FCredentialsAcquired and IsValidSecHandle(FCredHandle) then
    FreeCredentialsHandle(@FCredHandle);
  
  // 清理证书固定
  FreeAndNil(FPinValidator);
  
  inherited Destroy;
end;

procedure TWinSSLContext.CleanupCertificate;
begin
  if FCertContext <> nil then
  begin
    CertFreeCertificateContext(FCertContext);
    FCertContext := nil;
  end;

  if FCertStore <> nil then
  begin
    CertCloseStore(FCertStore, 0);
    FCertStore := nil;
  end;

  // P0-2: 清理 CA 证书存储
  if FCAStore <> nil then
  begin
    CertCloseStore(FCAStore, 0);
    FCAStore := nil;
  end;

  // 清理外部证书存储引用
  FExternalCertStore := nil;
end;

procedure TWinSSLContext.ApplyOptions;
begin
  // 当前实现已映射主要选项（会话缓存等）
  // 可扩展：根据实际需求添加更多 WinSSL 选项映射
  SetSessionCacheMode(ssoEnableSessionCache in FOptions);
end;

{ P0-1: 延迟凭据获取 - 确保证书加载后才获取凭据
  此方法在 CreateConnection 或 GetNativeHandle 时调用
  确保 LoadCertificate/LoadPrivateKey 的设置能够生效
  
  WinSSL 服务端支持 - 任务 2.1:
  增强服务端凭据获取,确保服务器证书正确配置 }
procedure TWinSSLContext.EnsureCredentialsAcquired;
var
  SchannelCred: SCHANNEL_CRED;
  Status: SECURITY_STATUS;
  TimeStamp: TTimeStamp;
  dwDirection: DWORD;
begin
  // 如果凭据已获取且不需要重建，直接返回
  if FCredentialsAcquired and (not FCredentialsNeedRebuild) then
    Exit;

  // 如果已有凭据句柄，先释放
  if FCredentialsAcquired and IsValidSecHandle(FCredHandle) then
  begin
    FreeCredentialsHandle(@FCredHandle);
    InitSecHandle(FCredHandle);
  end;

  // 任务 2.1: 服务端模式验证 - 服务端必须有证书
  if (FContextType = sslCtxServer) and (FCertContext = nil) then
    raise ESSLConfigurationException.CreateWithContext(
      'Server context requires a certificate. Use LoadCertificate() to load a server certificate.',
      sslErrConfiguration,
      'TWinSSLContext.EnsureCredentialsAcquired',
      0,
      sslWinSSL
    );

  // 初始化 Schannel 凭据
  FillChar(SchannelCred, SizeOf(SchannelCred), 0);
  SchannelCred.dwVersion := SCHANNEL_CRED_VERSION;

  // 设置协议版本标志
  SchannelCred.grbitEnabledProtocols := ProtocolVersionsToSchannelFlags(
    FProtocolVersions,
    FContextType = sslCtxServer
  );

  // 设置标志
  SchannelCred.dwFlags := SCH_CRED_NO_DEFAULT_CREDS or
                          SCH_CRED_MANUAL_CRED_VALIDATION;

  // 任务 2.1: 服务端凭据配置 - 服务端必须包含证书
  if FContextType = sslCtxServer then
  begin
    // Microsoft documents SCH_CRED_DISABLE_RECONNECTS as a server-side flag.
    // Keep WinSSL's "disable session cache/tickets" truth mapped here only for
    // inbound credentials. Client-side reconnect lookup still follows Schannel's
    // automatic cache key (target name + credential handle + process/logon session).
    if (not FSessionCacheEnabled) or
       (not (ssoEnableSessionTickets in FOptions)) then
      SchannelCred.dwFlags := SchannelCred.dwFlags or SCH_CRED_DISABLE_RECONNECTS;

    // 服务端模式: 必须提供证书
    SchannelCred.cCreds := 1;
    SchannelCred.paCred := @FCertContext;
  end
  else if FCertContext <> nil then
  begin
    // 客户端模式: 如果有证书则包含(用于双向 TLS)
    SchannelCred.cCreds := 1;
    SchannelCred.paCred := @FCertContext;
  end;

  // 确定方向（客户端或服务端）
  if FContextType = sslCtxServer then
    dwDirection := SECPKG_CRED_INBOUND
  else
    dwDirection := SECPKG_CRED_OUTBOUND;

  // 获取凭据句柄
  Status := AcquireCredentialsHandleW(
    nil,
    PWideChar(WideString('Microsoft Unified Security Protocol Provider')),
    dwDirection,
    nil,
    @SchannelCred,
    nil,
    nil,
    @FCredHandle,
    @TimeStamp
  );

  if not IsSuccess(Status) then
    raise ESSLInitializationException.CreateWithContext(
      Format('Failed to acquire credentials handle: 0x%x (%s mode)', 
        [Status, IfThen(FContextType = sslCtxServer, 'server', 'client')]),
      sslErrNotInitialized,
      'TWinSSLContext.EnsureCredentialsAcquired',
      Status,
      sslWinSSL
    );

  FCredentialsAcquired := True;
  FCredentialsNeedRebuild := False;
end;

{ P1: 统一上下文验证模式 - 与 OpenSSL 保持一致 }
procedure TWinSSLContext.RequireValidContext(const AMethodName: string);
begin
  if not FInitialized then
    raise ESSLInitializationException.CreateWithContext(
      'WinSSL context not initialized',
      sslErrNotInitialized,
      AMethodName
    );
end;

{ P1: PEM→DER 转换 - 消除跨平台差异
  使用 Windows CryptStringToBinaryA API 解码 PEM 格式
  支持带 header 和不带 header 的 Base64 格式 }
function TWinSSLContext.PEMToDER(const APEM: string): TBytes;
var
  LPEMAnsi: AnsiString;
  LBinarySize: DWORD;
begin
  Result := nil;
  if APEM = '' then
    Exit;

  LPEMAnsi := AnsiString(APEM);

  // 第一次调用：获取所需缓冲区大小
  LBinarySize := 0;
  if not CryptStringToBinaryA(
    PAnsiChar(LPEMAnsi),
    Length(LPEMAnsi),
    CRYPT_STRING_BASE64HEADER,  // 自动处理 -----BEGIN/END----- 头
    nil,
    @LBinarySize,
    nil,
    nil
  ) then
  begin
    // 尝试不带 header 的纯 Base64
    if not CryptStringToBinaryA(
      PAnsiChar(LPEMAnsi),
      Length(LPEMAnsi),
      CRYPT_STRING_BASE64,
      nil,
      @LBinarySize,
      nil,
      nil
    ) then
      raise ESSLCertificateLoadException.CreateWithContext(
        'Failed to decode PEM data: invalid format',
        sslErrLoadFailed,
        'TWinSSLContext.PEMToDER',
        GetLastError,
        sslWinSSL
      );
  end;

  // 分配缓冲区
  SetLength(Result, LBinarySize);

  // 第二次调用：实际解码
  if not CryptStringToBinaryA(
    PAnsiChar(LPEMAnsi),
    Length(LPEMAnsi),
    CRYPT_STRING_BASE64HEADER,
    @Result[0],
    @LBinarySize,
    nil,
    nil
  ) then
  begin
    // 尝试不带 header 的纯 Base64
    if not CryptStringToBinaryA(
      PAnsiChar(LPEMAnsi),
      Length(LPEMAnsi),
      CRYPT_STRING_BASE64,
      @Result[0],
      @LBinarySize,
      nil,
      nil
    ) then
    begin
      SetLength(Result, 0);
      raise ESSLCertificateLoadException.CreateWithContext(
        'Failed to decode PEM data',
        sslErrLoadFailed,
        'TWinSSLContext.PEMToDER',
        GetLastError,
        sslWinSSL
      );
    end;
  end;

  // 调整实际大小
  SetLength(Result, LBinarySize);
end;

// ============================================================================
// ISSLContext - 基本配置
// ============================================================================

function TWinSSLContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TWinSSLContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
  FProtocolVersions := AVersions;

  // 当首选版本不再可用时，自动回退为无偏好
  if (FPreferredVersion <> sslProtocolUnknown) and
    not (FPreferredVersion in FProtocolVersions) then
    FPreferredVersion := sslProtocolUnknown;

  // P2: 使用共享辅助函数记录废弃协议警告
  LogDeprecatedProtocolWarnings('WinSSL', AVersions);

  // P0-1: 协议版本变更需要重建凭据
  FCredentialsNeedRebuild := True;
end;

function TWinSSLContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := FProtocolVersions;
end;

procedure TWinSSLContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
  if (AVersion <> sslProtocolUnknown) and
    not (AVersion in FProtocolVersions) then
    RaiseInvalidParameter('PreferredVersion');

  FPreferredVersion := AVersion;
end;

function TWinSSLContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := FPreferredVersion;
end;

// ============================================================================
// ISSLContext - 证书和密钥管理
// ============================================================================

procedure TWinSSLContext.LoadCertificate(const AFileName: string);
var
  LFileStream: TFileStream;
  LSize: Int64;
begin
  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  if not FileExists(AFileName) then
    raise ESSLFileNotFoundException.CreateWithContext(
      Format('Certificate file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TWinSSLContext.LoadCertificate'
    );

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CERTIFICATE_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Certificate file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CERTIFICATE_SIZE, AFileName]);

  LFileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadCertificate(LFileStream);
  finally
    LFileStream.Free;
  end;
end;

procedure TWinSSLContext.LoadCertificate(AStream: TStream);
var
  LCertData: TBytes;
  LSize: Int64;
  Blob: CRYPT_DATA_BLOB;
  PFXStore: HCERTSTORE;
  CertContext: PCCERT_CONTEXT;
begin
  // Rust-quality: Validate parameters upfront
  if AStream = nil then
    RaiseInvalidParameter('AStream cannot be nil');

  // 清理之前的证书
  CleanupCertificate;

  // 读取证书数据
  LSize := AStream.Size - AStream.Position;
  if LSize <= 0 then
    RaiseInvalidParameter('Stream is empty or at end position');

  SetLength(LCertData, LSize);
  AStream.Read(LCertData[0], LSize);
  
  // 1. 尝试作为 PFX 加载 (无密码)
  Blob.cbData := Length(LCertData);
  Blob.pbData := @LCertData[0];
  
  PFXStore := PFXImportCertStore(@Blob, nil, CRYPT_EXPORTABLE or PKCS12_NO_PERSIST_KEY);
  if PFXStore <> nil then
  begin
    // 是 PFX 文件，查找第一个证书（通常是用户证书）
    // 注意：这里假设 PFX 中包含私钥的证书是我们需要的
    // 实际应该遍历查找带有私钥属性的证书
    CertContext := CertEnumCertificatesInStore(PFXStore, nil);
    if CertContext <> nil then
    begin
      FCertContext := CertDuplicateCertificateContext(CertContext);
      // PFX 存储中的证书已经包含了私钥关联信息
      // 我们不需要显式加载私钥，Schannel 会自动使用
    end;
    CertCloseStore(PFXStore, 0);
    
    if FCertContext <> nil then
    begin
      // P0-1: 证书加载后标记需要重建凭据
      FCredentialsNeedRebuild := True;
      Exit; // 成功加载
    end;
  end;

  // 2. 尝试作为普通证书加载 (DER/PEM)
  // 创建内存证书存储
  FCertStore := CertOpenStore(
    CERT_STORE_PROV_MEMORY,
    0,
    0,
    0,
    nil
  );
  
  if FCertStore = nil then
    raise ESSLResourceException.CreateWithContext(
      'Failed to create certificate store',
      sslErrMemory,
      'TWinSSLContext.LoadCertificate'
    );
  
  // 添加证书到存储 (尝试多种格式，包括 PEM)
  // CertAddEncodedCertificateToStore 只能处理 DER，我们需要先转换 PEM
  // 或者使用 CertCreateCertificateContextFromFile 的逻辑
  
  // 尝试直接添加 (DER)
  if not CertAddEncodedCertificateToStore(
    FCertStore,
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    @LCertData[0],
    Length(LCertData),
    CERT_STORE_ADD_ALWAYS,
    @FCertContext
  ) then
  begin
    // 如果失败，尝试解码 PEM
    // 这里简化处理，如果需要完整 PEM 支持，应使用 CryptStringToBinaryA
    // 目前假设是 DER 格式失败
    if FCertContext = nil then
    raise ESSLCertificateLoadException.CreateWithContext(
      'Certificate load failed: unsupported format or invalid data',
      sslErrLoadFailed,
      'TWinSSLContext.LoadCertificate',
      GetLastError,
      sslWinSSL
    );
  end;

  // P0-1: 证书加载后标记需要重建凭据
  FCredentialsNeedRebuild := True;
end;

procedure TWinSSLContext.LoadCertificate(ACert: ISSLCertificate);
begin
  // 从ISSLCertificate接口获取证书上下文
  if ACert = nil then
    raise ESSLInvalidArgument.CreateWithContext(
      'Certificate object is nil',
      sslErrInvalidParam,
      'TWinSSLContext.LoadCertificate'
    );

  CleanupCertificate;

  // 获取证书的原生句柄
  FCertContext := PCCERT_CONTEXT(GetNativeHandleSafe(ACert, 'TWinSSLContext.LoadCertificate'));
  if FCertContext <> nil then
  begin
    FCertContext := CertDuplicateCertificateContext(FCertContext);
    // P0-1: 证书加载后标记需要重建凭据
    FCredentialsNeedRebuild := True;
  end;
end;

procedure TWinSSLContext.LoadPrivateKey(const AFileName: string; const APassword: string);
var
  LFileStream: TFileStream;
  LSize: Int64;
begin
  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  if not FileExists(AFileName) then
    raise ESSLFileNotFoundException.CreateWithContext(
      Format('Private key file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TWinSSLContext.LoadPrivateKey'
    );

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_PRIVATE_KEY_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Private key file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_PRIVATE_KEY_SIZE, AFileName]);

  LFileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LoadPrivateKey(LFileStream, APassword);
  finally
    LFileStream.Free;
  end;
end;

procedure TWinSSLContext.LoadPrivateKey(AStream: TStream; const APassword: string);
var
  LCertData: TBytes;
  LSize: Int64;
  Blob: CRYPT_DATA_BLOB;
  PFXStore: HCERTSTORE;
  CertContext: PCCERT_CONTEXT;
  PW: PWideChar;
begin
  // WinSSL/Schannel 通常将证书和私钥一起加载（如PFX格式）
  // 如果是 PFX，我们尝试加载并提取证书和私钥

  if AStream = nil then
    raise ESSLInvalidArgument.CreateWithContext(
      'Private key stream is nil',
      sslErrInvalidParam,
      'TWinSSLContext.LoadPrivateKey',
      0,
      sslWinSSL
    );
  
  LSize := AStream.Size - AStream.Position;
  SetLength(LCertData, LSize);
  AStream.Read(LCertData[0], LSize);
  
  Blob.cbData := Length(LCertData);
  Blob.pbData := @LCertData[0];
  
  PW := nil;
  if APassword <> '' then
    PW := StringToPWideChar(APassword);
    
  try
    PFXStore := PFXImportCertStore(@Blob, PW, CRYPT_EXPORTABLE or PKCS12_NO_PERSIST_KEY);
  finally
    if PW <> nil then
      FreePWideCharString(PW);
  end;
  
  if PFXStore <> nil then
  begin
    // 成功打开 PFX，查找带有私钥的证书
    // 这里我们简单地取第一个证书，并替换当前的 FCertContext
    // 如果之前通过 LoadCertificate 加载了证书，这里会被覆盖
    // 这是符合预期的，因为 PFX 包含了证书和私钥
    
    CertContext := CertEnumCertificatesInStore(PFXStore, nil);
    if CertContext <> nil then
    begin
      if FCertContext <> nil then
        CertFreeCertificateContext(FCertContext);

      FCertContext := CertDuplicateCertificateContext(CertContext);
      // P0-1: 私钥加载后标记需要重建凭据
      FCredentialsNeedRebuild := True;
    end;
    CertCloseStore(PFXStore, 0);
  end
  else
  begin
    raise ESSLConfigurationException.CreateWithContext(
      'WinSSL backend only supports PFX/P12 format for private key loading. ' +
      'Bare PEM/DER/PKCS#8 private keys are unsupported; please merge certificate and key into a PFX file.',
      sslErrUnsupported,
      'TWinSSLContext.LoadPrivateKey'
    );
  end;
end;

procedure TWinSSLContext.LoadCertificatePEM(const APEM: string);
var
  LDERData: TBytes;
begin
  // P1: 实现 PEM→DER 转换，消除跨平台差异
  if APEM = '' then
    raise ESSLInvalidArgument.CreateWithContext(
      'PEM string is empty',
      sslErrInvalidParam,
      'TWinSSLContext.LoadCertificatePEM'
    );

  // 转换 PEM 到 DER
  LDERData := PEMToDER(APEM);
  if Length(LDERData) = 0 then
    raise ESSLCertificateLoadException.CreateWithContext(
      'Failed to decode PEM certificate data',
      sslErrLoadFailed,
      'TWinSSLContext.LoadCertificatePEM',
      0,
      sslWinSSL
    );

  // 清理之前的证书
  CleanupCertificate;

  // 创建内存证书存储
  FCertStore := CertOpenStore(
    CERT_STORE_PROV_MEMORY,
    0,
    0,
    0,
    nil
  );

  if FCertStore = nil then
    raise ESSLResourceException.CreateWithContext(
      'Failed to create certificate store',
      sslErrMemory,
      'TWinSSLContext.LoadCertificatePEM'
    );

  // 添加 DER 编码的证书到存储
  if not CertAddEncodedCertificateToStore(
    FCertStore,
    X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
    @LDERData[0],
    Length(LDERData),
    CERT_STORE_ADD_ALWAYS,
    @FCertContext
  ) then
    raise ESSLCertificateLoadException.CreateWithContext(
      'Failed to add certificate to store',
      sslErrLoadFailed,
      'TWinSSLContext.LoadCertificatePEM',
      GetLastError,
      sslWinSSL
    );

  // P0-1: 证书加载后标记需要重建凭据
  FCredentialsNeedRebuild := True;
end;

procedure TWinSSLContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string = '');
begin
  // P1: 私钥 PEM 加载说明
  // WinSSL/Schannel 不直接支持 PEM 格式私钥导入
  // Windows CNG API 需要 PKCS#8 DER 格式，且导入过程复杂
  // 推荐方案：将证书和私钥合并为 PFX/P12 格式
  if APEM = '' then
    raise ESSLInvalidArgument.CreateWithContext(
      'PEM string is empty',
      sslErrInvalidParam,
      'TWinSSLContext.LoadPrivateKeyPEM'
    );

  // 提供清晰的错误信息和解决方案
  raise ESSLConfigurationException.CreateWithContext(
    'WinSSL backend does not support direct PEM private key loading. ' +
    'Recommended solutions: ' +
    '(1) Use PKCS#12/PFX format with LoadPrivateKey method, ' +
    '(2) Use OpenSSL backend for PEM support, ' +
    '(3) Convert PEM to PFX using: openssl pkcs12 -export -in cert.pem -inkey key.pem -out bundle.pfx',
    sslErrUnsupported,
    'TWinSSLContext.LoadPrivateKeyPEM'
  );
end;

procedure TWinSSLContext.LoadCAFile(const AFileName: string);
var
  LFileStream: TFileStream;
  LCertData: TBytes;
  LSize: Int64;
  LFileSize: Int64;
  LCertContext: PCCERT_CONTEXT;
begin
  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  if not FileExists(AFileName) then
    raise ESSLFileNotFoundException.CreateWithContext(
      Format('CA file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TWinSSLContext.LoadCAFile'
    );

  LFileSize := GetFileSizeByName(AFileName);
  if LFileSize > MAX_CA_CHAIN_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'CA file exceeds maximum allowed size (%d > %d bytes): %s',
      [LFileSize, MAX_CA_CHAIN_SIZE, AFileName]);

  LFileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    LSize := LFileStream.Size;
    SetLength(LCertData, LSize);
    LFileStream.Read(LCertData[0], LSize);

    // P0-2: 创建或重用 CA 证书内存存储
    if FCAStore = nil then
    begin
      FCAStore := CertOpenStore(
        CERT_STORE_PROV_MEMORY,
        0,
        0,
        0,
        nil
      );
      if FCAStore = nil then
        raise ESSLResourceException.CreateWithContext(
          'Failed to create CA certificate store',
          sslErrMemory,
          'TWinSSLContext.LoadCAFile'
        );
    end;

    // 创建证书上下文
    LCertContext := CertCreateCertificateContext(
      X509_ASN_ENCODING or PKCS_7_ASN_ENCODING,
      @LCertData[0],
      Length(LCertData)
    );

    if LCertContext = nil then
      raise ESSLCertificateLoadException.CreateWithContext(
        'Failed to parse CA certificate',
        sslErrLoadFailed,
        'TWinSSLContext.LoadCAFile',
        GetLastError,
        sslWinSSL
      );

    // P0-2: 将 CA 证书添加到内存存储（而不是立即释放）
    if not CertAddCertificateContextToStore(
      FCAStore,
      LCertContext,
      CERT_STORE_ADD_REPLACE_EXISTING,
      nil
    ) then
    begin
      CertFreeCertificateContext(LCertContext);
      raise ESSLCertificateLoadException.CreateWithContext(
        'Failed to add CA certificate to store',
        sslErrLoadFailed,
        'TWinSSLContext.LoadCAFile',
        GetLastError,
        sslWinSSL
      );
    end;

    // 释放临时证书上下文（存储中已有副本）
    CertFreeCertificateContext(LCertContext);
  finally
    LFileStream.Free;
  end;
end;

procedure TWinSSLContext.LoadCAPath(const APath: string);
begin
  // Windows 使用系统证书存储，不支持指定CA路径
  // 如果调用者传入了路径，说明期望此功能工作，应该抛出异常
  if APath <> '' then
    raise ESSLPlatformNotSupportedException.CreateWithContext(
      'LoadCAPath is not supported on Windows. ' +
      'Windows uses the system certificate store for CA verification.',
      sslErrOther,
      'TWinSSLContext.LoadCAPath',
      0,
      sslWinSSL
    );
  // 空路径视为无操作（兼容跨平台代码）
end;

procedure TWinSSLContext.SetCertificateStore(AStore: ISSLCertificateStore);
var
  LStoreHandle: Pointer;
begin
  { WinSSL/Schannel 说明：
    与 OpenSSL 不同，Schannel 不直接使用自定义证书存储进行 CA 验证。
    Schannel 主要使用系统证书存储（ROOT、CA 等）进行证书链验证。

    此方法保存传入的证书存储接口引用，用于：
    1. 保持证书存储对象的生命周期
    2. 可在证书链验证时使用其原生句柄

    对于 CA 验证，建议使用 LoadCAFile 或直接将证书导入系统存储。
  }

  // 清理之前的外部存储引用
  FExternalCertStore := nil;

  if AStore = nil then
    Exit;  // nil 表示清除存储

  // 验证存储句柄有效性
  if not TryGetNativeHandle(AStore, LStoreHandle) then
    raise ESSLCertificateException.CreateWithContext(
      'Invalid certificate store handle (does not support native handle access)',
      sslErrCertificate,
      'TWinSSLContext.SetCertificateStore',
      0,
      sslWinSSL
    );

  // 保存接口引用（通过引用计数保持存储活跃）
  FExternalCertStore := AStore;
end;

// ============================================================================
// ISSLContext - 验证配置
// ============================================================================

procedure TWinSSLContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
  FVerifyMode := AMode;
end;

function TWinSSLContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := FVerifyMode;
end;

procedure TWinSSLContext.SetVerifyDepth(ADepth: Integer);
begin
  FVerifyDepth := ADepth;
end;

function TWinSSLContext.GetVerifyDepth: Integer;
begin
  Result := FVerifyDepth;
end;

procedure TWinSSLContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
  FVerifyCallback := ACallback;
end;

// ============================================================================
// ISSLContext - 密码套件配置
// ============================================================================

function IsCustomCipherListOverride(const ACipherList: string): Boolean; forward;
function IsCustomCipherSuitesOverride(const ACipherSuites: string): Boolean; forward;

procedure TWinSSLContext.SetCipherList(const ACipherList: string);
begin
  if IsCustomCipherListOverride(ACipherList) then
    RejectUnsupportedCustomCipherAssignment('Cipher list', 'TWinSSLContext.SetCipherList');
  FCipherList := ACipherList;
end;

function TWinSSLContext.GetCipherList: string;
begin
  Result := FCipherList;
end;

procedure TWinSSLContext.SetCipherSuites(const ACipherSuites: string);
begin
  if IsCustomCipherSuitesOverride(ACipherSuites) then
    RejectUnsupportedCustomCipherAssignment('Cipher suites', 'TWinSSLContext.SetCipherSuites');
  FCipherSuites := ACipherSuites;
  // TLS 1.3 密码套件在Windows 10/Server 2019+支持
  // Schannel会自动选择合适的密码套件
end;

function TWinSSLContext.GetCipherSuites: string;
begin
  Result := FCipherSuites;
end;

// ============================================================================
// ISSLContext - 会话管理（Schannel 自动管理）
// ============================================================================

procedure TWinSSLContext.SetSessionCacheMode(AEnabled: Boolean);
begin
  if FSessionCacheEnabled = AEnabled then
    Exit;

  FSessionCacheEnabled := AEnabled;
  FCredentialsNeedRebuild := True;
end;

function TWinSSLContext.GetSessionCacheMode: Boolean;
begin
  Result := FSessionCacheEnabled;
end;

procedure TWinSSLContext.SetSessionTimeout(ATimeout: Integer);
begin
  FSessionTimeout := ATimeout;
end;

function TWinSSLContext.GetSessionTimeout: Integer;
begin
  Result := FSessionTimeout;
end;

procedure TWinSSLContext.SetSessionCacheSize(ASize: Integer);
begin
  FSessionCacheSize := ASize;
end;

function TWinSSLContext.GetSessionCacheSize: Integer;
begin
  Result := FSessionCacheSize;
end;

// ============================================================================
// ISSLContext - 高级选项
// ============================================================================

procedure TWinSSLContext.SetOptions(const AOptions: TSSLOptions);
begin
  FOptions := AOptions;
  FCredentialsNeedRebuild := True;
  ApplyOptions;
end;

function TWinSSLContext.GetOptions: TSSLOptions;
begin
  Result := FOptions;
end;

procedure TWinSSLContext.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TWinSSLContext.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TWinSSLContext.SetALPNProtocols(const AProtocols: string);
begin
  FALPNProtocols := AProtocols;
  // ALPN在Windows 8.1/Server 2012 R2+支持
  // 实际协商在连接时进行
end;

function TWinSSLContext.GetALPNProtocols: string;
begin
  Result := FALPNProtocols;
end;

// ============================================================================
// ISSLContext - 证书验证标志
// ============================================================================

procedure TWinSSLContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
  FCertVerifyFlags := AFlags;
  // WinSSL/Schannel 说明:
  // Schannel 使用系统证书验证策略。CRL/OCSP 检查由 Windows 证书链引擎自动处理。
  // 可通过 CERT_CHAIN_REVOCATION_CHECK_* 标志在验证时控制。
  // 此处保存标志，实际应用将在 TWinSSLConnection.GetVerifyResult 中处理。
end;

function TWinSSLContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := FCertVerifyFlags;
end;

// ============================================================================
// ISSLContext - 回调设置（Schannel 模型限制）
// ============================================================================

procedure TWinSSLContext.RejectUnsupportedCallbackAssignment(
  const AFeature, AMethodName: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    Format('%s is not published by the current WinSSL backend runtime. ' +
      'The current WinSSL callback surface only publishes verify/info paths.',
      [AFeature]),
    sslErrUnsupported,
    AMethodName,
    0,
    sslWinSSL
  );
end;

function IsCustomCipherListOverride(const ACipherList: string): Boolean;
begin
  Result := (Trim(ACipherList) <> '') and
    (not SameText(Trim(ACipherList), SSL_DEFAULT_CIPHER_LIST));
end;

function IsCustomCipherSuitesOverride(const ACipherSuites: string): Boolean;
begin
  Result := (Trim(ACipherSuites) <> '') and
    (not SameText(Trim(ACipherSuites), SSL_DEFAULT_TLS13_CIPHERSUITES));
end;

procedure TWinSSLContext.RejectUnsupportedCustomCipherAssignment(
  const AFeature, AMethodName: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    Format('%s is not published by the current WinSSL backend runtime. ' +
      'Check ISSLLibrary.GetCapabilities.SupportsCustomCipherSuites before installing a custom non-default cipher override.',
      [AFeature]),
    sslErrUnsupported,
    AMethodName,
    0,
    sslWinSSL
  );
end;

procedure TWinSSLContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Password callback', 'TWinSSLContext.SetPasswordCallback');
  FPasswordCallback := nil;
end;

procedure TWinSSLContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
  FInfoCallback := ACallback;
end;

{ P1-7: 回调获取方法 }
function TWinSSLContext.GetVerifyCallback: TSSLVerifyCallback;
begin
  Result := FVerifyCallback;
end;

function TWinSSLContext.GetWinSSLVerifyCallback: TSSLVerifyCallback;
begin
  Result := GetVerifyCallback;
end;

function TWinSSLContext.GetInfoCallback: TSSLInfoCallback;
begin
  Result := FInfoCallback;
end;

function TWinSSLContext.GetWinSSLInfoCallback: TSSLInfoCallback;
begin
  Result := GetInfoCallback;
end;

// ============================================================================
// ISSLContext - 证书固定
// ============================================================================

procedure TWinSSLContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
  if FPinValidator = nil then
    raise ESSLException.CreateWithContext(
      'Pin validator not initialized',
      sslErrNotInitialized,
      'TWinSSLContext.AddCertificatePin'
    );
  
  FPinValidator.AddPin(AHash, TPinType(APinType), ADescription, AIsBackup);
end;

procedure TWinSSLContext.AddCertificatePinBase64(const ABase64Hash: string; 
  APinType: Integer; const ADescription: string; AIsBackup: Boolean);
begin
  if FPinValidator = nil then
    raise ESSLException.CreateWithContext(
      'Pin validator not initialized',
      sslErrNotInitialized,
      'TWinSSLContext.AddCertificatePinBase64'
    );
  
  FPinValidator.AddPinBase64(ABase64Hash, TPinType(APinType), ADescription, AIsBackup);
end;

procedure TWinSSLContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
  FPinningEnabled := AEnabled;
  
  if FPinValidator <> nil then
    FPinValidator.RequireValidPin := AEnabled;
  
  TSecurityLog.Info('WinSSL', 
    Format('Certificate pinning %s', [IfThen(AEnabled, 'enabled', 'disabled')]));
end;

function TWinSSLContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := FPinningEnabled;
end;

procedure TWinSSLContext.ClearCertificatePins;
begin
  if FPinValidator <> nil then
    FPinValidator.ClearPins;
end;

// ============================================================================
// ISSLContext - 创建连接
// ============================================================================

function TWinSSLContext.CreateConnection(ASocket: THandle): ISSLConnection;
begin
  // P1: 统一上下文验证模式 - 与 OpenSSL RequireValidContext 模式一致
  RequireValidContext('TWinSSLContext.CreateConnection');

  // P0-1: 延迟凭据获取 - 确保证书已加载后才获取凭据
  EnsureCredentialsAcquired;

  // Let exceptions propagate - caller must handle errors explicitly
  Result := TWinSSLConnection.Create(Self, ASocket);
end;

function TWinSSLContext.CreateConnection(AStream: TStream): ISSLConnection;
begin
  // P1: 统一上下文验证模式 - 与 OpenSSL RequireValidContext 模式一致
  RequireValidContext('TWinSSLContext.CreateConnection');

  // Rust-quality: Validate parameters upfront
  if AStream = nil then
    RaiseInvalidParameter('AStream cannot be nil');

  // P0-1: 延迟凭据获取 - 确保证书已加载后才获取凭据
  EnsureCredentialsAcquired;

  // Let exceptions propagate - caller must handle errors explicitly
  Result := TWinSSLConnection.Create(Self, AStream);
end;

// ============================================================================
// ISSLContext - 状态查询
// ============================================================================

function TWinSSLContext.IsValid: Boolean;
begin
  // P0-1: 上下文有效性检查 - 凭据可能尚未获取
  Result := FInitialized and (FCredentialsAcquired or FCredentialsNeedRebuild);
end;

function TWinSSLContext.GetNativeHandle: Pointer;
begin
  // P0-1: 延迟凭据获取 - 确保返回有效的凭据句柄
  EnsureCredentialsAcquired;
  Result := @FCredHandle;
end;

function TWinSSLContext.GetBackendType: TSSLLibraryType;
begin
  Result := sslWinSSL;
end;

function TWinSSLContext.IsNativeHandleValid: Boolean;
begin
  Result := FInitialized and FCredentialsAcquired;
end;

{ P0-2: 获取 CA 证书存储句柄（供连接验证使用） }
function TWinSSLContext.GetCAStoreHandle: HCERTSTORE;
var
  LStoreHandle: Pointer;
begin
  Result := FCAStore;

  if (Result = nil) and (FExternalCertStore <> nil) then
  begin
    if TryGetNativeHandle(FExternalCertStore, LStoreHandle) then
      Result := HCERTSTORE(LStoreHandle);
  end;
end;

function TWinSSLContext.GetWinSSLCAStoreHandle: Pointer;
begin
  Result := GetCAStoreHandle;
end;

{ Phase 3.3: 获取库实例（供连接更新统计使用） }
function TWinSSLContext.GetLibrary: ISSLLibrary;
begin
  Result := FLibrary;
end;

function TWinSSLContext.GetWinSSLLibrary: ISSLLibrary;
begin
  Result := GetLibrary;
end;

end.
