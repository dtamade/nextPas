{**
 * Unit: nextpas.core.tls.wolfssl.context
 * Purpose: WolfSSL 上下文实现
 *
 * 实现 ISSLContext 接口的 WolfSSL 后端。
 * 负责 WOLFSSL_CTX 管理和连接创建。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-10
 *}

unit nextpas.core.tls.wolfssl.context;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  SysUtils, Classes, Base64,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.native_handle,
  nextpas.core.tls.wolfssl.api,
  nextpas.core.tls.secure;

type
  { 证书固定记录 }
  TWolfSSLCertPin = record
    Hash: array[0..31] of Byte;  // SHA-256 hash
    PinType: Integer;            // 0=Certificate, 1=PublicKey
    Description: string;
    IsBackup: Boolean;
  end;
  TWolfSSLCertPinArray = array of TWolfSSLCertPin;

  { TWolfSSLContext - WolfSSL 上下文类 }
  TWolfSSLContext = class(TInterfacedObject, ISSLContext, ISSLNativeHandleAccess)
  private
    FLibrary: ISSLLibrary;
    FContextType: TSSLContextType;
    FWolfSSLCtx: PWOLFSSL_CTX;
    FProtocolVersions: TSSLProtocolVersions;
    FPreferredVersion: TSSLProtocolVersion;
    FVerifyMode: TSSLVerifyModes;
    FVerifyDepth: Integer;
    FServerName: string;
    FCipherList: string;
    FCipherSuites: string;
    FALPNProtocols: string;
    FSessionCacheEnabled: Boolean;
    FSessionTimeout: Integer;
    FSessionCacheSize: Integer;
    FOptions: TSSLOptions;
    FCertVerifyFlags: TSSLCertVerifyFlags;

    // 回调
    FVerifyCallback: TSSLVerifyCallback;
    FPasswordCallback: TSSLPasswordCallback;
    FInfoCallback: TSSLInfoCallback;

    // 证书固定
    FCertPins: TWolfSSLCertPinArray;
    FPinningEnabled: Boolean;

    // Early Data 相关 (v1.4.2)
    FClientEarlyDataEnabled: Boolean;
    FServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
    FServerMaxEarlyDataSize: Cardinal;

    // Server OCSP Stapling 相关 (v1.4.2)
    FServerStapledOCSPResponse: TBytes;

    function GetWolfSSLMethod: PWOLFSSL_METHOD;
    procedure ApplyVerifyMode;
    procedure ApplyOCSPStaplingConfiguration;
    function HasEarlyDataCapability: Boolean;
    function HasClientOCSPCapability: Boolean;
    procedure RequireValidContext(const AMethodName: string);
    procedure RejectUnsupportedPasswordProtectedKey(const AMethodName: string);
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

    { ISSLContext - 证书固定 }
    procedure AddCertificatePin(const AHash: TBytes; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure AddCertificatePinBase64(const ABase64Hash: string; APinType: Integer;
      const ADescription: string; AIsBackup: Boolean = False);
    procedure SetCertificatePinningEnabled(AEnabled: Boolean);
    function GetCertificatePinningEnabled: Boolean;
    procedure ClearCertificatePins;

    { ISSLEarlyDataContext - TLS 1.3 Early Data 配置 (v1.4.2) }
    procedure SetClientEarlyDataEnabled(AEnabled: Boolean);
    function GetClientEarlyDataEnabled: Boolean;
    procedure SetServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy);
    function GetServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
    procedure SetServerMaxEarlyDataSize(ASize: Cardinal);
    function GetServerMaxEarlyDataSize: Cardinal;

    { ISSLServerOCSPStaplingContext - 服务端 OCSP Stapling (v1.4.2) }
    procedure ClearServerStapledOCSPResponse;
    procedure SetServerStapledOCSPResponse(const AResponseDER: TBytes);
    procedure LoadServerStapledOCSPResponseFile(const AFileName: string);
    function HasServerStapledOCSPResponse: Boolean;
    function GetServerStapledOCSPResponse: TBytes;

    { 证书固定访问（供 Connection 使用）}
    function GetCertificatePins: TWolfSSLCertPinArray;

    { ISSLContext - 创建连接 }
    function CreateConnection(ASocket: THandle): ISSLConnection; overload;
    function CreateConnection(AStream: TStream): ISSLConnection; overload;

    { ISSLContext - 状态查询 }
    function IsValid: Boolean;

    { ISSLNativeHandleAccess implementation }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    { ISSLContext - 健康状态和诊断 }
    function GetHealthStatus: TSSLHealthStatus;
    function IsHealthy: Boolean;
    function GetDiagnosticInfo: TSSLDiagnosticInfo;
    function GetPerformanceMetrics: TSSLPerformanceMetrics;

    { 便利方法 }
    procedure ConfigureSecureDefaults;
  end;

  { 仅在 server OCSP stapling capability 可用时暴露该接口 }
  TWolfSSLOCSPStaplingContext = class(TWolfSSLContext, ISSLServerOCSPStaplingContext)
  end;

  { 仅在运行时 early-data capability 可用时才暴露该接口 }
  TWolfSSLEarlyDataContext = class(TWolfSSLContext, ISSLEarlyDataContext)
  end;

  { 同时暴露 early-data 与 server OCSP stapling 两类可选接口 }
  TWolfSSLAdvancedContext = class(TWolfSSLContext,
    ISSLEarlyDataContext, ISSLServerOCSPStaplingContext)
  end;

implementation

uses
  nextpas.core.tls.wolfssl.connection;

const
  WOLFSSL_SSL_CTRL_SET_TLSEXT_STATUS_REQ_TYPE = 65;

function WolfSSLServerOCSPStaplingStatusCallback(ssl: PWOLFSSL;
  arg: Pointer): Integer; cdecl;
var
  LContext: TWolfSSLContext;
  LResponse: TBytes;
  LResponseCopy: PByte;
begin
  Result := WOLFSSL_TLSEXT_ERR_NOACK;

  if (ssl = nil) or (arg = nil) then
    Exit;

  try
    LContext := TWolfSSLContext(arg);
    if not LContext.HasServerStapledOCSPResponse then
      Exit;

    LResponse := LContext.GetServerStapledOCSPResponse;
    if Length(LResponse) = 0 then
      Exit;

    GetMem(LResponseCopy, Length(LResponse));
    Move(LResponse[0], LResponseCopy^, Length(LResponse));

    if Assigned(wolfSSL_set_tlsext_status_ocsp_resp) and
      (wolfSSL_set_tlsext_status_ocsp_resp(ssl, LResponseCopy, Length(LResponse)) <> 0) then
      Result := WOLFSSL_TLSEXT_ERR_OK
    else
    begin
      FreeMem(LResponseCopy);
      Result := WOLFSSL_TLSEXT_ERR_ALERT_FATAL;
    end;
  except
    Result := WOLFSSL_TLSEXT_ERR_ALERT_FATAL;
  end;
end;

{ TWolfSSLContext }

constructor TWolfSSLContext.Create(ALibrary: ISSLLibrary; AType: TSSLContextType);
var
  LMethod: PWOLFSSL_METHOD;
begin
  inherited Create;
  FLibrary := ALibrary;
  FContextType := AType;
  FWolfSSLCtx := nil;
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FPreferredVersion := sslProtocolTLS13;
  FVerifyMode := [sslVerifyPeer];
  FVerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  FServerName := '';
  FCipherList := '';
  FCipherSuites := '';
  FALPNProtocols := '';
  FSessionCacheEnabled := True;
  FSessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FSessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;
  FOptions := [ssoEnableSNI];
  FCertVerifyFlags := [];
  FVerifyCallback := nil;
  FPasswordCallback := nil;
  FInfoCallback := nil;

  // 初始化证书固定
  SetLength(FCertPins, 0);
  FPinningEnabled := False;

  // 初始化 Early Data 配置 (v1.4.2)
  FClientEarlyDataEnabled := False;
  FServerEarlyDataPolicy := sslEarlyDataServerReject;
  FServerMaxEarlyDataSize := 16384;  // 16KB 默认值

  // 初始化 Server OCSP Stapling (v1.4.2)
  SetLength(FServerStapledOCSPResponse, 0);

  // 创建 WolfSSL 上下文
  LMethod := GetWolfSSLMethod;
  if LMethod = nil then
    raise ESSLException.Create('Failed to get WolfSSL method for context type');

  if not Assigned(wolfSSL_CTX_new) then
    raise ESSLException.Create('wolfSSL_CTX_new not available');

  FWolfSSLCtx := wolfSSL_CTX_new(LMethod);
  if FWolfSSLCtx = nil then
    raise ESSLException.Create('Failed to create WolfSSL context');

  // 应用默认验证模式
  ApplyVerifyMode;
  ApplyOCSPStaplingConfiguration;
end;

destructor TWolfSSLContext.Destroy;
begin
  if FWolfSSLCtx <> nil then
  begin
    if Assigned(wolfSSL_CTX_free) then
      wolfSSL_CTX_free(FWolfSSLCtx);
    FWolfSSLCtx := nil;
  end;
  FLibrary := nil;
  inherited Destroy;
end;

function TWolfSSLContext.GetWolfSSLMethod: PWOLFSSL_METHOD;
begin
  Result := nil;

  case FContextType of
    sslCtxClient:
      begin
        // 优先使用 TLS 1.3，回退到 TLS 1.2
        if (sslProtocolTLS13 in FProtocolVersions) and Assigned(wolfTLSv1_3_client_method) then
          Result := wolfTLSv1_3_client_method()
        else if Assigned(wolfSSLv23_client_method) then
          Result := wolfSSLv23_client_method()
        else if Assigned(wolfTLSv1_2_client_method) then
          Result := wolfTLSv1_2_client_method();
      end;

    sslCtxServer:
      begin
        if (sslProtocolTLS13 in FProtocolVersions) and Assigned(wolfTLSv1_3_server_method) then
          Result := wolfTLSv1_3_server_method()
        else if Assigned(wolfSSLv23_server_method) then
          Result := wolfSSLv23_server_method()
        else if Assigned(wolfTLSv1_2_server_method) then
          Result := wolfTLSv1_2_server_method();
      end;

    sslCtxBoth:
      begin
        // 使用通用方法
        if Assigned(wolfSSLv23_client_method) then
          Result := wolfSSLv23_client_method();
      end;
  end;
end;

procedure TWolfSSLContext.ApplyVerifyMode;
var
  LMode: Integer;
begin
  if FWolfSSLCtx = nil then Exit;
  if not Assigned(wolfSSL_CTX_set_verify) then Exit;

  LMode := WOLFSSL_VERIFY_NONE;

  if sslVerifyPeer in FVerifyMode then
    LMode := WOLFSSL_VERIFY_PEER;

  if sslVerifyFailIfNoPeerCert in FVerifyMode then
    LMode := LMode or WOLFSSL_VERIFY_FAIL_IF_NO_PEER_CERT;

  wolfSSL_CTX_set_verify(FWolfSSLCtx, LMode, nil);
end;

procedure TWolfSSLContext.RequireValidContext(const AMethodName: string);
begin
  if FWolfSSLCtx = nil then
    raise ESSLException.CreateFmt('%s: WolfSSL context is not valid', [AMethodName]);
end;

function TWolfSSLContext.HasEarlyDataCapability: Boolean;
begin
  Result := (FLibrary <> nil) and
    (FLibrary.GetCapabilities.EarlyDataSupport <> sslSupportNone);
end;

function TWolfSSLContext.HasClientOCSPCapability: Boolean;
begin
  Result := (FLibrary <> nil) and
    (FLibrary.GetCapabilities.OCSPStaplingSupport <> sslSupportNone);
end;

procedure TWolfSSLContext.ApplyOCSPStaplingConfiguration;
var
  LClientRequestsStapling: Boolean;
begin
  if FWolfSSLCtx = nil then
    Exit;

  LClientRequestsStapling :=
    (FContextType <> sslCtxServer) and
    ((ssoEnableOCSPStapling in FOptions) or
    (ssoRequireOCSPStapling in FOptions));

  if LClientRequestsStapling then
  begin
    if Assigned(wolfSSL_CTX_EnableOCSPStapling) then
      wolfSSL_CTX_EnableOCSPStapling(FWolfSSLCtx);
  end
  else if (FContextType <> sslCtxServer) and Assigned(wolfSSL_CTX_DisableOCSPStapling) then
    wolfSSL_CTX_DisableOCSPStapling(FWolfSSLCtx);

  if FContextType <> sslCtxServer then
    Exit;

  if Assigned(wolfSSL_CTX_set_tlsext_status_arg) then
  begin
    if HasServerStapledOCSPResponse then
      wolfSSL_CTX_set_tlsext_status_arg(FWolfSSLCtx, Self)
    else
      wolfSSL_CTX_set_tlsext_status_arg(FWolfSSLCtx, nil);
  end;

  if HasServerStapledOCSPResponse then
  begin
    if Assigned(wolfSSL_CTX_ctrl) then
      wolfSSL_CTX_ctrl(FWolfSSLCtx, WOLFSSL_SSL_CTRL_SET_TLSEXT_STATUS_REQ_TYPE,
        WOLFSSL_CSR_OCSP, nil);
    if Assigned(wolfSSL_CTX_EnableOCSP) then
      wolfSSL_CTX_EnableOCSP(FWolfSSLCtx, 0);
    if Assigned(wolfSSL_CTX_set_tlsext_status_cb) then
      wolfSSL_CTX_set_tlsext_status_cb(FWolfSSLCtx,
        @WolfSSLServerOCSPStaplingStatusCallback);
    if Assigned(wolfSSL_CTX_EnableOCSPStapling) then
      wolfSSL_CTX_EnableOCSPStapling(FWolfSSLCtx);
  end
  else
  begin
    if Assigned(wolfSSL_CTX_set_tlsext_status_cb) then
      wolfSSL_CTX_set_tlsext_status_cb(FWolfSSLCtx, nil);
    if Assigned(wolfSSL_CTX_DisableOCSPStapling) then
      wolfSSL_CTX_DisableOCSPStapling(FWolfSSLCtx);
    if Assigned(wolfSSL_CTX_DisableOCSP) then
      wolfSSL_CTX_DisableOCSP(FWolfSSLCtx);
  end;
end;

function TWolfSSLContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TWolfSSLContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
  FProtocolVersions := AVersions;

  // 当首选版本不再可用时，自动回退为无偏好
  if (FPreferredVersion <> sslProtocolUnknown) and
    not (FPreferredVersion in FProtocolVersions) then
    FPreferredVersion := sslProtocolUnknown;

  // WolfSSL 协议版本在创建时确定，运行时更改需要重建上下文
end;

function TWolfSSLContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := FProtocolVersions;
end;

procedure TWolfSSLContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
  if (AVersion <> sslProtocolUnknown) and
    not (AVersion in FProtocolVersions) then
    RaiseInvalidParameter('PreferredVersion');

  FPreferredVersion := AVersion;
end;

function TWolfSSLContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := FPreferredVersion;
end;

{ 证书和密钥管理 }

procedure TWolfSSLContext.LoadCertificate(const AFileName: string);
var
  LSize: Int64;
begin
  RequireValidContext('LoadCertificate');

  if AFileName = '' then
    raise ESSLInvalidArgument.Create('AFileName must not be empty');

  if not FileExists(AFileName) then
    raise ESSLCertError.CreateFmt('Certificate file not found: %s', [AFileName]);

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CERTIFICATE_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Certificate file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CERTIFICATE_SIZE, AFileName]);

  if not Assigned(wolfSSL_CTX_use_certificate_file) then
    raise ESSLCertError.Create('wolfSSL_CTX_use_certificate_file not available');

  if wolfSSL_CTX_use_certificate_file(FWolfSSLCtx, PAnsiChar(AnsiString(AFileName)),
    WOLFSSL_FILETYPE_PEM) <> WOLFSSL_SUCCESS then
    raise ESSLCertError.CreateFmt('Failed to load certificate: %s', [AFileName]);
end;

procedure TWolfSSLContext.LoadCertificate(AStream: TStream);
var
  LBuffer: TBytes;
  LRet: Integer;
begin
  RequireValidContext('LoadCertificate');

  if AStream = nil then
    raise ESSLCertError.Create('Stream is nil');

  if not Assigned(wolfSSL_CTX_use_certificate_buffer) then
    raise ESSLCertError.Create('wolfSSL_CTX_use_certificate_buffer not available');

  // 读取流内容到缓冲区
  SetLength(LBuffer, AStream.Size - AStream.Position);
  if Length(LBuffer) = 0 then
    raise ESSLCertError.Create('Stream is empty');
  if Length(LBuffer) > MAX_CERTIFICATE_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Certificate stream exceeds maximum allowed size (%d > %d bytes)',
      [Length(LBuffer), MAX_CERTIFICATE_SIZE]);

  AStream.ReadBuffer(LBuffer[0], Length(LBuffer));

  // 尝试 PEM 格式
  LRet := wolfSSL_CTX_use_certificate_buffer(FWolfSSLCtx, @LBuffer[0],
    Length(LBuffer), WOLFSSL_FILETYPE_PEM);

  // 如果 PEM 失败，尝试 DER 格式
  if LRet <> WOLFSSL_SUCCESS then
  begin
    LRet := wolfSSL_CTX_use_certificate_buffer(FWolfSSLCtx, @LBuffer[0],
      Length(LBuffer), WOLFSSL_FILETYPE_ASN1);
  end;

  if LRet <> WOLFSSL_SUCCESS then
    raise ESSLCertError.Create('Failed to load certificate from stream');
end;

procedure TWolfSSLContext.LoadCertificate(ACert: ISSLCertificate);
var
  LDERData: TBytes;
  LRet: Integer;
begin
  RequireValidContext('LoadCertificate');

  if ACert = nil then
    raise ESSLCertError.Create('Certificate is nil');

  if not Assigned(wolfSSL_CTX_use_certificate_buffer) then
    raise ESSLCertError.Create('wolfSSL_CTX_use_certificate_buffer not available');

  // 从 ISSLCertificate 获取 DER 编码数据
  LDERData := ACert.SaveToDER;
  if Length(LDERData) = 0 then
    raise ESSLCertError.Create('Certificate DER data is empty');

  LRet := wolfSSL_CTX_use_certificate_buffer(FWolfSSLCtx, @LDERData[0],
    Length(LDERData), WOLFSSL_FILETYPE_ASN1);

  if LRet <> WOLFSSL_SUCCESS then
    raise ESSLCertError.Create('Failed to load certificate from ISSLCertificate');
end;

procedure TWolfSSLContext.LoadPrivateKey(const AFileName: string; const APassword: string);
var
  LSize: Int64;
begin
  RequireValidContext('LoadPrivateKey');

  if AFileName = '' then
    raise ESSLInvalidArgument.Create('AFileName must not be empty');

  if not FileExists(AFileName) then
    raise ESSLCertError.CreateFmt('Private key file not found: %s', [AFileName]);

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_PRIVATE_KEY_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Private key file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_PRIVATE_KEY_SIZE, AFileName]);

  if not Assigned(wolfSSL_CTX_use_PrivateKey_file) then
    raise ESSLCertError.Create('wolfSSL_CTX_use_PrivateKey_file not available');

  if APassword <> '' then
    RejectUnsupportedPasswordProtectedKey('TWolfSSLContext.LoadPrivateKey');

  if wolfSSL_CTX_use_PrivateKey_file(FWolfSSLCtx, PAnsiChar(AnsiString(AFileName)),
    WOLFSSL_FILETYPE_PEM) <> WOLFSSL_SUCCESS then
    raise ESSLCertError.CreateFmt('Failed to load private key: %s', [AFileName]);
end;

procedure TWolfSSLContext.LoadPrivateKey(AStream: TStream; const APassword: string);
var
  LBuffer: TBytes;
  LRet: Integer;
begin
  RequireValidContext('LoadPrivateKey');

  if AStream = nil then
    raise ESSLCertError.Create('Stream is nil');

  if not Assigned(wolfSSL_CTX_use_PrivateKey_buffer) then
    raise ESSLCertError.Create('wolfSSL_CTX_use_PrivateKey_buffer not available');

  // 读取流内容到缓冲区
  SetLength(LBuffer, AStream.Size - AStream.Position);
  if Length(LBuffer) = 0 then
    raise ESSLCertError.Create('Stream is empty');
  if Length(LBuffer) > MAX_PRIVATE_KEY_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Private key stream exceeds maximum allowed size (%d > %d bytes)',
      [Length(LBuffer), MAX_PRIVATE_KEY_SIZE]);

  if APassword <> '' then
    RejectUnsupportedPasswordProtectedKey('TWolfSSLContext.LoadPrivateKey(AStream)');

  AStream.ReadBuffer(LBuffer[0], Length(LBuffer));

  // 尝试 PEM 格式
  LRet := wolfSSL_CTX_use_PrivateKey_buffer(FWolfSSLCtx, @LBuffer[0],
    Length(LBuffer), WOLFSSL_FILETYPE_PEM);

  // 如果 PEM 失败，尝试 DER 格式
  if LRet <> WOLFSSL_SUCCESS then
  begin
    LRet := wolfSSL_CTX_use_PrivateKey_buffer(FWolfSSLCtx, @LBuffer[0],
      Length(LBuffer), WOLFSSL_FILETYPE_ASN1);
  end;

  if LRet <> WOLFSSL_SUCCESS then
    raise ESSLCertError.Create('Failed to load private key from stream');
end;

procedure TWolfSSLContext.LoadCertificatePEM(const APEM: string);
var
  LBuffer: TBytes;
  LRet: Integer;
begin
  RequireValidContext('LoadCertificatePEM');

  if APEM = '' then
    raise ESSLCertError.Create('PEM string is empty');

  if not Assigned(wolfSSL_CTX_use_certificate_buffer) then
    raise ESSLCertError.Create('wolfSSL_CTX_use_certificate_buffer not available');

  // 转换 PEM 字符串为字节数组
  LBuffer := nextpas.core.text.conv.StringToUTF8Bytes(APEM));

  LRet := wolfSSL_CTX_use_certificate_buffer(FWolfSSLCtx, @LBuffer[0],
    Length(LBuffer), WOLFSSL_FILETYPE_PEM);

  if LRet <> WOLFSSL_SUCCESS then
    raise ESSLCertError.Create('Failed to load certificate from PEM string');
end;

procedure TWolfSSLContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string);
var
  LBuffer: TBytes;
  LRet: Integer;
begin
  RequireValidContext('LoadPrivateKeyPEM');

  if APEM = '' then
    raise ESSLCertError.Create('PEM string is empty');

  if not Assigned(wolfSSL_CTX_use_PrivateKey_buffer) then
    raise ESSLCertError.Create('wolfSSL_CTX_use_PrivateKey_buffer not available');

  // 转换 PEM 字符串为字节数组
  LBuffer := nextpas.core.text.conv.StringToUTF8Bytes(APEM));

  if APassword <> '' then
    RejectUnsupportedPasswordProtectedKey('TWolfSSLContext.LoadPrivateKeyPEM');

  LRet := wolfSSL_CTX_use_PrivateKey_buffer(FWolfSSLCtx, @LBuffer[0],
    Length(LBuffer), WOLFSSL_FILETYPE_PEM);

  if LRet <> WOLFSSL_SUCCESS then
    raise ESSLCertError.Create('Failed to load private key from PEM string');
end;

procedure TWolfSSLContext.LoadCAFile(const AFileName: string);
var
  LSize: Int64;
begin
  RequireValidContext('LoadCAFile');

  if AFileName = '' then
    raise ESSLInvalidArgument.Create('AFileName must not be empty');

  if not FileExists(AFileName) then
    raise ESSLCertError.CreateFmt('CA file not found: %s', [AFileName]);

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CA_CHAIN_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'CA file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CA_CHAIN_SIZE, AFileName]);

  if not Assigned(wolfSSL_CTX_load_verify_locations) then
    raise ESSLCertError.Create('wolfSSL_CTX_load_verify_locations not available');

  if wolfSSL_CTX_load_verify_locations(FWolfSSLCtx, PAnsiChar(AnsiString(AFileName)), nil) <> WOLFSSL_SUCCESS then
    raise ESSLCertError.CreateFmt('Failed to load CA file: %s', [AFileName]);
end;

procedure TWolfSSLContext.LoadCAPath(const APath: string);
begin
  RequireValidContext('LoadCAPath');

  if not DirectoryExists(APath) then
    raise ESSLCertError.CreateFmt('CA path not found: %s', [APath]);

  if not Assigned(wolfSSL_CTX_load_verify_locations) then
    raise ESSLCertError.Create('wolfSSL_CTX_load_verify_locations not available');

  if wolfSSL_CTX_load_verify_locations(FWolfSSLCtx, nil, PAnsiChar(AnsiString(APath))) <> WOLFSSL_SUCCESS then
    raise ESSLCertError.CreateFmt('Failed to load CA path: %s', [APath]);
end;

procedure TWolfSSLContext.SetCertificateStore(AStore: ISSLCertificateStore);
var
  LCert: ISSLCertificate;
  LDERData: TBytes;
  LRet: Integer;
  I, LCount: Integer;
begin
  RequireValidContext('SetCertificateStore');

  if AStore = nil then
    raise ESSLCertError.Create('Certificate store is nil');

  if not Assigned(wolfSSL_CTX_load_verify_buffer) then
    raise ESSLCertError.Create('wolfSSL_CTX_load_verify_buffer not available');

  // 从证书存储中获取所有证书并加载
  LCount := AStore.GetCount;

  for I := 0 to LCount - 1 do
  begin
    LCert := AStore.GetCertificate(I);
    if LCert <> nil then
    begin
      LDERData := LCert.SaveToDER;
      if Length(LDERData) > 0 then
      begin
        LRet := wolfSSL_CTX_load_verify_buffer(FWolfSSLCtx, @LDERData[0],
          Length(LDERData), WOLFSSL_FILETYPE_ASN1);
        if LRet <> WOLFSSL_SUCCESS then
          raise ESSLCertError.CreateFmt('Failed to load certificate from store: %s',
            [LCert.GetSubject]);
      end;
    end;
  end;
end;

{ 验证配置 }

procedure TWolfSSLContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
  FVerifyMode := AMode;
  ApplyVerifyMode;
end;

function TWolfSSLContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := FVerifyMode;
end;

procedure TWolfSSLContext.SetVerifyDepth(ADepth: Integer);
begin
  FVerifyDepth := ADepth;
  // WolfSSL 验证深度通过其他方式设置
end;

function TWolfSSLContext.GetVerifyDepth: Integer;
begin
  Result := FVerifyDepth;
end;

procedure TWolfSSLContext.RejectUnsupportedCallbackAssignment(
  const AFeature, AMethodName: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    Format('%s is not published by the current WolfSSL backend runtime. ' +
      'Check ISSLLibrary.GetCapabilities.SupportsCallbacks before installing a non-nil callback.',
      [AFeature]),
    sslErrUnsupported,
    AMethodName,
    0,
    sslWolfSSL
  );
end;

procedure TWolfSSLContext.RejectUnsupportedPasswordProtectedKey(
  const AMethodName: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    'Password-protected private key loading is not published by the current WolfSSL backend runtime. ' +
    'Check ISSLLibrary.GetCapabilities.SupportsPasswordProtectedKeys before providing a non-empty private-key password.',
    sslErrUnsupported,
    AMethodName,
    0,
    sslWolfSSL
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

procedure TWolfSSLContext.RejectUnsupportedCustomCipherAssignment(
  const AFeature, AMethodName: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    Format('%s is not published by the current WolfSSL backend runtime. ' +
      'Check ISSLLibrary.GetCapabilities.SupportsCustomCipherSuites before installing a custom non-default cipher override.',
      [AFeature]),
    sslErrUnsupported,
    AMethodName,
    0,
    sslWolfSSL
  );
end;

procedure TWolfSSLContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Verify callback', 'TWolfSSLContext.SetVerifyCallback');
  FVerifyCallback := nil;
end;

{ 密码套件配置 }

procedure TWolfSSLContext.SetCipherList(const ACipherList: string);
begin
  if IsCustomCipherListOverride(ACipherList) then
    RejectUnsupportedCustomCipherAssignment('Cipher list', 'TWolfSSLContext.SetCipherList');
  FCipherList := ACipherList;
  // WolfSSL 密码套件设置需要额外 API
end;

function TWolfSSLContext.GetCipherList: string;
begin
  Result := FCipherList;
end;

procedure TWolfSSLContext.SetCipherSuites(const ACipherSuites: string);
begin
  if IsCustomCipherSuitesOverride(ACipherSuites) then
    RejectUnsupportedCustomCipherAssignment('Cipher suites', 'TWolfSSLContext.SetCipherSuites');
  FCipherSuites := ACipherSuites;
end;

function TWolfSSLContext.GetCipherSuites: string;
begin
  Result := FCipherSuites;
end;

{ 会话管理 }

procedure TWolfSSLContext.SetSessionCacheMode(AEnabled: Boolean);
begin
  FSessionCacheEnabled := AEnabled;
end;

function TWolfSSLContext.GetSessionCacheMode: Boolean;
begin
  Result := FSessionCacheEnabled;
end;

procedure TWolfSSLContext.SetSessionTimeout(ATimeout: Integer);
begin
  FSessionTimeout := ATimeout;
end;

function TWolfSSLContext.GetSessionTimeout: Integer;
begin
  Result := FSessionTimeout;
end;

procedure TWolfSSLContext.SetSessionCacheSize(ASize: Integer);
begin
  FSessionCacheSize := ASize;
end;

function TWolfSSLContext.GetSessionCacheSize: Integer;
begin
  Result := FSessionCacheSize;
end;

{ 高级选项 }

procedure TWolfSSLContext.SetOptions(const AOptions: TSSLOptions);
begin
  FOptions := AOptions;
  ApplyOCSPStaplingConfiguration;
end;

function TWolfSSLContext.GetOptions: TSSLOptions;
begin
  Result := FOptions;
end;

procedure TWolfSSLContext.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TWolfSSLContext.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TWolfSSLContext.SetALPNProtocols(const AProtocols: string);
begin
  FALPNProtocols := AProtocols;
end;

function TWolfSSLContext.GetALPNProtocols: string;
begin
  Result := FALPNProtocols;
end;

procedure TWolfSSLContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
  FCertVerifyFlags := AFlags;
end;

function TWolfSSLContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := FCertVerifyFlags;
end;

procedure TWolfSSLContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Password callback', 'TWolfSSLContext.SetPasswordCallback');
  FPasswordCallback := nil;
end;

procedure TWolfSSLContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Info callback', 'TWolfSSLContext.SetInfoCallback');
  FInfoCallback := nil;
end;

{ 证书固定 }

procedure TWolfSSLContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
var
  LIdx: Integer;
  LPin: TWolfSSLCertPin;
begin
  if Length(AHash) <> 32 then
    raise ESSLException.CreateWithContext(
      'Certificate pin hash must be 32 bytes (SHA-256)',
      sslErrInvalidParam,
      'TWolfSSLContext.AddCertificatePin'
    );

  // 初始化新的 pin
  FillChar(LPin, SizeOf(LPin), 0);
  Move(AHash[0], LPin.Hash[0], 32);
  LPin.PinType := APinType;
  LPin.Description := ADescription;
  LPin.IsBackup := AIsBackup;

  // 添加到数组
  LIdx := Length(FCertPins);
  SetLength(FCertPins, LIdx + 1);
  FCertPins[LIdx] := LPin;
end;

procedure TWolfSSLContext.AddCertificatePinBase64(const ABase64Hash: string;
  APinType: Integer; const ADescription: string; AIsBackup: Boolean);
var
  LHash: TBytes;
  LDecoded: AnsiString;
begin
  // 解码 Base64
  LDecoded := DecodeStringBase64(ABase64Hash);
  SetLength(LHash, Length(LDecoded));
  if Length(LDecoded) > 0 then
    Move(LDecoded[1], LHash[0], Length(LDecoded));

  if Length(LHash) <> 32 then
    raise ESSLException.CreateWithContext(
      Format('Invalid Base64 hash length: expected 32, got %d', [Length(LHash)]),
      sslErrInvalidParam,
      'TWolfSSLContext.AddCertificatePinBase64'
    );

  AddCertificatePin(LHash, APinType, ADescription, AIsBackup);
end;

procedure TWolfSSLContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
  FPinningEnabled := AEnabled;
end;

function TWolfSSLContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := FPinningEnabled;
end;

procedure TWolfSSLContext.ClearCertificatePins;
begin
  SetLength(FCertPins, 0);
  FPinningEnabled := False;
end;

function TWolfSSLContext.GetCertificatePins: TWolfSSLCertPinArray;
begin
  Result := FCertPins;
end;

{ 创建连接 }

function TWolfSSLContext.CreateConnection(ASocket: THandle): ISSLConnection;
var
  LExposeEarlyData: Boolean;
  LExposeOCSP: Boolean;
begin
  RequireValidContext('CreateConnection');

  LExposeEarlyData := HasEarlyDataCapability;
  LExposeOCSP := HasClientOCSPCapability;

  if LExposeEarlyData and LExposeOCSP then
    Result := nextpas.core.tls.wolfssl.connection.TWolfSSLAdvancedConnection.Create(Self, ASocket)
  else if LExposeEarlyData then
    Result := nextpas.core.tls.wolfssl.connection.TWolfSSLEarlyDataConnection.Create(Self, ASocket)
  else if LExposeOCSP then
    Result := nextpas.core.tls.wolfssl.connection.TWolfSSLOCSPConnection.Create(Self, ASocket)
  else
    Result := nextpas.core.tls.wolfssl.connection.TWolfSSLConnection.Create(Self, ASocket);
end;

function TWolfSSLContext.CreateConnection(AStream: TStream): ISSLConnection;
var
  LExposeEarlyData: Boolean;
  LExposeOCSP: Boolean;
begin
  RequireValidContext('CreateConnection');

  if AStream = nil then
    raise ESSLException.Create('Cannot create connection: stream is nil');

  // 检查 I/O 回调是否可用
  if not Assigned(wolfSSL_CTX_SetIORecv) or not Assigned(wolfSSL_CTX_SetIOSend) then
    raise ESSLException.Create('Stream-based connections require WolfSSL I/O callbacks which are not available');

  LExposeEarlyData := HasEarlyDataCapability;
  LExposeOCSP := HasClientOCSPCapability;

  if LExposeEarlyData and LExposeOCSP then
    Result := nextpas.core.tls.wolfssl.connection.TWolfSSLAdvancedConnection.Create(Self, AStream)
  else if LExposeEarlyData then
    Result := nextpas.core.tls.wolfssl.connection.TWolfSSLEarlyDataConnection.Create(Self, AStream)
  else if LExposeOCSP then
    Result := nextpas.core.tls.wolfssl.connection.TWolfSSLOCSPConnection.Create(Self, AStream)
  else
    Result := nextpas.core.tls.wolfssl.connection.TWolfSSLConnection.Create(Self, AStream);
end;

{ 状态查询 }

function TWolfSSLContext.IsValid: Boolean;
begin
  Result := FWolfSSLCtx <> nil;
end;

function TWolfSSLContext.GetNativeHandle: Pointer;
begin
  Result := FWolfSSLCtx;
end;

function TWolfSSLContext.GetBackendType: TSSLLibraryType;
begin
  Result := sslWolfSSL;
end;

function TWolfSSLContext.IsNativeHandleValid: Boolean;
begin
  Result := (FWolfSSLCtx <> nil);
end;

function TWolfSSLContext.GetHealthStatus: TSSLHealthStatus;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.IsConnected := False;  // Context doesn't have connection state
  Result.HandshakeComplete := False;
  Result.LastError := sslErrNone;
  Result.LastErrorTime := 0;
  Result.BytesSent := 0;
  Result.BytesReceived := 0;
  Result.ConnectionAge := 0;
end;

function TWolfSSLContext.IsHealthy: Boolean;
begin
  Result := IsValid;
end;

function TWolfSSLContext.GetDiagnosticInfo: TSSLDiagnosticInfo;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.HealthStatus := GetHealthStatus;
  Result.PerformanceMetrics := GetPerformanceMetrics;
  SetLength(Result.ErrorHistory, 0);
end;

function TWolfSSLContext.GetPerformanceMetrics: TSSLPerformanceMetrics;
begin
  FillChar(Result, SizeOf(Result), 0);
  // Context-level metrics are not tracked in this implementation
end;

procedure TWolfSSLContext.ConfigureSecureDefaults;
begin
  // 配置安全默认值
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FPreferredVersion := sslProtocolTLS13;
  FVerifyMode := [sslVerifyPeer];
  FVerifyDepth := 4;
  ApplyVerifyMode;
end;

// ============================================================================
// ISSLEarlyDataContext - TLS 1.3 Early Data 配置 (v1.4.2)
// ============================================================================

procedure TWolfSSLContext.SetClientEarlyDataEnabled(AEnabled: Boolean);
begin
  RequireValidContext('SetClientEarlyDataEnabled');
  FClientEarlyDataEnabled := AEnabled;

  // 注意：客户端不需要设置 max_early_data
  // WolfSSL 客户端会从服务端的 session ticket 中获取 max_early_data 值
  // 这里仅记录状态，不调用 wolfSSL_CTX_set_max_early_data
end;

function TWolfSSLContext.GetClientEarlyDataEnabled: Boolean;
begin
  Result := FClientEarlyDataEnabled;
end;

procedure TWolfSSLContext.SetServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy);
var
  LRet: Integer;
begin
  RequireValidContext('SetServerEarlyDataPolicy');

  // 根据策略设置 WolfSSL
  if Assigned(wolfSSL_CTX_set_max_early_data) then
  begin
    LRet := 1;
    case APolicy of
      sslEarlyDataServerReject:
        LRet := wolfSSL_CTX_set_max_early_data(FWolfSSLCtx, 0);
      sslEarlyDataServerAccept,
      sslEarlyDataServerIssueOnly:
        LRet := wolfSSL_CTX_set_max_early_data(FWolfSSLCtx, FServerMaxEarlyDataSize);
    end;

    if LRet <> 1 then
      raise ESSLException.CreateWithContext(
        Format('wolfSSL_CTX_set_max_early_data failed (policy=%d, return=%d)',
          [Ord(APolicy), LRet]),
        sslErrGeneral,
        'SetServerEarlyDataPolicy'
      );
  end;

  FServerEarlyDataPolicy := APolicy;
end;

function TWolfSSLContext.GetServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
begin
  Result := FServerEarlyDataPolicy;
end;

procedure TWolfSSLContext.SetServerMaxEarlyDataSize(ASize: Cardinal);
var
  LRet: Integer;
begin
  RequireValidContext('SetServerMaxEarlyDataSize');

  // 如果服务端 early data 已启用，更新 WolfSSL
  if Assigned(wolfSSL_CTX_set_max_early_data) and
    (FServerEarlyDataPolicy <> sslEarlyDataServerReject) then
  begin
    LRet := wolfSSL_CTX_set_max_early_data(FWolfSSLCtx, ASize);
    if LRet <> 1 then
      raise ESSLException.CreateWithContext(
        Format('wolfSSL_CTX_set_max_early_data failed (size=%d, return=%d)',
          [ASize, LRet]),
        sslErrGeneral,
        'SetServerMaxEarlyDataSize'
      );
  end;

  FServerMaxEarlyDataSize := ASize;
end;

function TWolfSSLContext.GetServerMaxEarlyDataSize: Cardinal;
begin
  Result := FServerMaxEarlyDataSize;
end;

// ============================================================================
// ISSLServerOCSPStaplingContext - 服务端 OCSP Stapling (v1.4.2)
// ============================================================================

procedure TWolfSSLContext.ClearServerStapledOCSPResponse;
begin
  RequireValidContext('ClearServerStapledOCSPResponse');
  SetLength(FServerStapledOCSPResponse, 0);
  ApplyOCSPStaplingConfiguration;
end;

procedure TWolfSSLContext.SetServerStapledOCSPResponse(const AResponseDER: TBytes);
begin
  RequireValidContext('SetServerStapledOCSPResponse');

  if Length(AResponseDER) = 0 then
    raise ESSLInvalidArgument.Create(
      'OCSP response cannot be empty',
      sslErrInvalidParam
    );

  FServerStapledOCSPResponse := Copy(AResponseDER);
  ApplyOCSPStaplingConfiguration;
end;

procedure TWolfSSLContext.LoadServerStapledOCSPResponseFile(const AFileName: string);
var
  LStream: TFileStream;
  LSize: Int64;
begin
  RequireValidContext('LoadServerStapledOCSPResponseFile');

  if not FileExists(AFileName) then
    raise ESSLException.CreateWithContext(
      Format('OCSP response file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'LoadServerStapledOCSPResponseFile'
    );

  try
    LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      LSize := LStream.Size;
      if LSize = 0 then
        raise ESSLInvalidArgument.Create(
          'OCSP response file is empty',
          sslErrInvalidParam
        );

      if LSize > MAX_OCSP_RESPONSE_SIZE then
        raise ESSLInvalidArgument.Create(
          Format('OCSP response file too large (%d bytes, max %d)',
            [LSize, MAX_OCSP_RESPONSE_SIZE]),
          sslErrInvalidParam
        );

      SetLength(FServerStapledOCSPResponse, LSize);
      LStream.ReadBuffer(FServerStapledOCSPResponse[0], LSize);
    finally
      LStream.Free;
    end;

    ApplyOCSPStaplingConfiguration;
  except
    on E: ESSLException do
      raise;
    on E: Exception do
      raise ESSLException.CreateWithContext(
        Format('Failed to load OCSP response file: %s', [E.Message]),
        sslErrLoadFailed,
        'LoadServerStapledOCSPResponseFile'
      );
  end;
end;

function TWolfSSLContext.HasServerStapledOCSPResponse: Boolean;
begin
  Result := Length(FServerStapledOCSPResponse) > 0;
end;

function TWolfSSLContext.GetServerStapledOCSPResponse: TBytes;
begin
  Result := Copy(FServerStapledOCSPResponse);
end;

end.
