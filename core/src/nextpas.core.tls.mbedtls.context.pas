{**
 * Unit: nextpas.core.tls.mbedtls.context
 * Purpose: MbedTLS 上下文实现
 *
 * 实现 ISSLContext 接口的 MbedTLS 后端。
 * 负责 SSL 配置管理和连接创建。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-10
 *}

unit nextpas.core.tls.mbedtls.context;

{$mode objfpc}{$H+}

interface

uses
  nextpas.core.base,
  Base64, nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.io.util,
  nextpas.core.io.stream_adapter,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.secure,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.native_handle,
  nextpas.core.tls.mbedtls.api;

type
  { 证书固定记录 }
  TMbedTLSCertPin = record
    Hash: array[0..31] of Byte;  // SHA-256 hash
    PinType: Integer;            // 0=Certificate, 1=PublicKey
    Description: string;
    IsBackup: Boolean;
  end;
  TMbedTLSCertPinArray = array of TMbedTLSCertPin;

  { TMbedTLSContext - MbedTLS 上下文类 }
  TMbedTLSContext = class(TInterfacedObject, ISSLContext, ISSLNativeHandleAccess)
  private
    FLibrary: ISSLLibrary;
    FContextType: TSSLContextType;
    FSSLConfig: Pmbedtls_ssl_config;
    FProtocolVersions: TSSLProtocolVersions;
    FPreferredVersion: TSSLProtocolVersion;
    FVerifyMode: TSSLVerifyModes;
    FVerifyDepth: Integer;
    FServerName: string;
    FCipherList: string;
    FCipherSuites: string;
    FALPNProtocols: string;
    FALPNProtocolsArray: array of PAnsiChar;  // NULL-terminated array for mbedtls
    FSessionCacheEnabled: Boolean;
    FSessionTimeout: Integer;
    FSessionCacheSize: Integer;
    FOptions: TSSLOptions;
    FCertVerifyFlags: TSSLCertVerifyFlags;

    // 回调
    FVerifyCallback: TSSLVerifyCallback;
    FPasswordCallback: TSSLPasswordCallback;
    FInfoCallback: TSSLInfoCallback;

    // 证书和密钥
    FCertChain: Pmbedtls_x509_crt;
    FPrivateKey: Pmbedtls_pk_context;
    FCACerts: Pmbedtls_x509_crt;

    // 证书固定
    FCertPins: TMbedTLSCertPinArray;
    FPinningEnabled: Boolean;

    procedure AllocateConfig;
    procedure FreeConfig;
    procedure ApplyVerifyMode;
    procedure ApplyCredentials;
    procedure RequireValidContext(const AMethodName: string);
    procedure RejectUnsupportedCallbackAssignment(
      const AFeature, AMethodName: string);
    procedure RejectUnsupportedCustomCipherAssignment(
      const AFeature, AMethodName: string);
    function ReadLimitedStreamBytes(const AStream: IStream; const AMaxSize: Int64;
      const ASubject: string): TBytes;

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
    procedure LoadCertificate(AStream: IStream); overload;
    procedure LoadCertificate(ACert: ISSLCertificate); overload;
    procedure LoadPrivateKey(const AFileName: string; const APassword: string = ''); overload;
    procedure LoadPrivateKey(AStream: IStream; const APassword: string = ''); overload;
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

    { 证书固定访问（供 Connection 使用）}
    function GetCertificatePins: TMbedTLSCertPinArray;

    { ISSLContext - 创建连接 }
    function CreateConnection(ASocket: THandle): ISSLConnection; overload;
    function CreateConnection(AStream: IStream): ISSLConnection; overload;

    { ISSLContext - 状态查询 }
    function IsValid: Boolean;

    { ISSLNativeHandleAccess implementation }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    { 便利方法 }
    procedure ConfigureSecureDefaults;

    { 内部访问 }
    property SSLConfig: Pmbedtls_ssl_config read FSSLConfig;
  end;

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
    nextpas.core.tls.mbedtls.lib,
  nextpas.core.tls.mbedtls.certificate,
  nextpas.core.tls.mbedtls.session,
  nextpas.core.tls.mbedtls.connection;

const
  // MbedTLS structure sizes - use large buffers for safety
  // Actual sizes depend on MbedTLS compile-time configuration
  MBEDTLS_SSL_CONFIG_SIZE = 8192;
  MBEDTLS_X509_CRT_SIZE = 16384;
  MBEDTLS_PK_CONTEXT_SIZE = 2048;

{ TMbedTLSContext }

constructor TMbedTLSContext.Create(ALibrary: ISSLLibrary; AType: TSSLContextType);
begin
  inherited Create;
  FLibrary := ALibrary;
  FContextType := AType;
  FSSLConfig := nil;
  FCertChain := nil;
  FPrivateKey := nil;
  FCACerts := nil;
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

  AllocateConfig;
  ApplyVerifyMode;
end;

destructor TMbedTLSContext.Destroy;
var
  I: Integer;
begin
  // 清理 ALPN 协议数组
  for I := 0 to High(FALPNProtocolsArray) do
    if FALPNProtocolsArray[I] <> nil then
      StrDispose(FALPNProtocolsArray[I]);
  SetLength(FALPNProtocolsArray, 0);

  FreeConfig;
  FLibrary := nil;
  inherited Destroy;
end;

function TMbedTLSContext.ReadLimitedStreamBytes(const AStream: IStream;
  const AMaxSize: Int64; const ASubject: string): TBytes;
var
  LReader: IReader;
begin
  if AStream = nil then
    raise ESSLCertError.Create('Stream is nil');

  LReader := IoLimitReader(AStream, AMaxSize + 1);
  Result := IoReadAll(LReader);

  if Length(Result) = 0 then
    raise ESSLCertError.Create('Stream is empty');
  if Length(Result) > AMaxSize then
    raise ESSLInvalidArgument.CreateFmt(
      '%s exceeds maximum allowed size (%d > %d bytes)',
      [ASubject, Length(Result), AMaxSize]
    );
end;

procedure TMbedTLSContext.AllocateConfig;
var
  LEndpoint: Integer;
  LLib: TMbedTLSLibrary;
  LObj: TObject;
begin
  if FSSLConfig <> nil then
    FreeConfig;

  // 分配 SSL 配置
  GetMem(FSSLConfig, MBEDTLS_SSL_CONFIG_SIZE);
  FillChar(FSSLConfig^, MBEDTLS_SSL_CONFIG_SIZE, 0);

  if Assigned(mbedtls_ssl_config_init) then
    mbedtls_ssl_config_init(FSSLConfig);

  // 设置端点类型
  case FContextType of
    sslCtxClient: LEndpoint := MBEDTLS_SSL_IS_CLIENT;
    sslCtxServer: LEndpoint := MBEDTLS_SSL_IS_SERVER;
  else
    LEndpoint := MBEDTLS_SSL_IS_CLIENT;
  end;

  // 配置默认值
  if Assigned(mbedtls_ssl_config_defaults) then
    mbedtls_ssl_config_defaults(FSSLConfig, LEndpoint,
      MBEDTLS_SSL_TRANSPORT_STREAM, MBEDTLS_SSL_PRESET_DEFAULT);

  // 配置 RNG - 从 Library 获取 CTR_DRBG 上下文
  if Assigned(mbedtls_ssl_conf_rng) and Assigned(mbedtls_ctr_drbg_random) then
  begin
    if FLibrary <> nil then
    begin
      LObj := FLibrary as TObject;
      if LObj is TMbedTLSLibrary then
      begin
        LLib := TMbedTLSLibrary(LObj);
        if LLib.GetCtrDrbgContext <> nil then
          mbedtls_ssl_conf_rng(FSSLConfig, Tmbedtls_f_rng(mbedtls_ctr_drbg_random), LLib.GetCtrDrbgContext);
      end;
    end;
  end;
end;

procedure TMbedTLSContext.FreeConfig;
begin
  // 释放证书链
  if FCertChain <> nil then
  begin
    if Assigned(mbedtls_x509_crt_free) then
      mbedtls_x509_crt_free(FCertChain);
    FreeMem(FCertChain);
    FCertChain := nil;
  end;

  // 释放私钥
  if FPrivateKey <> nil then
  begin
    if Assigned(mbedtls_pk_free) then
      mbedtls_pk_free(FPrivateKey);
    FreeMem(FPrivateKey);
    FPrivateKey := nil;
  end;

  // 释放 CA 证书
  if FCACerts <> nil then
  begin
    if Assigned(mbedtls_x509_crt_free) then
      mbedtls_x509_crt_free(FCACerts);
    FreeMem(FCACerts);
    FCACerts := nil;
  end;

  // 释放 SSL 配置
  if FSSLConfig <> nil then
  begin
    if Assigned(mbedtls_ssl_config_free) then
      mbedtls_ssl_config_free(FSSLConfig);
    FreeMem(FSSLConfig);
    FSSLConfig := nil;
  end;
end;

procedure TMbedTLSContext.ApplyVerifyMode;
var
  LMode: Integer;
begin
  if FSSLConfig = nil then Exit;
  if not Assigned(mbedtls_ssl_conf_authmode) then Exit;

  if sslVerifyNone in FVerifyMode then
    LMode := MBEDTLS_SSL_VERIFY_NONE
  else if sslVerifyPeer in FVerifyMode then
  begin
    if sslVerifyFailIfNoPeerCert in FVerifyMode then
      LMode := MBEDTLS_SSL_VERIFY_REQUIRED
    else
      LMode := MBEDTLS_SSL_VERIFY_OPTIONAL;
  end
  else
    LMode := MBEDTLS_SSL_VERIFY_NONE;

  mbedtls_ssl_conf_authmode(FSSLConfig, LMode);
end;

procedure TMbedTLSContext.ApplyCredentials;
var
  LRet: Integer;
begin
  if FSSLConfig = nil then Exit;

  // 配置 CA 证书链（用于验证对端）
  if (FCACerts <> nil) and Assigned(mbedtls_ssl_conf_ca_chain) then
    mbedtls_ssl_conf_ca_chain(FSSLConfig, FCACerts, nil);

  // 配置自己的证书和私钥（用于服务端或客户端认证）
  if (FCertChain <> nil) and (FPrivateKey <> nil) and Assigned(mbedtls_ssl_conf_own_cert) then
  begin
    LRet := mbedtls_ssl_conf_own_cert(FSSLConfig, FCertChain, FPrivateKey);
    if LRet <> 0 then
      raise ESSLCertError.CreateFmt('Failed to configure own certificate: error 0x%x', [-LRet]);
  end;
end;

procedure TMbedTLSContext.RequireValidContext(const AMethodName: string);
begin
  if FSSLConfig = nil then
    raise ESSLException.CreateFmt('%s: MbedTLS context is not valid', [AMethodName]);
end;

function TMbedTLSContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TMbedTLSContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
  FProtocolVersions := AVersions;

  // 当首选版本不再可用时，自动回退为无偏好
  if (FPreferredVersion <> sslProtocolUnknown) and
    not (FPreferredVersion in FProtocolVersions) then
    FPreferredVersion := sslProtocolUnknown;
end;

function TMbedTLSContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := FProtocolVersions;
end;

procedure TMbedTLSContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
  if (AVersion <> sslProtocolUnknown) and
    not (AVersion in FProtocolVersions) then
    RaiseInvalidParameter('PreferredVersion');

  FPreferredVersion := AVersion;
end;

function TMbedTLSContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := FPreferredVersion;
end;

{ 证书和密钥管理 }

procedure TMbedTLSContext.LoadCertificate(const AFileName: string);
var
  LSize: Int64;
begin
  RequireValidContext('LoadCertificate');

  if AFileName = '' then
    raise ESSLInvalidArgument.Create('AFileName must not be empty');

  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLCertError.CreateFmt('Certificate file not found: %s', [AFileName]);

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CERTIFICATE_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Certificate file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CERTIFICATE_SIZE, AFileName]);

  // 分配证书链
  if FCertChain = nil then
  begin
    GetMem(FCertChain, MBEDTLS_X509_CRT_SIZE);
    FillChar(FCertChain^, MBEDTLS_X509_CRT_SIZE, 0);
    if Assigned(mbedtls_x509_crt_init) then
      mbedtls_x509_crt_init(FCertChain);
  end;

  if not Assigned(mbedtls_x509_crt_parse_file) then
    raise ESSLCertError.Create('mbedtls_x509_crt_parse_file not available');

  if mbedtls_x509_crt_parse_file(FCertChain, PAnsiChar(AnsiString(AFileName))) <> 0 then
    raise ESSLCertError.CreateFmt('Failed to load certificate: %s', [AFileName]);
end;

procedure TMbedTLSContext.LoadCertificate(AStream: IStream);
var
  LData: TBytes;
  LReadData: TBytes;
begin
  RequireValidContext('LoadCertificate');

  if AStream = nil then
    raise ESSLCertError.Create('Stream is nil');

  LReadData := ReadLimitedStreamBytes(
    WrapIStream(AStream, False),
    MAX_CERTIFICATE_SIZE,
    'Certificate stream'
  );
  SetLength(LData, Length(LReadData) + 1);
  Move(LReadData[0], LData[0], Length(LReadData));
  LData[High(LData)] := 0;

  // 分配证书链
  if FCertChain = nil then
  begin
    GetMem(FCertChain, MBEDTLS_X509_CRT_SIZE);
    FillChar(FCertChain^, MBEDTLS_X509_CRT_SIZE, 0);
    if Assigned(mbedtls_x509_crt_init) then
      mbedtls_x509_crt_init(FCertChain);
  end;

  if not Assigned(mbedtls_x509_crt_parse) then
    raise ESSLCertError.Create('mbedtls_x509_crt_parse not available');

  if mbedtls_x509_crt_parse(FCertChain, @LData[0], Length(LData)) <> 0 then
    raise ESSLCertError.Create('Failed to load certificate from stream');
end;

procedure TMbedTLSContext.LoadCertificate(ACert: ISSLCertificate);
var
  LPEMData: string;
  LAnsi: AnsiString;
begin
  RequireValidContext('LoadCertificate');

  if ACert = nil then
    raise ESSLCertError.Create('Certificate is nil');

  // 尝试从证书获取 PEM 数据
  LPEMData := ACert.SaveToPEM;
  if LPEMData = '' then
    raise ESSLCertError.Create('Cannot get PEM data from certificate');

  LAnsi := AnsiString(LPEMData);

  // 分配证书链
  if FCertChain = nil then
  begin
    GetMem(FCertChain, MBEDTLS_X509_CRT_SIZE);
    FillChar(FCertChain^, MBEDTLS_X509_CRT_SIZE, 0);
    if Assigned(mbedtls_x509_crt_init) then
      mbedtls_x509_crt_init(FCertChain);
  end;

  if not Assigned(mbedtls_x509_crt_parse) then
    raise ESSLCertError.Create('mbedtls_x509_crt_parse not available');

  if mbedtls_x509_crt_parse(FCertChain, PByte(PAnsiChar(LAnsi)), Length(LAnsi) + 1) <> 0 then
    raise ESSLCertError.Create('Failed to load certificate from ISSLCertificate');
end;

procedure TMbedTLSContext.LoadPrivateKey(const AFileName: string; const APassword: string);
var
  LSize: Int64;
begin
  RequireValidContext('LoadPrivateKey');

  if AFileName = '' then
    raise ESSLInvalidArgument.Create('AFileName must not be empty');

  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLCertError.CreateFmt('Private key file not found: %s', [AFileName]);

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_PRIVATE_KEY_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Private key file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_PRIVATE_KEY_SIZE, AFileName]);

  // 分配私钥上下文
  if FPrivateKey = nil then
  begin
    GetMem(FPrivateKey, MBEDTLS_PK_CONTEXT_SIZE);
    FillChar(FPrivateKey^, MBEDTLS_PK_CONTEXT_SIZE, 0);
    if Assigned(mbedtls_pk_init) then
      mbedtls_pk_init(FPrivateKey);
  end;

  if not Assigned(mbedtls_pk_parse_keyfile) then
    raise ESSLCertError.Create('mbedtls_pk_parse_keyfile not available');

  if mbedtls_pk_parse_keyfile(FPrivateKey, PAnsiChar(AnsiString(AFileName)),
    PAnsiChar(AnsiString(APassword)), nil, nil) <> 0 then
    raise ESSLCertError.CreateFmt('Failed to load private key: %s', [AFileName]);
end;

procedure TMbedTLSContext.LoadPrivateKey(AStream: IStream; const APassword: string);
var
  LData: TBytes;
  LReadData: TBytes;
  LPwd: PAnsiChar;
  LPwdLen: NativeUInt;
begin
  RequireValidContext('LoadPrivateKey');

  if AStream = nil then
    raise ESSLCertError.Create('Stream is nil');

  LReadData := ReadLimitedStreamBytes(
    WrapIStream(AStream, False),
    MAX_PRIVATE_KEY_SIZE,
    'Private key stream'
  );
  SetLength(LData, Length(LReadData) + 1);
  Move(LReadData[0], LData[0], Length(LReadData));
  LData[High(LData)] := 0;

  // 分配私钥上下文
  if FPrivateKey = nil then
  begin
    GetMem(FPrivateKey, MBEDTLS_PK_CONTEXT_SIZE);
    FillChar(FPrivateKey^, MBEDTLS_PK_CONTEXT_SIZE, 0);
    if Assigned(mbedtls_pk_init) then
      mbedtls_pk_init(FPrivateKey);
  end;

  if not Assigned(mbedtls_pk_parse_key) then
    raise ESSLCertError.Create('mbedtls_pk_parse_key not available');

  // 设置密码
  if APassword <> '' then
  begin
    LPwd := PAnsiChar(AnsiString(APassword));
    LPwdLen := Length(APassword);
  end
  else
  begin
    LPwd := nil;
    LPwdLen := 0;
  end;

  if mbedtls_pk_parse_key(FPrivateKey, @LData[0], Length(LData),
    PByte(LPwd), LPwdLen, nil, nil) <> 0 then
    raise ESSLCertError.Create('Failed to load private key from stream');
end;

procedure TMbedTLSContext.LoadCertificatePEM(const APEM: string);
var
  LAnsi: AnsiString;
begin
  RequireValidContext('LoadCertificatePEM');

  if APEM = '' then
    raise ESSLCertError.Create('PEM string is empty');

  LAnsi := AnsiString(APEM);

  // 分配证书链
  if FCertChain = nil then
  begin
    GetMem(FCertChain, MBEDTLS_X509_CRT_SIZE);
    FillChar(FCertChain^, MBEDTLS_X509_CRT_SIZE, 0);
    if Assigned(mbedtls_x509_crt_init) then
      mbedtls_x509_crt_init(FCertChain);
  end;

  if not Assigned(mbedtls_x509_crt_parse) then
    raise ESSLCertError.Create('mbedtls_x509_crt_parse not available');

  // MbedTLS PEM 解析需要 null 终止
  if mbedtls_x509_crt_parse(FCertChain, PByte(PAnsiChar(LAnsi)), Length(LAnsi) + 1) <> 0 then
    raise ESSLCertError.Create('Failed to load certificate from PEM string');
end;

procedure TMbedTLSContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string);
var
  LAnsi: AnsiString;
  LPwd: PAnsiChar;
  LPwdLen: NativeUInt;
begin
  RequireValidContext('LoadPrivateKeyPEM');

  if APEM = '' then
    raise ESSLCertError.Create('PEM string is empty');

  LAnsi := AnsiString(APEM);

  // 分配私钥上下文
  if FPrivateKey = nil then
  begin
    GetMem(FPrivateKey, MBEDTLS_PK_CONTEXT_SIZE);
    FillChar(FPrivateKey^, MBEDTLS_PK_CONTEXT_SIZE, 0);
    if Assigned(mbedtls_pk_init) then
      mbedtls_pk_init(FPrivateKey);
  end;

  if not Assigned(mbedtls_pk_parse_key) then
    raise ESSLCertError.Create('mbedtls_pk_parse_key not available');

  // 设置密码
  if APassword <> '' then
  begin
    LPwd := PAnsiChar(AnsiString(APassword));
    LPwdLen := Length(APassword);
  end
  else
  begin
    LPwd := nil;
    LPwdLen := 0;
  end;

  // MbedTLS PEM 解析需要 null 终止
  if mbedtls_pk_parse_key(FPrivateKey, PByte(PAnsiChar(LAnsi)), Length(LAnsi) + 1,
    PByte(LPwd), LPwdLen, nil, nil) <> 0 then
    raise ESSLCertError.Create('Failed to load private key from PEM string');
end;

procedure TMbedTLSContext.LoadCAFile(const AFileName: string);
var
  LSize: Int64;
begin
  RequireValidContext('LoadCAFile');

  if AFileName = '' then
    raise ESSLInvalidArgument.Create('AFileName must not be empty');

  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLCertError.CreateFmt('CA file not found: %s', [AFileName]);

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CA_CHAIN_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'CA file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CA_CHAIN_SIZE, AFileName]);

  // 分配 CA 证书
  if FCACerts = nil then
  begin
    GetMem(FCACerts, MBEDTLS_X509_CRT_SIZE);
    FillChar(FCACerts^, MBEDTLS_X509_CRT_SIZE, 0);
    if Assigned(mbedtls_x509_crt_init) then
      mbedtls_x509_crt_init(FCACerts);
  end;

  if not Assigned(mbedtls_x509_crt_parse_file) then
    raise ESSLCertError.Create('mbedtls_x509_crt_parse_file not available');

  if mbedtls_x509_crt_parse_file(FCACerts, PAnsiChar(AnsiString(AFileName))) <> 0 then
    raise ESSLCertError.CreateFmt('Failed to load CA file: %s', [AFileName]);

  // 设置 CA 链
  if Assigned(mbedtls_ssl_conf_ca_chain) then
    mbedtls_ssl_conf_ca_chain(FSSLConfig, FCACerts, nil);
end;

procedure TMbedTLSContext.LoadCAPath(const APath: string);
begin
  RequireValidContext('LoadCAPath');

  if not nextpas.core.fs.IsDir(APath) then
    raise ESSLCertError.CreateFmt('CA path not found: %s', [APath]);

  // 分配 CA 证书
  if FCACerts = nil then
  begin
    GetMem(FCACerts, MBEDTLS_X509_CRT_SIZE);
    FillChar(FCACerts^, MBEDTLS_X509_CRT_SIZE, 0);
    if Assigned(mbedtls_x509_crt_init) then
      mbedtls_x509_crt_init(FCACerts);
  end;

  if not Assigned(mbedtls_x509_crt_parse_path) then
    raise ESSLCertError.Create('mbedtls_x509_crt_parse_path not available');

  if mbedtls_x509_crt_parse_path(FCACerts, PAnsiChar(AnsiString(APath))) < 0 then
    raise ESSLCertError.CreateFmt('Failed to load CA path: %s', [APath]);

  if Assigned(mbedtls_ssl_conf_ca_chain) then
    mbedtls_ssl_conf_ca_chain(FSSLConfig, FCACerts, nil);
end;

procedure TMbedTLSContext.SetCertificateStore(AStore: ISSLCertificateStore);
var
  LCACerts: Pmbedtls_x509_crt;
begin
  RequireValidContext('SetCertificateStore');

  if AStore = nil then
    raise ESSLCertError.Create('Certificate store is nil');

  // 获取存储的原生句柄（CA 证书链）
  LCACerts := Pmbedtls_x509_crt(GetNativeHandleSafe(AStore, 'TMbedTLSContext.SetCertificateStore'));
  if LCACerts = nil then
    raise ESSLCertError.Create('Certificate store has no CA certificates');

  // 设置 CA 链到 SSL 配置
  if Assigned(mbedtls_ssl_conf_ca_chain) then
    mbedtls_ssl_conf_ca_chain(FSSLConfig, LCACerts, nil)
  else
    raise ESSLCertError.Create('mbedtls_ssl_conf_ca_chain not available');
end;

{ 验证配置 }

procedure TMbedTLSContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
  FVerifyMode := AMode;
  ApplyVerifyMode;
end;

function TMbedTLSContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := FVerifyMode;
end;

procedure TMbedTLSContext.SetVerifyDepth(ADepth: Integer);
begin
  FVerifyDepth := ADepth;
end;

function TMbedTLSContext.GetVerifyDepth: Integer;
begin
  Result := FVerifyDepth;
end;

procedure TMbedTLSContext.RejectUnsupportedCallbackAssignment(
  const AFeature, AMethodName: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    nextpas.core.text.conv.Format('%s is not published by the current MbedTLS backend runtime. ' +
      'Check ISSLLibrary.GetCapabilities.SupportsCallbacks before installing a non-nil callback.',
      [AFeature]),
    sslErrUnsupported,
    AMethodName,
    0,
    sslMbedTLS
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

procedure TMbedTLSContext.RejectUnsupportedCustomCipherAssignment(
  const AFeature, AMethodName: string);
begin
  raise ESSLConfigurationException.CreateWithContext(
    nextpas.core.text.conv.Format('%s is not published by the current MbedTLS backend runtime. ' +
      'Check ISSLLibrary.GetCapabilities.SupportsCustomCipherSuites before installing a custom non-default cipher override.',
      [AFeature]),
    sslErrUnsupported,
    AMethodName,
    0,
    sslMbedTLS
  );
end;

procedure TMbedTLSContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Verify callback', 'TMbedTLSContext.SetVerifyCallback');
  FVerifyCallback := nil;
end;

{ 密码套件配置 }

procedure TMbedTLSContext.SetCipherList(const ACipherList: string);
begin
  if IsCustomCipherListOverride(ACipherList) then
    RejectUnsupportedCustomCipherAssignment('Cipher list', 'TMbedTLSContext.SetCipherList');
  FCipherList := ACipherList;
end;

function TMbedTLSContext.GetCipherList: string;
begin
  Result := FCipherList;
end;

procedure TMbedTLSContext.SetCipherSuites(const ACipherSuites: string);
begin
  if IsCustomCipherSuitesOverride(ACipherSuites) then
    RejectUnsupportedCustomCipherAssignment('Cipher suites', 'TMbedTLSContext.SetCipherSuites');
  FCipherSuites := ACipherSuites;
end;

function TMbedTLSContext.GetCipherSuites: string;
begin
  Result := FCipherSuites;
end;

{ 会话管理 }

procedure TMbedTLSContext.SetSessionCacheMode(AEnabled: Boolean);
begin
  FSessionCacheEnabled := AEnabled;
end;

function TMbedTLSContext.GetSessionCacheMode: Boolean;
begin
  Result := FSessionCacheEnabled;
end;

procedure TMbedTLSContext.SetSessionTimeout(ATimeout: Integer);
begin
  FSessionTimeout := ATimeout;
end;

function TMbedTLSContext.GetSessionTimeout: Integer;
begin
  Result := FSessionTimeout;
end;

procedure TMbedTLSContext.SetSessionCacheSize(ASize: Integer);
begin
  FSessionCacheSize := ASize;
end;

function TMbedTLSContext.GetSessionCacheSize: Integer;
begin
  Result := FSessionCacheSize;
end;

{ 高级选项 }

procedure TMbedTLSContext.SetOptions(const AOptions: TSSLOptions);
begin
  FOptions := AOptions;
end;

function TMbedTLSContext.GetOptions: TSSLOptions;
begin
  Result := FOptions;
end;

procedure TMbedTLSContext.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TMbedTLSContext.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TMbedTLSContext.SetALPNProtocols(const AProtocols: string);
var
  LProtos: TStringArray;
  I, LRet: Integer;
begin
  FALPNProtocols := AProtocols;

  // 清理旧的数组
  for I := 0 to High(FALPNProtocolsArray) do
    if FALPNProtocolsArray[I] <> nil then
      StrDispose(FALPNProtocolsArray[I]);
  SetLength(FALPNProtocolsArray, 0);

  if FSSLConfig = nil then Exit;
  if AProtocols = '' then Exit;
  if not Assigned(mbedtls_ssl_conf_alpn_protocols) then Exit;

  // 解析逗号分隔的协议列表
  try

    if Length(LProtos) = 0 then Exit;

    // 构建 NULL-terminated 数组 (需要额外一个 nil 结尾)
    SetLength(FALPNProtocolsArray, Length(LProtos) + 1);
    for I := 0 to Length(LProtos) - 1 do
      FALPNProtocolsArray[I] := StrNew(PAnsiChar(AnsiString(Trim(LProtos[I]))));
    FALPNProtocolsArray[Length(LProtos)] := nil;  // NULL 终止

    // 配置到 mbedtls
    LRet := mbedtls_ssl_conf_alpn_protocols(FSSLConfig, @FALPNProtocolsArray[0]);
    if LRet <> 0 then
      raise ESSLException.CreateFmt('Failed to set ALPN protocols: 0x%04X', [-LRet]);
  finally
  end;
end;

function TMbedTLSContext.GetALPNProtocols: string;
begin
  Result := FALPNProtocols;
end;

procedure TMbedTLSContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
begin
  FCertVerifyFlags := AFlags;
end;

function TMbedTLSContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := FCertVerifyFlags;
end;

procedure TMbedTLSContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Password callback', 'TMbedTLSContext.SetPasswordCallback');
  FPasswordCallback := nil;
end;

procedure TMbedTLSContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
  if Assigned(ACallback) then
    RejectUnsupportedCallbackAssignment('Info callback', 'TMbedTLSContext.SetInfoCallback');
  FInfoCallback := nil;
end;

{ 证书固定 }

procedure TMbedTLSContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
var
  LIdx: Integer;
  LPin: TMbedTLSCertPin;
begin
  if Length(AHash) <> 32 then
    raise ESSLException.CreateWithContext(
      'Certificate pin hash must be 32 bytes (SHA-256)',
      sslErrInvalidParam,
      'TMbedTLSContext.AddCertificatePin'
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

procedure TMbedTLSContext.AddCertificatePinBase64(const ABase64Hash: string;
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
      nextpas.core.text.conv.Format('Invalid Base64 hash length: expected 32, got %d', [Length(LHash)]),
      sslErrInvalidParam,
      'TMbedTLSContext.AddCertificatePinBase64'
    );

  AddCertificatePin(LHash, APinType, ADescription, AIsBackup);
end;

procedure TMbedTLSContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
  FPinningEnabled := AEnabled;
end;

function TMbedTLSContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := FPinningEnabled;
end;

procedure TMbedTLSContext.ClearCertificatePins;
begin
  SetLength(FCertPins, 0);
  FPinningEnabled := False;
end;

function TMbedTLSContext.GetCertificatePins: TMbedTLSCertPinArray;
begin
  Result := FCertPins;
end;

{ 创建连接 }

function TMbedTLSContext.CreateConnection(ASocket: THandle): ISSLConnection;
begin
  RequireValidContext('CreateConnection');

  // 在创建连接前应用证书凭据
  ApplyCredentials;

  try
    Result := TMbedTLSConnection.Create(Self as ISSLContext, FSSLConfig, ASocket);
  except
    on E: ESSLException do
      raise;
    on E: Exception do
      raise ESSLException.CreateFmt('Failed to create MbedTLS connection: %s', [E.Message]);
  end;
end;

function TMbedTLSContext.CreateConnection(AStream: IStream): ISSLConnection;
begin
  RequireValidContext('CreateConnection');

  if AStream = nil then
    raise ESSLException.Create('Cannot create connection: stream is nil');

  // 在创建连接前应用证书凭据
  ApplyCredentials;

  try
    Result := TMbedTLSConnection.Create(Self as ISSLContext, FSSLConfig, WrapIStream(AStream, False));
  except
    on E: ESSLException do
      raise;
    on E: Exception do
      raise ESSLException.CreateFmt('Failed to create MbedTLS stream connection: %s', [E.Message]);
  end;
end;

{ 状态查询 }

function TMbedTLSContext.IsValid: Boolean;
begin
  Result := FSSLConfig <> nil;
end;

function TMbedTLSContext.GetNativeHandle: Pointer;
begin
  Result := FSSLConfig;
end;

function TMbedTLSContext.GetBackendType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TMbedTLSContext.IsNativeHandleValid: Boolean;
begin
  Result := (FSSLConfig <> nil);
end;

procedure TMbedTLSContext.ConfigureSecureDefaults;
begin
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FPreferredVersion := sslProtocolTLS13;
  FVerifyMode := [sslVerifyPeer];
  FVerifyDepth := 4;
  ApplyVerifyMode;
end;

// MbedTLS 后端不暴露 ISSLEarlyDataContext / ISSLServerOCSPStaplingContext
// 原因：MbedTLS 3.x API 不完整，等待 MbedTLS 4.x

end.
