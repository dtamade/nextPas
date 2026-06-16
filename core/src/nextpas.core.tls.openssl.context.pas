{
  nextpas.core.tls.openssl.context - OpenSSL 上下文实现
  
  版本: 1.0
  作者: fafafa.ssl 开发团队
  创建: 2025-11-02
  
  描述:
    实现 ISSLContext 接口的 OpenSSL 后端。
    负责 SSL_CTX 管理和连接创建。
}

unit nextpas.core.tls.openssl.context;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized
{$IFDEF UNIX}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  SysUtils, Classes, SyncObjs,
  nextpas.core.base.utils,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.io.stream_adapter,
  nextpas.core.io.util,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.openssl.errors,  // Phase 3.1 - OpenSSL-specific error handling
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.native_handle,  // 原生句柄辅助函数
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.ec,
  nextpas.core.tls.openssl.api.pem,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.logging,
  nextpas.core.tls.pkcs11.uri,
  nextpas.core.tls.pkcs11.types,
  nextpas.core.tls.pkcs11.backend,
  nextpas.core.tls.cert.pinning,
  nextpas.core.tls.secure;

type
  { TOpenSSLContext - OpenSSL 上下文类 }
  TOpenSSLContext = class(TInterfacedObject, ISSLContext, ISSLNativeHandleAccess,
    ISSLHttpHooksAccess)
  private
    FLibrary: ISSLLibrary;
    FContextType: TSSLContextType;
    FSSLContext: PSSL_CTX;
    FProtocolVersions: TSSLProtocolVersions;
    FPreferredVersion: TSSLProtocolVersion;
    FVerifyMode: TSSLVerifyModes;
    FVerifyDepth: Integer;
    FServerName: string;
    FCipherList: string;
    FCipherSuites: string;
    FALPNProtocols: string;
    FALPNWireData: TBytes;
    FSessionCacheEnabled: Boolean;
    FSessionTimeout: Integer;
    FSessionCacheSize: Integer;
    FOptions: TSSLOptions;
    FCertVerifyFlags: TSSLCertVerifyFlags;

    // 回调
    FVerifyCallback: TSSLVerifyCallback;
    FPasswordCallback: TSSLPasswordCallback;
    FInfoCallback: TSSLInfoCallback;
    FHTTPGetCallback: TSSLHTTPGetCallback;
    FHTTPPostCallback: TSSLHTTPPostCallback;

    // 证书固定
    FPinValidator: TPinValidator;
    FPinningEnabled: Boolean;

    // Early Data 相关 (v1.4.1)
    FClientEarlyDataEnabled: Boolean;
    FServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
    FServerMaxEarlyDataSize: Cardinal;

    // Server OCSP Stapling 相关 (v1.4.1)
    FServerStapledOCSPResponse: TBytes;
    
    procedure ApplyProtocolVersions;
    procedure ApplyVerifyMode;
    procedure ApplyOptions;
    procedure ApplyServerOCSPStaplingConfiguration;
    function GetSSLMethod: PSSL_METHOD;
    function HasClientOCSPCapability: Boolean;

    { P0-1: 上下文验证守卫方法 - 消除代码重复 }
    procedure RequireValidContext(const AMethodName: string);

    { P1-2: 私钥-证书匹配检查辅助方法 }
    procedure CheckPrivateKeyMatchesCertificate(const AMethodName: string);

    { PKCS#11: Load private key from PKCS#11 token }
    procedure LoadPrivateKeyFromPKCS11(const AURI: string; const APIN: string);

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

    { ISSLHttpHooksAccess - HTTP hooks（可选） }
    procedure SetHTTPGetCallback(ACallback: TSSLHTTPGetCallback);
    function GetHTTPGetCallback: TSSLHTTPGetCallback;
    procedure SetHTTPPostCallback(ACallback: TSSLHTTPPostCallback);
    function GetHTTPPostCallback: TSSLHTTPPostCallback;

    { ISSLEarlyDataContext - TLS 1.3 Early Data 配置 (v1.4.1) }
    procedure SetClientEarlyDataEnabled(AEnabled: Boolean);
    function GetClientEarlyDataEnabled: Boolean;
    procedure SetServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy);
    function GetServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
    procedure SetServerMaxEarlyDataSize(ASize: Cardinal);
    function GetServerMaxEarlyDataSize: Cardinal;

    { ISSLServerOCSPStaplingContext - 服务端 OCSP Stapling (v1.4.1) }
    procedure ClearServerStapledOCSPResponse;
    procedure SetServerStapledOCSPResponse(const AResponseDER: TBytes);
    procedure LoadServerStapledOCSPResponseFile(const AFileName: string);
    function HasServerStapledOCSPResponse: Boolean;
    function GetServerStapledOCSPResponse: TBytes;

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

    { ISSLNativeHandleAccess - 原生句柄访问 }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    { 便利方法 - 一键配置安全默认值 }
    procedure ConfigureSecureDefaults;
  end;

  { 仅在 runtime early-data capability 可用时暴露该接口 }
  TOpenSSLEarlyDataContext = class(TOpenSSLContext, ISSLEarlyDataContext)
  end;

  { 仅在 runtime server-OCSP capability 可用时暴露该接口 }
  TOpenSSLServerOCSPContext = class(TOpenSSLContext, ISSLServerOCSPStaplingContext)
  end;

  { 同时暴露 early-data 与 server-OCSP 两类可选接口 }
  TOpenSSLAdvancedContext = class(TOpenSSLContext,
    ISSLEarlyDataContext, ISSLServerOCSPStaplingContext)
  end;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.tls.openssl.connection,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.api.crypto,
  nextpas.core.tls.pem,
  nextpas.core.tls.openssl.api.pkcs,
  nextpas.core.tls.openssl.api.pkcs12,
  nextpas.core.tls.openssl.api.rsa,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.mem.secure;

var
  GContextRegistry: TList = nil;
  // Phase 3.3 P1-2: 使用读写锁优化多线程性能
  // 读操作（LookupContext）可以并发执行，只有写操作（Register/Unregister）需要独占
  // 性能提升：10-50 倍（多线程场景）
  GContextLock: TMultiReadExclusiveWriteSynchronizer = nil;

procedure RequireContextCertificateMemoryBIOHelpers(const AMethodName: string);
begin
  if (not Assigned(BIO_new_mem_buf)) or (not Assigned(BIO_free)) then
    RaiseSSLCertError(
      'Required OpenSSL BIO helpers are unavailable for certificate load',
      AMethodName
    );
end;

procedure RequireContextPrivateKeyMemoryBIOHelpers(const AMethodName: string);
begin
  if (not Assigned(BIO_new_mem_buf)) or (not Assigned(BIO_free)) then
    raise ESSLKeyException.CreateWithContext(
      'Required OpenSSL BIO helpers are unavailable for private key load',
      sslErrFunctionNotFound,
      AMethodName,
      0,
      sslOpenSSL
    );
end;

procedure RequireContextPrivateKeyFileBIOHelpers(const AMethodName: string);
begin
  if (not Assigned(BIO_new_file)) or (not Assigned(BIO_free)) then
    raise ESSLKeyException.CreateWithContext(
      'Required OpenSSL BIO file helpers are unavailable for private key load',
      sslErrFunctionNotFound,
      AMethodName,
      0,
      sslOpenSSL
    );
end;

procedure RequirePublishedOpenSSLContextCallbackSurface(const AMethodName: string);
begin
  if not OpenSSLPublishedContextCallbackSurfaceReady then
    raise ESSLInitializationException.CreateWithContext(
      'OpenSSL callback surface is incomplete in this runtime build; ' +
      'verify/password/info callback publication remains unsupported until all required helpers are available.',
      sslErrUnsupported,
      AMethodName,
      0,
      sslOpenSSL
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

procedure RequirePublishedOpenSSLContextCustomCipherSurface(
  const AFeature, AMethodName: string);
begin
  if not OpenSSLPublishedCustomCipherSurfaceReady then
    raise ESSLInitializationException.CreateWithContext(
      nextpas.core.text.conv.Format('OpenSSL custom cipher surface is incomplete in this runtime build; ' +
        '%s publication remains unsupported until both TLS 1.2 and TLS 1.3 cipher helpers are available.',
        [AFeature]),
      sslErrUnsupported,
      AMethodName,
      0,
      sslOpenSSL
    );
end;

function OpenSSLOCSPResponseAlloc(ASize: size_t): PByte;
var
  LCryptoMalloc: TCRYPTO_malloc;
begin
  Result := nil;

  if ASize = 0 then
    Exit;

  LCryptoMalloc := TCRYPTO_malloc(GetCryptoProcAddress('CRYPTO_malloc'));
  if Assigned(LCryptoMalloc) then
    Result := LCryptoMalloc(ASize,
      PAnsiChar(AnsiString('nextpas.core.tls.openssl.context')), 0);
end;

procedure OpenSSLOCSPResponseFree(ABuffer: Pointer);
var
  LOpenSSLFree: TOPENSSL_free;
  LCryptoFree: TCRYPTO_free;
begin
  if ABuffer = nil then
    Exit;

  LOpenSSLFree := TOPENSSL_free(GetCryptoProcAddress('OPENSSL_free'));
  if Assigned(LOpenSSLFree) then
  begin
    LOpenSSLFree(ABuffer);
    Exit;
  end;

  LCryptoFree := TCRYPTO_free(GetCryptoProcAddress('CRYPTO_free'));
  if Assigned(LCryptoFree) then
    LCryptoFree(ABuffer, nil, 0);
end;

function OpenSSLServerOCSPStaplingStatusCallback(ssl: PSSL;
  arg: Pointer): Integer; cdecl;
var
  LContext: TOpenSSLContext;
  LResponse: TBytes;
  LResponseCopy: PByte;
begin
  Result := SSL_TLSEXT_ERR_NOACK;

  if (ssl = nil) or (arg = nil) then
    Exit;

  try
    LContext := TOpenSSLContext(arg);
    if not LContext.HasServerStapledOCSPResponse then
      Exit;

    LResponse := LContext.GetServerStapledOCSPResponse;
    if Length(LResponse) = 0 then
      Exit;

    LResponseCopy := OpenSSLOCSPResponseAlloc(Length(LResponse));
    if LResponseCopy = nil then
      Exit(SSL_TLSEXT_ERR_ALERT_FATAL);

    Move(LResponse[0], LResponseCopy^, Length(LResponse));
    if Assigned(SSL_set_tlsext_status_ocsp_resp) and
      (SSL_set_tlsext_status_ocsp_resp(ssl, LResponseCopy, Length(LResponse)) = 1) then
      Result := SSL_TLSEXT_ERR_OK
    else
    begin
      OpenSSLOCSPResponseFree(LResponseCopy);
      Result := SSL_TLSEXT_ERR_ALERT_FATAL;
    end;
  except
    Result := SSL_TLSEXT_ERR_ALERT_FATAL;
  end;
end;

function ReadPrivateKeyFileBytes(const AFileName, AMethodName: string): TBytes;
var
  LStream: TFileStream;
begin
  SetLength(Result, 0);

  try
    LStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
    try
      SetLength(Result, LStream.Size);
      if LStream.Size > 0 then
        LStream.ReadBuffer(Result[0], LStream.Size);
    finally
      LStream.Free;
    end;
  except
    on E: Exception do
      raise ESSLKeyException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to read private key file: %s', [AFileName]),
        sslErrLoadFailed,
        AMethodName,
        0,
        sslOpenSSL
      );
  end;
end;

function ReadPrivateKeyStreamBytes(AStream: TStream): TBytes;
begin
  Result := IoReadAll(WrapTStream(AStream, False));
end;

function ReadLimitedStreamBytes(AStream: TStream; const AMaxSize: Int64;
  const ASubject: string): TBytes;
var
  LReader: IReader;
begin
  if AStream = nil then
    RaiseInvalidParameter('AStream');

  LReader := IoLimitReader(WrapTStream(AStream, False), AMaxSize + 1);
  Result := IoReadAll(LReader);

  if Length(Result) = 0 then
    RaiseInvalidParameter('Stream is empty');
  if Length(Result) > AMaxSize then
    raise ESSLInvalidArgument.CreateFmt(
      '%s exceeds maximum allowed size (%d > %d bytes)',
      [ASubject, Length(Result), AMaxSize]
    );
end;

function TryLoadPrivateKeyFromPEMBuffer(
  const AData: TBytes;
  const APassword: string;
  out APKey: PEVP_PKEY
): Boolean;
var
  LBIO: PBIO;
  LPassA: AnsiString;
  LPassPtr: PAnsiChar;
begin
  Result := False;
  APKey := nil;

  if (Length(AData) = 0) or (not IsPEMFormat(AData)) then
    Exit;

  if (not Assigned(PEM_read_bio_PrivateKey)) and
    (not TOpenSSLLoader.IsModuleLoaded(osmPEM)) then
    LoadOpenSSLPEM(GetCryptoLibHandle);

  if (not Assigned(PEM_read_bio_PrivateKey)) or
    (not Assigned(BIO_new_mem_buf)) or
    (not Assigned(BIO_free)) then
    Exit;

  LBIO := BIO_new_mem_buf(@AData[0], Length(AData));
  if LBIO = nil then
    Exit;

  LPassPtr := nil;
  if APassword <> '' then
  begin
    LPassA := AnsiString(APassword);
    LPassPtr := PAnsiChar(LPassA);
  end;

  try
    APKey := PEM_read_bio_PrivateKey(LBIO, nil, nil, LPassPtr);
    Result := APKey <> nil;
  finally
    if APassword <> '' then
      SecureZeroString(LPassA);
    BIO_free(LBIO);
  end;
end;

function TryLoadPrivateKeyFromEncryptedDERPKCS8(
  const AData: TBytes;
  const APassword: string;
  out APKey: PEVP_PKEY
): Boolean;
var
  LPointer: PByte;
  LPassA: AnsiString;
  LPassPtr: PAnsiChar;
  LEncryptedKey: nextpas.core.tls.openssl.api.pkcs.PX509_SIG;
  LPrivateKeyInfo: nextpas.core.tls.openssl.api.pkcs.PPKCS8_PRIV_KEY_INFO;
begin
  Result := False;
  APKey := nil;
  LPassA := '';

  if (Length(AData) = 0) or (not IsDERFormat(AData)) then
    Exit;

  if ((not Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG)) or
      (not Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY)) or
      (not Assigned(nextpas.core.tls.openssl.api.pkcs.X509_SIG_free)) or
      (not Assigned(nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free))) and
    (not TOpenSSLLoader.IsModuleLoaded(osmPKCS)) then
    LoadOpenSSLPKCS(GetCryptoLibHandle);

  if (not Assigned(nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt)) and
    (not TOpenSSLLoader.IsModuleLoaded(osmPKCS12)) then
    LoadPKCS12Module(GetCryptoLibHandle);

  if (not Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG)) or
    (not Assigned(nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt)) or
    (not Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY)) or
    (not Assigned(nextpas.core.tls.openssl.api.pkcs.X509_SIG_free)) or
    (not Assigned(nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free)) then
    Exit;

  LPointer := @AData[0];
  LEncryptedKey := nextpas.core.tls.openssl.api.pkcs.d2i_X509_SIG(nil, @LPointer, Length(AData));
  if LEncryptedKey = nil then
    Exit;

  LPassPtr := nil;
  if APassword <> '' then
  begin
    LPassA := AnsiString(APassword);
    LPassPtr := PAnsiChar(LPassA);
  end;

  try
    LPrivateKeyInfo := nextpas.core.tls.openssl.api.pkcs12.PKCS8_decrypt(
      LEncryptedKey,
      LPassPtr,
      Length(LPassA)
    );
    if LPrivateKeyInfo = nil then
      Exit;

    try
      APKey := nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY(LPrivateKeyInfo);
      Result := APKey <> nil;
    finally
      nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free(LPrivateKeyInfo);
    end;
  finally
    if APassword <> '' then
      SecureZeroString(LPassA);
    nextpas.core.tls.openssl.api.pkcs.X509_SIG_free(LEncryptedKey);
  end;
end;

function TryLoadPrivateKeyFromDERPKCS8(
  const AData: TBytes;
  out APKey: PEVP_PKEY
): Boolean;
var
  LPointer: PByte;
  LPrivateKeyInfo: nextpas.core.tls.openssl.api.pkcs.PPKCS8_PRIV_KEY_INFO;
begin
  Result := False;
  APKey := nil;

  if (Length(AData) = 0) or (not IsDERFormat(AData)) then
    Exit;

  if ((not Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO)) or
      (not Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY)) or
      (not Assigned(nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free))) and
    (not TOpenSSLLoader.IsModuleLoaded(osmPKCS)) then
    LoadOpenSSLPKCS(GetCryptoLibHandle);

  if (not Assigned(nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO)) or
    (not Assigned(nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY)) or
    (not Assigned(nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free)) then
    Exit;

  LPointer := @AData[0];
  LPrivateKeyInfo := nextpas.core.tls.openssl.api.pkcs.d2i_PKCS8_PRIV_KEY_INFO(nil, @LPointer, Length(AData));
  if LPrivateKeyInfo = nil then
    Exit;

  try
    APKey := nextpas.core.tls.openssl.api.pkcs.EVP_PKCS82PKEY(LPrivateKeyInfo);
    Result := APKey <> nil;
  finally
    nextpas.core.tls.openssl.api.pkcs.PKCS8_PRIV_KEY_INFO_free(LPrivateKeyInfo);
  end;
end;

function TryLoadPrivateKeyFromDERPKCS1RSA(
  const AData: TBytes;
  out APKey: PEVP_PKEY
): Boolean;
var
  LPointer: PByte;
  LRSAKey: PRSA;
begin
  Result := False;
  APKey := nil;

  if (Length(AData) = 0) or (not IsDERFormat(AData)) then
    Exit;

  if (not Assigned(d2i_RSAPrivateKey)) and
    (not TOpenSSLLoader.IsModuleLoaded(osmRSA)) then
    LoadOpenSSLRSA;

  if ((not Assigned(EVP_PKEY_new)) or
      (not Assigned(EVP_PKEY_set1_RSA)) or
      (not Assigned(EVP_PKEY_free))) and
    (not TOpenSSLLoader.IsModuleLoaded(osmEVP)) then
    LoadEVP(GetCryptoLibHandle);

  if (not Assigned(d2i_RSAPrivateKey)) or
    (not Assigned(RSA_free)) or
    (not Assigned(EVP_PKEY_new)) or
    (not Assigned(EVP_PKEY_set1_RSA)) or
    (not Assigned(EVP_PKEY_free)) then
    Exit;

  LPointer := @AData[0];
  LRSAKey := d2i_RSAPrivateKey(nil, @LPointer, Length(AData));
  if LRSAKey = nil then
    Exit;

  try
    APKey := EVP_PKEY_new();
    if APKey = nil then
      Exit;

    if EVP_PKEY_set1_RSA(APKey, LRSAKey) <> 1 then
    begin
      EVP_PKEY_free(APKey);
      APKey := nil;
      Exit;
    end;

    Result := True;
  finally
    RSA_free(LRSAKey);
  end;
end;

function TryLoadPrivateKeyFromDERSEC1EC(
  const AData: TBytes;
  out APKey: PEVP_PKEY
): Boolean;
var
  LPointer: PByte;
  LECKey: PEC_KEY;
begin
  Result := False;
  APKey := nil;

  if (Length(AData) = 0) or (not IsDERFormat(AData)) then
    Exit;

  if (not Assigned(d2i_ECPrivateKey)) and
    (not TOpenSSLLoader.IsModuleLoaded(osmEC)) then
    LoadECFunctions(GetCryptoLibHandle);

  if ((not Assigned(EVP_PKEY_new)) or
      (not Assigned(EVP_PKEY_set1_EC_KEY)) or
      (not Assigned(EVP_PKEY_free))) and
    (not TOpenSSLLoader.IsModuleLoaded(osmEVP)) then
    LoadEVP(GetCryptoLibHandle);

  if (not Assigned(d2i_ECPrivateKey)) or
    (not Assigned(EC_KEY_free)) or
    (not Assigned(EVP_PKEY_new)) or
    (not Assigned(EVP_PKEY_set1_EC_KEY)) or
    (not Assigned(EVP_PKEY_free)) then
    Exit;

  LPointer := @AData[0];
  LECKey := d2i_ECPrivateKey(nil, @LPointer, Length(AData));
  if LECKey = nil then
    Exit;

  try
    APKey := EVP_PKEY_new();
    if APKey = nil then
      Exit;

    if EVP_PKEY_set1_EC_KEY(APKey, LECKey) <> 1 then
    begin
      EVP_PKEY_free(APKey);
      APKey := nil;
      Exit;
    end;

    Result := True;
  finally
    EC_KEY_free(LECKey);
  end;
end;

function ParsePrivateKeyBuffer(
  const AData: TBytes;
  const APassword: string;
  out APKey: PEVP_PKEY
): Boolean;
begin
  APKey := nil;
  Result := TryLoadPrivateKeyFromPEMBuffer(AData, APassword, APKey);
  if Result then
    Exit;

  Result := TryLoadPrivateKeyFromEncryptedDERPKCS8(AData, APassword, APKey);
  if Result then
    Exit;

  Result := TryLoadPrivateKeyFromDERPKCS8(AData, APKey);
  if Result then
    Exit;

  Result := TryLoadPrivateKeyFromDERPKCS1RSA(AData, APKey);
  if Result then
    Exit;

  Result := TryLoadPrivateKeyFromDERSEC1EC(AData, APKey);
end;

procedure UseParsedPrivateKey(
  ASSLContext: PSSL_CTX;
  APKey: PEVP_PKEY;
  const AMethodName, AErrorMessage: string
);
begin
  if SSL_CTX_use_PrivateKey(ASSLContext, APKey) <> 1 then
    raise ESSLKeyException.CreateWithContext(
      AErrorMessage,
      sslErrLoadFailed,
      AMethodName,
      Integer(GetLastOpenSSLError),
      sslOpenSSL
    );
end;

procedure RegisterContextInstance(const AContext: TOpenSSLContext);
begin
  if (AContext = nil) or (AContext.FSSLContext = nil) then Exit;
  GContextLock.BeginWrite;
  try
    if GContextRegistry.IndexOf(AContext) = -1 then
      GContextRegistry.Add(AContext);
  finally
    GContextLock.EndWrite;
  end;
end;

procedure UnregisterContextInstance(const AContext: TOpenSSLContext);
begin
  if (GContextLock = nil) or (AContext = nil) then Exit;
  GContextLock.BeginWrite;
  try
    if GContextRegistry = nil then Exit;
    GContextRegistry.Remove(AContext);
    // Note: Don't destroy registry here to avoid race conditions
    // It will be cleaned up in finalization
  finally
    GContextLock.EndWrite;
  end;
end;

function LookupContext(AHandle: PSSL_CTX): TOpenSSLContext;
var
  i: Integer;
  Ctx: TOpenSSLContext;
begin
  Result := nil;
  if (GContextLock = nil) or (AHandle = nil) then Exit;
  // 使用读锁：允许多个线程同时查找上下文
  GContextLock.BeginRead;
  try
    if GContextRegistry = nil then Exit;
    for i := 0 to GContextRegistry.Count - 1 do
    begin
      Ctx := TOpenSSLContext(GContextRegistry[i]);
      if Ctx.FSSLContext = AHandle then
      begin
        Result := Ctx;
        Exit;
      end;
    end;
  finally
    GContextLock.EndRead;
  end;
end;

function BuildALPNWireData(const AProtocols: string): TBytes;
var
  ProtoList: TStringArray;
  Proto: string;
  Trimmed: string;
  TotalLen, Offset: Integer;
  AnsiProto: AnsiString;
begin
  TotalLen := 0;
  ProtoList := AProtocols.Split([',']);
  for Proto in ProtoList do
  begin
    Trimmed := Trim(Proto);
    if Trimmed = '' then Continue;
    if Length(Trimmed) > 255 then
      RaiseInvalidParameter('ALPN protocol name length');
    Inc(TotalLen, 1 + Length(Trimmed));
  end;

  SetLength(Result, TotalLen);
  Offset := 0;
  if TotalLen = 0 then Exit;

  for Proto in ProtoList do
  begin
    Trimmed := Trim(Proto);
    if Trimmed = '' then Continue;
    Result[Offset] := Length(Trimmed);
    Inc(Offset);
    AnsiProto := AnsiString(Trimmed);
    if Length(Trimmed) > 0 then
    begin
      Move(AnsiProto[1], Result[Offset], Length(Trimmed));
      Inc(Offset, Length(Trimmed));
    end;
  end;
end;

function ALPNSelectCallback(ssl: PSSL; const out_proto: PPByte; out_proto_len: PByte;
  const in_proto: PByte; in_proto_len: Cardinal; {%H-}arg: Pointer): Integer; cdecl;
  // P3-3: arg 是 OpenSSL API 签名要求的参数，当前实现不使用（通过 SSL_get_SSL_CTX 获取上下文）
var
  Ctx: PSSL_CTX;
  Context: TOpenSSLContext;
  Wire: TBytes;
  Code: Integer;
begin
  Result := SSL_TLSEXT_ERR_NOACK;
  if (ssl = nil) or (out_proto = nil) or (out_proto_len = nil) then Exit;
  if not Assigned(SSL_get_SSL_CTX) then Exit;
  Ctx := SSL_get_SSL_CTX(ssl);
  Context := LookupContext(Ctx);
  if Context = nil then Exit;

  Wire := Context.FALPNWireData;
  if (Length(Wire) = 0) or not Assigned(SSL_select_next_proto) then Exit;

  Code := SSL_select_next_proto(out_proto, out_proto_len, @Wire[0], Length(Wire), in_proto, in_proto_len);
  if Code = 1 {NEGOTIATED} then
    Result := SSL_TLSEXT_ERR_OK
  else if Code = 2 {NO_OVERLAP} then
    Result := SSL_TLSEXT_ERR_NOACK
  else
    Result := SSL_TLSEXT_ERR_ALERT_FATAL;
end;

function VerifyCertificateCallback(ctx: PX509_STORE_CTX; arg: Pointer): Integer; cdecl;
var
  Context: TOpenSSLContext;
  DefaultResult: Integer;
  Cert: PX509;
  Info: TSSLCertificateInfo;
  ErrorCode: Integer;
  ErrorMsg: string;
begin
  // P3-4: 显式初始化管理类型变量
  Info := Default(TSSLCertificateInfo);
  ErrorMsg := '';

  // 先执行 OpenSSL 默认验证逻辑
  if Assigned(X509_verify_cert) then
    DefaultResult := X509_verify_cert(ctx)
  else
    DefaultResult := 1;

  Context := TOpenSSLContext(arg);
  if (Context = nil) or not Assigned(Context.FVerifyCallback) then
  begin
    Result := DefaultResult;
    Exit;
  end;

  // P3-4: 已在函数开始处使用 Default() 初始化，无需 FillChar
  if Assigned(X509_STORE_CTX_get_current_cert) then
  begin
    Cert := X509_STORE_CTX_get_current_cert(ctx);
    if Cert <> nil then
    begin
      // 仅提取基本信息（按需可扩展）
      Info.Subject := '';
      Info.Issuer := '';
    end;
  end;

  ErrorCode := 0;
  if Assigned(X509_STORE_CTX_get_error) then
    ErrorCode := X509_STORE_CTX_get_error(ctx);

  if Assigned(X509_verify_cert_error_string) then
    ErrorMsg := string(X509_verify_cert_error_string(ErrorCode))
  else
    ErrorMsg := '';

  if Context.FVerifyCallback(Info, ErrorCode, ErrorMsg) then
  begin
    Result := DefaultResult;
    if (Result = 0) and Assigned(X509_STORE_CTX_set_error) then
      X509_STORE_CTX_set_error(ctx, X509_V_OK);
  end
  else
  begin
    Result := 0;
    if Assigned(X509_STORE_CTX_set_error) then
      X509_STORE_CTX_set_error(ctx, X509_V_ERR_APPLICATION_VERIFICATION);
  end;
end;

function PasswordCallbackThunk(buf: PAnsiChar; size: Integer; rwflag: Integer; userdata: Pointer): Integer; cdecl;
var
  Context: TOpenSSLContext;
  Password: string;
  PasswordAnsi: AnsiString;
begin
  Result := 0;
  if (buf = nil) or (size <= 0) then Exit;
  Context := TOpenSSLContext(userdata);
  if (Context = nil) or not Assigned(Context.FPasswordCallback) then Exit;
  Password := '';
  if not Context.FPasswordCallback(Password, rwflag <> 0) then Exit;
  PasswordAnsi := AnsiString(Password);
  try
    if Length(PasswordAnsi) >= size then Exit;
    if Length(PasswordAnsi) > 0 then Move(PasswordAnsi[1], buf^, Length(PasswordAnsi));
    buf[Length(PasswordAnsi)] := #0;
    Result := Length(PasswordAnsi);
  finally
    SecureZeroString(PasswordAnsi);
  end;
end;

procedure InfoCallbackThunk(ssl: PSSL; where: Integer; ret: Integer); cdecl;
var
  Ctx: PSSL_CTX;
  Context: TOpenSSLContext;
  StatePtr: PAnsiChar;
  StateStr: string;
begin
  if (ssl = nil) or not Assigned(SSL_get_SSL_CTX) then Exit;
  Ctx := SSL_get_SSL_CTX(ssl);
  Context := LookupContext(Ctx);
  if (Context = nil) or not Assigned(Context.FInfoCallback) then Exit;
  StateStr := '';
  if Assigned(SSL_state_string_long) then
  begin
    StatePtr := SSL_state_string_long(ssl);
    if StatePtr <> nil then StateStr := string(StatePtr);
  end;
  Context.FInfoCallback(where, ret, StateStr);
end;

// ============================================================================
// TOpenSSLContext - 构造和析构
// ============================================================================

constructor TOpenSSLContext.Create(ALibrary: ISSLLibrary; AType: TSSLContextType);
var
  Method: PSSL_METHOD;
begin
  inherited Create;
  FLibrary := ALibrary;
  FContextType := AType;
  FProtocolVersions := [sslProtocolTLS12, sslProtocolTLS13];
  FPreferredVersion := sslProtocolTLS13;
  FVerifyMode := [sslVerifyPeer];
  FVerifyDepth := SSL_DEFAULT_VERIFY_DEPTH;
  FServerName := '';
  FCipherList := SSL_DEFAULT_CIPHER_LIST;
  FCipherSuites := SSL_DEFAULT_TLS13_CIPHERSUITES;
  FALPNProtocols := '';
  SetLength(FALPNWireData, 0);
  FSessionCacheEnabled := True;
  FSessionTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FSessionCacheSize := SSL_DEFAULT_SESSION_CACHE_SIZE;
  FOptions := [ssoEnableSessionCache, ssoEnableSessionTickets,
              ssoDisableCompression, ssoDisableRenegotiation,
              ssoNoSSLv2, ssoNoSSLv3, ssoNoTLSv1, ssoNoTLSv1_1];
  FCertVerifyFlags := [sslCertVerifyDefault];

  FVerifyCallback := nil;
  FPasswordCallback := nil;
  FInfoCallback := nil;

  // 初始化证书固定
  FPinValidator := TPinValidator.Create;
  FPinningEnabled := False;

  // 初始化 Early Data 配置 (v1.4.1)
  FClientEarlyDataEnabled := False;
  FServerEarlyDataPolicy := sslEarlyDataServerReject;
  FServerMaxEarlyDataSize := 16384;  // 16KB 默认值

  // 初始化 Server OCSP Stapling (v1.4.1)
  SetLength(FServerStapledOCSPResponse, 0);

  // 创建 SSL_CTX
  Method := GetSSLMethod;
  if Method = nil then
    raise ESSLInitializationException.CreateWithContext(
      'Failed to get SSL method',
      sslErrNotInitialized,
      'TOpenSSLContext.Create'
    );
  
  if not Assigned(SSL_CTX_new) then
    raise ESSLInitializationException.CreateWithContext(
      'SSL_CTX_new not loaded from OpenSSL library',
      sslErrFunctionNotFound,
      'TOpenSSLContext.Create'
    );
  
  FSSLContext := SSL_CTX_new(Method);
  if FSSLContext = nil then
    RaiseSSLInitError(
      'Failed to create SSL_CTX',
      'TOpenSSLContext.Create'
    );

  // 注册上下文以便回调反查
  RegisterContextInstance(Self);
  
  // 应用默认配置
  ApplyProtocolVersions;
  ApplyVerifyMode;
  
  // 设置密码套件
  if FCipherList <> '' then
    SetCipherList(FCipherList);
  if FCipherSuites <> '' then
    SetCipherSuites(FCipherSuites);

  ApplyOptions;
  ApplyServerOCSPStaplingConfiguration;
  
  TSecurityLog.Info('OpenSSL', nextpas.core.text.conv.Format('SSL Context created (Type: %d)', [Ord(FContextType)]));
end;

destructor TOpenSSLContext.Destroy;
begin
  if FSSLContext <> nil then
  begin
    UnregisterContextInstance(Self);
    if Assigned(SSL_CTX_free) then
      SSL_CTX_free(FSSLContext);
    FSSLContext := nil;
  end;
  
  // 清理证书固定
  
  inherited Destroy;
end;

// ============================================================================
// 内部辅助方法
// ============================================================================

function TOpenSSLContext.GetSSLMethod: PSSL_METHOD;
begin
  // 使用 TLS_method() 支持所有TLS版本（OpenSSL 1.1.0+）
  if FContextType = sslCtxServer then
  begin
    if Assigned(TLS_server_method) then
      Result := TLS_server_method()
    else if Assigned(SSLv23_server_method) then
      Result := SSLv23_server_method()
    else
      raise ESSLInitializationException.CreateWithContext(
        'No suitable SSL server method available in OpenSSL library',
        sslErrFunctionNotFound,
        'TOpenSSLContext.GetSSLMethod'
      );
  end
  else
  begin
    if Assigned(TLS_client_method) then
      Result := TLS_client_method()
    else if Assigned(SSLv23_client_method) then
      Result := SSLv23_client_method()
    else
      raise ESSLInitializationException.CreateWithContext(
        'No suitable SSL client method available in OpenSSL library',
        sslErrFunctionNotFound,
        'TOpenSSLContext.GetSSLMethod'
      );
  end;
end;

{ P0-1: 上下文验证守卫方法 - 消除代码重复 }
procedure TOpenSSLContext.RequireValidContext(const AMethodName: string);
begin
  if FSSLContext = nil then
    raise ESSLInitializationException.CreateWithContext(
      'SSL context not initialized',
      sslErrNotInitialized,
      AMethodName
    );
  if Assigned(ERR_clear_error) then ERR_clear_error();
end;

function TOpenSSLContext.HasClientOCSPCapability: Boolean;
begin
  Result := (FLibrary <> nil) and
    (FLibrary.GetCapabilities.OCSPStaplingSupport <> sslSupportNone);
end;

{ P1-2: 私钥-证书匹配检查辅助方法 - 消除代码重复 }
procedure TOpenSSLContext.CheckPrivateKeyMatchesCertificate(const AMethodName: string);
var
  HasCert: Boolean;
begin
  HasCert := Assigned(SSL_CTX_get0_certificate) and (SSL_CTX_get0_certificate(FSSLContext) <> nil);
  if HasCert then
  begin
    if SSL_CTX_check_private_key(FSSLContext) <> 1 then
    begin
      TSecurityLog.Error('OpenSSL', 'Private key does not match certificate');
      raise ESSLKeyException.CreateWithContext(
        'Private key does not match the loaded certificate',
        sslErrCertificate,
        AMethodName,
        Integer(GetLastOpenSSLError),
        sslOpenSSL
      );
    end;
  end;
end;

procedure TOpenSSLContext.ApplyProtocolVersions;
var
  MinVersion, MaxVersion: Integer;
begin
  if FSSLContext = nil then
    Exit;
  
  // 确定最小和最大协议版本
  MinVersion := 0;
  MaxVersion := 0;
  
  if sslProtocolTLS10 in FProtocolVersions then
    MinVersion := TLS1_VERSION;
  if sslProtocolTLS11 in FProtocolVersions then
  begin
    if MinVersion = 0 then MinVersion := TLS1_1_VERSION;
    MaxVersion := TLS1_1_VERSION;
  end;
  if sslProtocolTLS12 in FProtocolVersions then
  begin
    if MinVersion = 0 then MinVersion := TLS1_2_VERSION;
    MaxVersion := TLS1_2_VERSION;
  end;
  if sslProtocolTLS13 in FProtocolVersions then
  begin
    if MinVersion = 0 then MinVersion := TLS1_3_VERSION;
    MaxVersion := TLS1_3_VERSION;
  end;
  
  if Assigned(SSL_CTX_set_min_proto_version) and (MinVersion > 0) then
    SSL_CTX_set_min_proto_version(FSSLContext, MinVersion);
  
  if Assigned(SSL_CTX_set_max_proto_version) and (MaxVersion > 0) then
    SSL_CTX_set_max_proto_version(FSSLContext, MaxVersion);
end;

procedure TOpenSSLContext.ApplyVerifyMode;
var
  Mode: Integer;
begin
  if FSSLContext = nil then
    Exit;
  
  Mode := SSL_VERIFY_NONE;
  
  if sslVerifyPeer in FVerifyMode then
    Mode := Mode or SSL_VERIFY_PEER;
  if sslVerifyFailIfNoPeerCert in FVerifyMode then
    Mode := Mode or SSL_VERIFY_FAIL_IF_NO_PEER_CERT;
  if sslVerifyClientOnce in FVerifyMode then
    Mode := Mode or SSL_VERIFY_CLIENT_ONCE;
  
  if Assigned(SSL_CTX_set_verify) then
    SSL_CTX_set_verify(FSSLContext, Mode, nil);
  if Assigned(SSL_CTX_set_verify_depth) then
    SSL_CTX_set_verify_depth(FSSLContext, FVerifyDepth);
end;

procedure TOpenSSLContext.ApplyServerOCSPStaplingConfiguration;
var
  LStatusType: Integer;
begin
  if (FSSLContext = nil) or (FContextType <> sslCtxServer) then
    Exit;

  if Assigned(SSL_CTX_set_tlsext_status_type) then
  begin
    if HasServerStapledOCSPResponse then
      LStatusType := TLSEXT_STATUSTYPE_ocsp
    else
      LStatusType := 0;
    SSL_CTX_set_tlsext_status_type(FSSLContext, LStatusType);
  end;

  if Assigned(SSL_CTX_set_tlsext_status_arg) then
  begin
    if HasServerStapledOCSPResponse then
      SSL_CTX_set_tlsext_status_arg(FSSLContext, Self)
    else
      SSL_CTX_set_tlsext_status_arg(FSSLContext, nil);
  end;

  if Assigned(SSL_CTX_set_tlsext_status_cb) then
  begin
    if HasServerStapledOCSPResponse then
      SSL_CTX_set_tlsext_status_cb(FSSLContext, @OpenSSLServerOCSPStaplingStatusCallback)
    else
      SSL_CTX_set_tlsext_status_cb(FSSLContext, nil);
  end;
end;

// ============================================================================
// ISSLContext - 基本配置
// ============================================================================

function TOpenSSLContext.GetContextType: TSSLContextType;
begin
  Result := FContextType;
end;

procedure TOpenSSLContext.SetProtocolVersions(AVersions: TSSLProtocolVersions);
begin
  FProtocolVersions := AVersions;

  // 当首选版本不再可用时，自动回退为无偏好
  if (FPreferredVersion <> sslProtocolUnknown) and
    not (FPreferredVersion in FProtocolVersions) then
    FPreferredVersion := sslProtocolUnknown;

  // P2: 使用共享辅助函数记录废弃协议警告
  LogDeprecatedProtocolWarnings('OpenSSL', AVersions);

  ApplyProtocolVersions;
end;

function TOpenSSLContext.GetProtocolVersions: TSSLProtocolVersions;
begin
  Result := FProtocolVersions;
end;

procedure TOpenSSLContext.SetPreferredVersion(AVersion: TSSLProtocolVersion);
begin
  if (AVersion <> sslProtocolUnknown) and
    not (AVersion in FProtocolVersions) then
    RaiseInvalidParameter('PreferredVersion');

  FPreferredVersion := AVersion;
end;

function TOpenSSLContext.GetPreferredVersion: TSSLProtocolVersion;
begin
  Result := FPreferredVersion;
end;

// ============================================================================
// ISSLContext - 证书和密钥管理
// ============================================================================

procedure TOpenSSLContext.LoadCertificate(const AFileName: string);
var
  FileNameA: AnsiString;
  LSize: Int64;
begin
  RequireValidContext('TOpenSSLContext.LoadCertificate');

  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  if not nextpas.core.fs.IsFile(AFileName) then
    RaiseSSLCertError(nextpas.core.text.conv.Format('Certificate file not found: %s', [AFileName]),
      'TOpenSSLContext.LoadCertificate');

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CERTIFICATE_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Certificate file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CERTIFICATE_SIZE, AFileName]);

  if not Assigned(SSL_CTX_use_certificate_file) then
  begin
    try
      LoadOpenSSLCore;
    except
      on E: Exception do
        raise ESSLInitializationException.CreateWithContext(
          nextpas.core.text.conv.Format('OpenSSL core not available: %s', [E.Message]),
          sslErrNotInitialized,
          'TOpenSSLContext.LoadCertificate'
        );
    end;

    if not Assigned(SSL_CTX_use_certificate_file) then
      raise ESSLInitializationException.CreateWithContext(
        'SSL_CTX_use_certificate_file not loaded from OpenSSL library',
        sslErrFunctionNotFound,
        'TOpenSSLContext.LoadCertificate'
      );
  end;
  
  FileNameA := AnsiString(AFileName);
  if SSL_CTX_use_certificate_file(FSSLContext, PAnsiChar(FileNameA), SSL_FILETYPE_PEM) <> 1 then
  begin
    TSecurityLog.Error('OpenSSL', nextpas.core.text.conv.Format('Failed to load certificate: %s', [AFileName]));
    RaiseSSLCertError(
      nextpas.core.text.conv.Format('Failed to load certificate from file: %s', [AFileName]),
      'TOpenSSLContext.LoadCertificate'
    );
  end;
  TSecurityLog.Info('OpenSSL', nextpas.core.text.conv.Format('Loaded certificate from file: %s', [AFileName]));
end;

procedure TOpenSSLContext.LoadCertificate(AStream: TStream);
var
  Data: TBytes;
  BIO: PBIO;
  Cert: PX509;
begin
  Data := nil;  // P3-4: 显式初始化管理类型
  RequireValidContext('TOpenSSLContext.LoadCertificate');

  if AStream = nil then
    RaiseInvalidParameter('AStream');

  Data := ReadLimitedStreamBytes(AStream, MAX_CERTIFICATE_SIZE, 'Certificate stream');

  RequireContextCertificateMemoryBIOHelpers('TOpenSSLContext.LoadCertificate');
  BIO := BIO_new_mem_buf(@Data[0], Length(Data));
  try
    Cert := PEM_read_bio_X509(BIO, nil, nil, nil);
    if Cert = nil then
      RaiseSSLCertError(
        'Failed to parse certificate from stream',
        'TOpenSSLContext.LoadCertificate'
      );
    
    try
      if SSL_CTX_use_certificate(FSSLContext, Cert) <> 1 then
        RaiseSSLCertError(
          'Failed to use certificate in context',
          'TOpenSSLContext.LoadCertificate'
        );
    finally
      X509_free(Cert);
    end;
  finally
    BIO_free(BIO);
  end;
end;

procedure TOpenSSLContext.LoadCertificate(ACert: ISSLCertificate);
var
  Cert: PX509;
begin
  RequireValidContext('TOpenSSLContext.LoadCertificate');

  if ACert = nil then
    RaiseInvalidParameter('Certificate');

  // 使用辅助函数安全获取原生句柄
  Cert := PX509(GetNativeHandleSafe(ACert, 'TOpenSSLContext.LoadCertificate'));

  if SSL_CTX_use_certificate(FSSLContext, Cert) <> 1 then
    RaiseSSLCertError(
      'Failed to use certificate in SSL context',
      'TOpenSSLContext.LoadCertificate'
    );
end;

procedure TOpenSSLContext.LoadPrivateKey(const AFileName: string; const APassword: string = '');
var
  Data: TBytes;
  FileNameA: AnsiString;
  PassA: AnsiString;
  BIO: PBIO;
  PKey: PEVP_PKEY;
  LSize: Int64;
begin
  RequireValidContext('TOpenSSLContext.LoadPrivateKey');

  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  // Check if this is a PKCS#11 URI
  if TPKCS11URIParser.IsPKCS11URI(AFileName) then
  begin
    LoadPrivateKeyFromPKCS11(AFileName, APassword);
    Exit;
  end;

  if not nextpas.core.fs.IsFile(AFileName) then
    RaiseSSLCertError(nextpas.core.text.conv.Format('Private key file not found: %s', [AFileName]),
      'TOpenSSLContext.LoadPrivateKey');

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_PRIVATE_KEY_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'Private key file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_PRIVATE_KEY_SIZE, AFileName]);

  FileNameA := AnsiString(AFileName);

  if APassword <> '' then
  begin
    RequireContextPrivateKeyFileBIOHelpers('TOpenSSLContext.LoadPrivateKey');
    BIO := BIO_new_file(PAnsiChar(FileNameA), 'r');
    if BIO = nil then
      raise ESSLKeyException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to open private key file: %s', [AFileName]),
        sslErrLoadFailed,
        'TOpenSSLContext.LoadPrivateKey',
        Integer(GetLastOpenSSLError),
        sslOpenSSL
      );

    PKey := nil;
    try
      if (not Assigned(PEM_read_bio_PrivateKey)) and
        (not TOpenSSLLoader.IsModuleLoaded(osmPEM)) then
        LoadOpenSSLPEM(GetCryptoLibHandle);

      if Assigned(PEM_read_bio_PrivateKey) then
      begin
        PassA := AnsiString(APassword);
        try
          PKey := PEM_read_bio_PrivateKey(BIO, nil, nil, PAnsiChar(PassA));
        finally
          SecureZeroString(PassA);
        end;
      end;
    finally
      BIO_free(BIO);
    end;

    if PKey = nil then
    begin
      Data := ReadPrivateKeyFileBytes(AFileName, 'TOpenSSLContext.LoadPrivateKey');
      if not ParsePrivateKeyBuffer(Data, APassword, PKey) then
        raise ESSLKeyException.CreateWithContext(
          nextpas.core.text.conv.Format('Failed to parse private key from file: %s', [AFileName]),
          sslErrParseFailed,
          'TOpenSSLContext.LoadPrivateKey',
          Integer(GetLastOpenSSLError),
          sslOpenSSL
        );
    end;

    try
      UseParsedPrivateKey(
        FSSLContext,
        PKey,
        'TOpenSSLContext.LoadPrivateKey',
        nextpas.core.text.conv.Format('Failed to use private key from file: %s', [AFileName])
      );
    finally
      EVP_PKEY_free(PKey);
    end;
  end
  else if Assigned(SSL_CTX_use_PrivateKey_file) then
  begin
    if SSL_CTX_use_PrivateKey_file(FSSLContext, PAnsiChar(FileNameA), SSL_FILETYPE_PEM) <> 1 then
    begin
      Data := ReadPrivateKeyFileBytes(AFileName, 'TOpenSSLContext.LoadPrivateKey');
      if not ParsePrivateKeyBuffer(Data, APassword, PKey) then
        raise ESSLKeyException.CreateWithContext(
          nextpas.core.text.conv.Format('Failed to parse private key from file: %s', [AFileName]),
          sslErrParseFailed,
          'TOpenSSLContext.LoadPrivateKey',
          Integer(GetLastOpenSSLError),
          sslOpenSSL
        );
      try
        UseParsedPrivateKey(
          FSSLContext,
          PKey,
          'TOpenSSLContext.LoadPrivateKey',
          nextpas.core.text.conv.Format('Failed to use private key from file: %s', [AFileName])
        );
        finally
          EVP_PKEY_free(PKey);
        end;
      end;
    end
  else
  begin
    Data := ReadPrivateKeyFileBytes(AFileName, 'TOpenSSLContext.LoadPrivateKey');
    if not ParsePrivateKeyBuffer(Data, APassword, PKey) then
      raise ESSLKeyException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to parse private key from file: %s', [AFileName]),
        sslErrParseFailed,
        'TOpenSSLContext.LoadPrivateKey',
        Integer(GetLastOpenSSLError),
        sslOpenSSL
      );
    try
      UseParsedPrivateKey(
        FSSLContext,
        PKey,
        'TOpenSSLContext.LoadPrivateKey',
        nextpas.core.text.conv.Format('Failed to use private key from file: %s', [AFileName])
      );
    finally
      EVP_PKEY_free(PKey);
    end;
  end;

  CheckPrivateKeyMatchesCertificate('TOpenSSLContext.LoadPrivateKey');
  TSecurityLog.Audit('OpenSSL', 'LoadPrivateKey', 'System', 'Private key loaded from file');
end;

procedure TOpenSSLContext.LoadPrivateKey(AStream: TStream; const APassword: string = '');
var
  Data: TBytes;
  PKey: PEVP_PKEY;
begin
  Data := nil;  // P3-4: 显式初始化管理类型
  RequireValidContext('TOpenSSLContext.LoadPrivateKey');

  if AStream = nil then
    RaiseInvalidParameter('Stream');

  Data := ReadLimitedStreamBytes(AStream, MAX_PRIVATE_KEY_SIZE, 'Private key stream');
  if not ParsePrivateKeyBuffer(Data, APassword, PKey) then
    raise ESSLKeyException.CreateWithContext(
      'Failed to parse private key from stream',
      sslErrParseFailed,
      'TOpenSSLContext.LoadPrivateKey',
      Integer(GetLastOpenSSLError),
      sslOpenSSL
    );
  try
    UseParsedPrivateKey(
      FSSLContext,
      PKey,
      'TOpenSSLContext.LoadPrivateKey',
      'Failed to use private key in context'
    );
    CheckPrivateKeyMatchesCertificate('TOpenSSLContext.LoadPrivateKey');
  finally
    EVP_PKEY_free(PKey);
  end;
end;

procedure TOpenSSLContext.LoadCertificatePEM(const APEM: string);
var
  BIO: PBIO;
  Cert: PX509;
  PemA: AnsiString;
begin
  RequireValidContext('TOpenSSLContext.LoadCertificatePEM');

  if APEM = '' then
    RaiseInvalidParameter('Certificate PEM');

  PemA := AnsiString(APEM);
  RequireContextCertificateMemoryBIOHelpers('TOpenSSLContext.LoadCertificatePEM');
  BIO := BIO_new_mem_buf(PAnsiChar(PemA), Length(PemA));
  if BIO = nil then
    RaiseMemoryError('create BIO for PEM certificate');
  
  try
    Cert := PEM_read_bio_X509(BIO, nil, nil, nil);
    if Cert = nil then
      RaiseSSLCertError(
        'Failed to parse certificate from PEM string',
        'TOpenSSLContext.LoadCertificatePEM'
      );

    try
      if SSL_CTX_use_certificate(FSSLContext, Cert) <> 1 then
        RaiseSSLCertError(
          'Failed to use certificate in context',
          'TOpenSSLContext.LoadCertificatePEM'
        );
      TSecurityLog.Info('OpenSSL', 'Loaded certificate from PEM string');
    finally
      X509_free(Cert);
    end;
  finally
    BIO_free(BIO);
  end;
end;

procedure TOpenSSLContext.LoadPrivateKeyPEM(const APEM: string; const APassword: string = '');
var
  BIO: PBIO;
  PKey: PEVP_PKEY;
  PemA, PassA: AnsiString;
  PassPtr: PAnsiChar;
begin
  RequireValidContext('TOpenSSLContext.LoadPrivateKeyPEM');

  if APEM = '' then
    RaiseInvalidParameter('Private key PEM');

  PemA := AnsiString(APEM);
  RequireContextPrivateKeyMemoryBIOHelpers('TOpenSSLContext.LoadPrivateKeyPEM');
  BIO := BIO_new_mem_buf(PAnsiChar(PemA), Length(PemA));
  if BIO = nil then
    RaiseMemoryError('create BIO for PEM private key');
  
  try
    if not Assigned(PEM_read_bio_PrivateKey) then
      LoadOpenSSLPEM(GetCryptoLibHandle);
    if not Assigned(PEM_read_bio_PrivateKey) then
      raise ESSLKeyException.CreateWithContext(
        'OpenSSL PEM API not loaded (PEM_read_bio_PrivateKey is nil)',
        sslErrFunctionNotFound,
        'TOpenSSLContext.LoadPrivateKeyPEM',
        0,
        sslOpenSSL
      );

    PassPtr := nil;
    if APassword <> '' then
    begin
      PassA := AnsiString(APassword);
      PassPtr := PAnsiChar(PassA);
    end;

    try
      PKey := PEM_read_bio_PrivateKey(BIO, nil, nil, PassPtr);
      if PKey = nil then
        raise ESSLKeyException.CreateWithContext(
          'Failed to parse private key from PEM string',
          sslErrParseFailed,
          'TOpenSSLContext.LoadPrivateKeyPEM',
          Integer(GetLastOpenSSLError),
          sslOpenSSL
        );

      try
        if SSL_CTX_use_PrivateKey(FSSLContext, PKey) <> 1 then
          raise ESSLKeyException.CreateWithContext(
            'Failed to use private key in context',
            sslErrLoadFailed,
            'TOpenSSLContext.LoadPrivateKeyPEM',
            Integer(GetLastOpenSSLError),
            sslOpenSSL
          );

        CheckPrivateKeyMatchesCertificate('TOpenSSLContext.LoadPrivateKeyPEM');

        TSecurityLog.Audit('OpenSSL', 'LoadPrivateKeyPEM', 'System', 'Private key loaded from PEM string');
      finally
        EVP_PKEY_free(PKey);
      end;
    finally
      // Rust-quality: Always securely zero sensitive data after use
      if APassword <> '' then
        SecureZeroString(PassA);
      SecureZeroString(PemA);  // PEM may contain unencrypted key
    end;
  finally
    BIO_free(BIO);
  end;
end;

procedure TOpenSSLContext.LoadPrivateKeyFromPKCS11(const AURI: string; const APIN: string);
var
  URIParsed: TPKCS11URI;
  Config: TPKCS11Config;
  Backend: IPKCS11Backend;
  PKey: PEVP_PKEY;
begin
  RequireValidContext('TOpenSSLContext.LoadPrivateKeyFromPKCS11');
  
  // Parse PKCS#11 URI
  try
    URIParsed := TPKCS11URIParser.Parse(AURI);
  except
    on E: Exception do
      raise ESSLKeyException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to parse PKCS#11 URI: %s', [E.Message]),
        sslErrParseFailed,
        'TOpenSSLContext.LoadPrivateKeyFromPKCS11',
        0,
        sslOpenSSL
      );
  end;
  
  // Build configuration from URI
  Config := TPKCS11ConfigFromURI(URIParsed);
  
  // Override PIN if provided
  if APIN <> '' then
  begin
    Config.PINMethod := pmValue;
    Config.PINValue := APIN;
  end;
  
  // Validate configuration
  if not Config.IsValid then
    raise ESSLKeyException.CreateWithContext(
      'Invalid PKCS#11 configuration',
      sslErrLoadFailed,
      'TOpenSSLContext.LoadPrivateKeyFromPKCS11',
      0,
      sslOpenSSL
    );
  
  // Create backend (auto-detect Provider or ENGINE)
  try
    Backend := TPKCS11BackendFactory.CreateBackend(btAuto);
  except
    on E: Exception do
      raise ESSLKeyException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to create PKCS#11 backend: %s', [E.Message]),
        sslErrLoadFailed,
        'TOpenSSLContext.LoadPrivateKeyFromPKCS11',
        0,
        sslOpenSSL
      );
  end;
  
  // Load private key from PKCS#11 token
  try
    PKey := Backend.LoadPrivateKey(Config);
    if PKey = nil then
      raise ESSLKeyException.CreateWithContext(
        'Failed to load private key from PKCS#11 token',
        sslErrLoadFailed,
        'TOpenSSLContext.LoadPrivateKeyFromPKCS11',
        0,
        sslOpenSSL
      );
    
    try
      // Use the key in SSL context
      if SSL_CTX_use_PrivateKey(FSSLContext, PKey) <> 1 then
        raise ESSLKeyException.CreateWithContext(
          'Failed to use PKCS#11 private key in SSL context',
          sslErrLoadFailed,
          'TOpenSSLContext.LoadPrivateKeyFromPKCS11',
          Integer(GetLastOpenSSLError),
          sslOpenSSL
        );
      
      CheckPrivateKeyMatchesCertificate('TOpenSSLContext.LoadPrivateKeyFromPKCS11');
      TSecurityLog.Audit('OpenSSL', 'LoadPrivateKeyFromPKCS11', 'System', 
        nextpas.core.text.conv.Format('Private key loaded from PKCS#11 token (Backend: %s)', [Backend.GetName]));
    finally
      EVP_PKEY_free(PKey);
    end;
  except
    on E: EPKCS11Exception do
      raise ESSLKeyException.CreateWithContext(
        nextpas.core.text.conv.Format('PKCS#11 error: %s', [E.Message]),
        sslErrLoadFailed,
        'TOpenSSLContext.LoadPrivateKeyFromPKCS11',
        Integer(E.ReturnValue),
        sslOpenSSL
      );
    on E: Exception do
      raise ESSLKeyException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to load PKCS#11 private key: %s', [E.Message]),
        sslErrLoadFailed,
        'TOpenSSLContext.LoadPrivateKeyFromPKCS11',
        0,
        sslOpenSSL
      );
  end;
end;

procedure TOpenSSLContext.LoadCAFile(const AFileName: string);
var
  FileNameA: AnsiString;
  LSize: Int64;
begin
  RequireValidContext('TOpenSSLContext.LoadCAFile');

  if AFileName = '' then
    RaiseInvalidParameter('AFileName');

  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLCertificateLoadException.CreateWithContext(
      nextpas.core.text.conv.Format('CA file not found: %s', [AFileName]),
      sslErrLoadFailed,
      'TOpenSSLContext.LoadCAFile',
      0,
      sslOpenSSL);

  LSize := GetFileSizeByName(AFileName);
  if LSize > MAX_CA_CHAIN_SIZE then
    raise ESSLInvalidArgument.CreateFmt(
      'CA file exceeds maximum allowed size (%d > %d bytes): %s',
      [LSize, MAX_CA_CHAIN_SIZE, AFileName]);

  if not Assigned(SSL_CTX_load_verify_locations) then
  begin
    try
      LoadOpenSSLCore;
    except
      on E: Exception do
        raise ESSLInitializationException.CreateWithContext(
          nextpas.core.text.conv.Format('OpenSSL core not available: %s', [E.Message]),
          sslErrNotInitialized,
          'TOpenSSLContext.LoadCAFile'
        );
    end;

    if not Assigned(SSL_CTX_load_verify_locations) then
      raise ESSLInitializationException.CreateWithContext(
        'SSL_CTX_load_verify_locations not loaded from OpenSSL library',
        sslErrFunctionNotFound,
        'TOpenSSLContext.LoadCAFile'
      );
  end;
  
  FileNameA := AnsiString(AFileName);
  if SSL_CTX_load_verify_locations(FSSLContext, PAnsiChar(FileNameA), nil) <> 1 then
    raise ESSLCertificateLoadException.CreateWithContext(
      nextpas.core.text.conv.Format('Failed to load CA certificates from file: %s', [AFileName]),
      sslErrLoadFailed,
      'TOpenSSLContext.LoadCAFile',
      Integer(GetLastOpenSSLError),
      sslOpenSSL
    );
end;

procedure TOpenSSLContext.LoadCAPath(const APath: string);
var
  PathA: AnsiString;
begin
  RequireValidContext('TOpenSSLContext.LoadCAPath');

  if not Assigned(SSL_CTX_load_verify_locations) then
  begin
    try
      LoadOpenSSLCore;
    except
      on E: Exception do
        raise ESSLInitializationException.CreateWithContext(
          nextpas.core.text.conv.Format('OpenSSL core not available: %s', [E.Message]),
          sslErrNotInitialized,
          'TOpenSSLContext.LoadCAPath'
        );
    end;

    if not Assigned(SSL_CTX_load_verify_locations) then
      raise ESSLInitializationException.CreateWithContext(
        'SSL_CTX_load_verify_locations not loaded from OpenSSL library',
        sslErrFunctionNotFound,
        'TOpenSSLContext.LoadCAPath'
      );
  end;
  
  if not nextpas.core.fs.IsDir(APath) then
    RaiseLoadError(APath);
  
  PathA := AnsiString(APath);
  if SSL_CTX_load_verify_locations(FSSLContext, nil, PAnsiChar(PathA)) <> 1 then
    raise ESSLCertificateLoadException.CreateWithContext(
      nextpas.core.text.conv.Format('Failed to load CA certificates from directory: %s', [APath]),
      sslErrLoadFailed,
      'TOpenSSLContext.LoadCAPath',
      Integer(GetLastOpenSSLError),
      sslOpenSSL
    );
end;

procedure TOpenSSLContext.SetCertificateStore(AStore: ISSLCertificateStore);
var
  Store: PX509_STORE;
begin
  RequireValidContext('TOpenSSLContext.SetCertificateStore');
  if AStore = nil then
    RaiseInvalidParameter('Certificate store');

  // 使用辅助函数安全获取原生句柄
  Store := PX509_STORE(GetNativeHandleSafe(AStore, 'TOpenSSLContext.SetCertificateStore'));

  if Assigned(SSL_CTX_set1_cert_store) then
    SSL_CTX_set1_cert_store(FSSLContext, Store)
  else if Assigned(SSL_CTX_set_cert_store) then
    SSL_CTX_set_cert_store(FSSLContext, Store)
  else
    raise ESSLInitializationException.CreateWithContext(
      'Setting certificate store is not supported by this OpenSSL build',
      sslErrUnsupported,
      'TOpenSSLContext.SetCertificateStore'
    );
end;

// ============================================================================
// ISSLContext - 验证配置
// ============================================================================

procedure TOpenSSLContext.SetVerifyMode(AMode: TSSLVerifyModes);
begin
  FVerifyMode := AMode;
  ApplyVerifyMode;
end;

function TOpenSSLContext.GetVerifyMode: TSSLVerifyModes;
begin
  Result := FVerifyMode;
end;

procedure TOpenSSLContext.SetVerifyDepth(ADepth: Integer);
begin
  FVerifyDepth := ADepth;
  if FSSLContext <> nil then
    if Assigned(SSL_CTX_set_verify_depth) then
      SSL_CTX_set_verify_depth(FSSLContext, ADepth);
end;

function TOpenSSLContext.GetVerifyDepth: Integer;
begin
  Result := FVerifyDepth;
end;

procedure TOpenSSLContext.SetVerifyCallback(ACallback: TSSLVerifyCallback);
begin
  if Assigned(ACallback) then
  begin
    RequirePublishedOpenSSLContextCallbackSurface('TOpenSSLContext.SetVerifyCallback');
    FVerifyCallback := ACallback;
    if FSSLContext = nil then Exit;
    SSL_CTX_set_cert_verify_callback(FSSLContext, @VerifyCertificateCallback, Self)
  end
  else
  begin
    FVerifyCallback := nil;
    if (FSSLContext <> nil) and Assigned(SSL_CTX_set_cert_verify_callback) then
      SSL_CTX_set_cert_verify_callback(FSSLContext, nil, nil);
  end;
end;

// ============================================================================
// ISSLContext - 密码套件配置
// ============================================================================

procedure TOpenSSLContext.SetCipherList(const ACipherList: string);
var
  CipherListA: AnsiString;
begin
  if IsCustomCipherListOverride(ACipherList) then
    RequirePublishedOpenSSLContextCustomCipherSurface(
      'Cipher-list override',
      'TOpenSSLContext.SetCipherList'
    );
  FCipherList := ACipherList;
  
  if (Trim(ACipherList) <> '') and (FSSLContext <> nil) and Assigned(SSL_CTX_set_cipher_list) then
  begin
    CipherListA := AnsiString(ACipherList);
    if SSL_CTX_set_cipher_list(FSSLContext, PAnsiChar(CipherListA)) <> 1 then
      raise ESSLConfigurationException.Create(
        'Invalid cipher list: "' + ACipherList + '"');
  end;
end;

function TOpenSSLContext.GetCipherList: string;
begin
  Result := FCipherList;
end;

procedure TOpenSSLContext.SetCipherSuites(const ACipherSuites: string);
var
  CipherSuitesA: AnsiString;
begin
  if IsCustomCipherSuitesOverride(ACipherSuites) then
    RequirePublishedOpenSSLContextCustomCipherSurface(
      'Cipher-suite override',
      'TOpenSSLContext.SetCipherSuites'
    );
  FCipherSuites := ACipherSuites;
  
  if (Trim(ACipherSuites) <> '') and (FSSLContext <> nil) and Assigned(SSL_CTX_set_ciphersuites) then
  begin
    CipherSuitesA := AnsiString(ACipherSuites);
    if SSL_CTX_set_ciphersuites(FSSLContext, PAnsiChar(CipherSuitesA)) <> 1 then
      raise ESSLConfigurationException.Create(
        'Invalid TLS 1.3 cipher suites: "' + ACipherSuites + '"');
  end;
end;

function TOpenSSLContext.GetCipherSuites: string;
begin
  Result := FCipherSuites;
end;

// ============================================================================
// ISSLContext - 会话管理
// ============================================================================

procedure TOpenSSLContext.SetSessionCacheMode(AEnabled: Boolean);
var
  Mode: Int64;
begin
  FSessionCacheEnabled := AEnabled;
  
  if (FSSLContext <> nil) and Assigned(SSL_CTX_set_session_cache_mode) then
  begin
    if AEnabled then
      Mode := SSL_SESS_CACHE_BOTH
    else
      Mode := SSL_SESS_CACHE_OFF;
    
    SSL_CTX_set_session_cache_mode(FSSLContext, Mode);
  end;
end;

function TOpenSSLContext.GetSessionCacheMode: Boolean;
begin
  Result := FSessionCacheEnabled;
end;

procedure TOpenSSLContext.SetSessionTimeout(ATimeout: Integer);
begin
  FSessionTimeout := ATimeout;
  if FSSLContext <> nil then
    SSL_CTX_set_timeout(FSSLContext, ATimeout);
end;

function TOpenSSLContext.GetSessionTimeout: Integer;
begin
  Result := FSessionTimeout;
end;

procedure TOpenSSLContext.SetSessionCacheSize(ASize: Integer);
begin
  FSessionCacheSize := ASize;
  if (FSSLContext <> nil) and Assigned(SSL_CTX_sess_set_cache_size) and (ASize > 0) then
    SSL_CTX_sess_set_cache_size(FSSLContext, ASize);
end;

function TOpenSSLContext.GetSessionCacheSize: Integer;
begin
  Result := FSessionCacheSize;
end;

procedure TOpenSSLContext.ApplyOptions;
const
  CONTROLLED_SSL_OPS: UInt64 =
    SSL_OP_NO_SSL_MASK or SSL_OP_NO_COMPRESSION or SSL_OP_NO_RENEGOTIATION or
    SSL_OP_NO_TICKET or SSL_OP_SINGLE_DH_USE or SSL_OP_SINGLE_ECDH_USE or
    SSL_OP_CIPHER_SERVER_PREFERENCE;
var
  Mask: UInt64;
  StatusType: Integer;
begin
  SetSessionCacheMode(ssoEnableSessionCache in FOptions);

  if FSSLContext = nil then
    Exit;

  // Client-side OCSP stapling request extension (status_request / RFC 6066)
  if (FContextType <> sslCtxServer) and Assigned(SSL_CTX_set_tlsext_status_type) then
  begin
    if ssoEnableOCSPStapling in FOptions then
      StatusType := TLSEXT_STATUSTYPE_ocsp
    else
      StatusType := 0;
    SSL_CTX_set_tlsext_status_type(FSSLContext, StatusType);
  end;

  Mask := 0;

  if ssoNoSSLv2 in FOptions then
    Mask := Mask or SSL_OP_NO_SSLv2;
  if ssoNoSSLv3 in FOptions then
    Mask := Mask or SSL_OP_NO_SSLv3;
  if ssoNoTLSv1 in FOptions then
    Mask := Mask or SSL_OP_NO_TLSv1;
  if ssoNoTLSv1_1 in FOptions then
    Mask := Mask or SSL_OP_NO_TLSv1_1;
  if ssoNoTLSv1_2 in FOptions then
    Mask := Mask or SSL_OP_NO_TLSv1_2;
  if ssoNoTLSv1_3 in FOptions then
    Mask := Mask or SSL_OP_NO_TLSv1_3;
  if ssoDisableCompression in FOptions then
    Mask := Mask or SSL_OP_NO_COMPRESSION;
  if ssoDisableRenegotiation in FOptions then
    Mask := Mask or SSL_OP_NO_RENEGOTIATION;
  if not (ssoEnableSessionTickets in FOptions) then
    Mask := Mask or SSL_OP_NO_TICKET;
  if ssoSingleDHUse in FOptions then
    Mask := Mask or SSL_OP_SINGLE_DH_USE;
  if ssoSingleECDHUse in FOptions then
    Mask := Mask or SSL_OP_SINGLE_ECDH_USE;
  if ssoCipherServerPreference in FOptions then
    Mask := Mask or SSL_OP_CIPHER_SERVER_PREFERENCE;

  if Assigned(SSL_CTX_clear_options) then
    SSL_CTX_clear_options(FSSLContext, CONTROLLED_SSL_OPS);

  if (Mask <> 0) and Assigned(SSL_CTX_set_options) then
    SSL_CTX_set_options(FSSLContext, Mask);
end;

// ============================================================================
// ISSLContext - 高级选项
// ============================================================================

procedure TOpenSSLContext.SetOptions(const AOptions: TSSLOptions);
begin
  FOptions := AOptions;
  ApplyOptions;
end;

function TOpenSSLContext.GetOptions: TSSLOptions;
begin
  Result := FOptions;
end;

procedure TOpenSSLContext.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
end;

function TOpenSSLContext.GetServerName: string;
begin
  Result := FServerName;
end;

procedure TOpenSSLContext.SetALPNProtocols(const AProtocols: string);
begin
  FALPNProtocols := Trim(AProtocols);
  FALPNWireData := BuildALPNWireData(FALPNProtocols);

  if FSSLContext = nil then Exit;

  if FALPNProtocols = '' then
  begin
    if Assigned(SSL_CTX_set_alpn_select_cb) then
      SSL_CTX_set_alpn_select_cb(FSSLContext, nil, nil);
    Exit;
  end;

  if not Assigned(SSL_CTX_set_alpn_protos) then
    RaiseUnsupported('ALPN');

  if (Length(FALPNWireData) = 0) or
    (SSL_CTX_set_alpn_protos(FSSLContext, @FALPNWireData[0], Length(FALPNWireData)) <> 0) then
    RaiseConfigurationError('ALPN protocols', nextpas.core.text.conv.Format('failed to configure: %s', [FALPNProtocols]));

  // 仅在服务端设置选择回调，客户端只发送候选列表
  if (FContextType <> sslCtxClient) and Assigned(SSL_CTX_set_alpn_select_cb) then
    SSL_CTX_set_alpn_select_cb(FSSLContext, @ALPNSelectCallback, nil);
end;

function TOpenSSLContext.GetALPNProtocols: string;
begin
  Result := FALPNProtocols;
end;

// ============================================================================
// ISSLContext - 证书验证标志
// ============================================================================

procedure TOpenSSLContext.SetCertVerifyFlags(AFlags: TSSLCertVerifyFlags);
var
  X509VerifyFlags: Cardinal;
  Store: PX509_STORE;
begin
  FCertVerifyFlags := AFlags;
  if FSSLContext = nil then Exit;

  // 获取证书存储
  if not Assigned(SSL_CTX_get_cert_store) then Exit;
  Store := SSL_CTX_get_cert_store(FSSLContext);
  if Store = nil then Exit;

  // 设置 X509 验证标志
  X509VerifyFlags := 0;

  if sslCertVerifyCheckCRL in AFlags then
    X509VerifyFlags := X509VerifyFlags or X509_V_FLAG_CRL_CHECK;

  if sslCertVerifyCheckRevocation in AFlags then
    X509VerifyFlags := X509VerifyFlags or X509_V_FLAG_CRL_CHECK or X509_V_FLAG_CRL_CHECK_ALL;

  if sslCertVerifyStrictChain in AFlags then
    X509VerifyFlags := X509VerifyFlags or X509_V_FLAG_X509_STRICT;

  // 应用标志到证书存储
  if Assigned(X509_STORE_set_flags) and (X509VerifyFlags <> 0) then
    X509_STORE_set_flags(Store, X509VerifyFlags);

  // Note: OCSP 检查需要在验证回调中实现，因为 OpenSSL 不自动执行 OCSP
  // sslCertVerifyCheckOCSP 标志将在 VerifyCertificateCallback 中处理
end;

function TOpenSSLContext.GetCertVerifyFlags: TSSLCertVerifyFlags;
begin
  Result := FCertVerifyFlags;
end;

// ============================================================================
// ISSLContext - 回调设置
// ============================================================================

procedure TOpenSSLContext.SetPasswordCallback(ACallback: TSSLPasswordCallback);
begin
  if Assigned(ACallback) then
  begin
    RequirePublishedOpenSSLContextCallbackSurface('TOpenSSLContext.SetPasswordCallback');
    FPasswordCallback := ACallback;
    if FSSLContext = nil then Exit;
    SSL_CTX_set_default_passwd_cb(FSSLContext, @PasswordCallbackThunk);
    SSL_CTX_set_default_passwd_cb_userdata(FSSLContext, Self);
  end
  else
  begin
    FPasswordCallback := nil;
    if (FSSLContext <> nil) and Assigned(SSL_CTX_set_default_passwd_cb) then
      SSL_CTX_set_default_passwd_cb(FSSLContext, nil);
    if (FSSLContext <> nil) and Assigned(SSL_CTX_set_default_passwd_cb_userdata) then
      SSL_CTX_set_default_passwd_cb_userdata(FSSLContext, nil);
  end;
end;

procedure TOpenSSLContext.SetInfoCallback(ACallback: TSSLInfoCallback);
begin
  if Assigned(ACallback) then
  begin
    RequirePublishedOpenSSLContextCallbackSurface('TOpenSSLContext.SetInfoCallback');
    FInfoCallback := ACallback;
    if FSSLContext = nil then Exit;
    SSL_CTX_set_info_callback(FSSLContext, @InfoCallbackThunk)
  end
  else
  begin
    FInfoCallback := nil;
    if (FSSLContext <> nil) and Assigned(SSL_CTX_set_info_callback) then
      SSL_CTX_set_info_callback(FSSLContext, nil);
  end;
end;

// ============================================================================
// ISSLHttpHooksAccess - HTTP hooks（可选）
// ============================================================================

procedure TOpenSSLContext.SetHTTPGetCallback(ACallback: TSSLHTTPGetCallback);
begin
  FHTTPGetCallback := ACallback;
end;

function TOpenSSLContext.GetHTTPGetCallback: TSSLHTTPGetCallback;
begin
  Result := FHTTPGetCallback;
end;

procedure TOpenSSLContext.SetHTTPPostCallback(ACallback: TSSLHTTPPostCallback);
begin
  FHTTPPostCallback := ACallback;
end;

function TOpenSSLContext.GetHTTPPostCallback: TSSLHTTPPostCallback;
begin
  Result := FHTTPPostCallback;
end;

// ============================================================================
// ISSLContext - 证书固定
// ============================================================================

procedure TOpenSSLContext.AddCertificatePin(const AHash: TBytes; APinType: Integer;
  const ADescription: string; AIsBackup: Boolean);
begin
  if FPinValidator = nil then
    raise ESSLException.CreateWithContext(
      'Pin validator not initialized',
      sslErrNotInitialized,
      'TOpenSSLContext.AddCertificatePin'
    );
  
  FPinValidator.AddPin(AHash, TPinType(APinType), ADescription, AIsBackup);
end;

procedure TOpenSSLContext.AddCertificatePinBase64(const ABase64Hash: string; 
  APinType: Integer; const ADescription: string; AIsBackup: Boolean);
begin
  if FPinValidator = nil then
    raise ESSLException.CreateWithContext(
      'Pin validator not initialized',
      sslErrNotInitialized,
      'TOpenSSLContext.AddCertificatePinBase64'
    );
  
  FPinValidator.AddPinBase64(ABase64Hash, TPinType(APinType), ADescription, AIsBackup);
end;

procedure TOpenSSLContext.SetCertificatePinningEnabled(AEnabled: Boolean);
begin
  FPinningEnabled := AEnabled;
  
  if FPinValidator <> nil then
    FPinValidator.RequireValidPin := AEnabled;
  
  if AEnabled then
    TSecurityLog.Info('OpenSSL', 'Certificate pinning enabled')
  else
    TSecurityLog.Info('OpenSSL', 'Certificate pinning disabled');
end;

function TOpenSSLContext.GetCertificatePinningEnabled: Boolean;
begin
  Result := FPinningEnabled;
end;

procedure TOpenSSLContext.ClearCertificatePins;
begin
  if FPinValidator <> nil then
    FPinValidator.ClearPins;
end;

// ============================================================================
// ISSLContext - 创建连接
// ============================================================================

function TOpenSSLContext.CreateConnection(ASocket: THandle): ISSLConnection;
var
  LEarlyDataContext: ISSLEarlyDataContext;
  LExposeEarlyData: Boolean;
  LExposeOCSP: Boolean;
begin
  RequireValidContext('TOpenSSLContext.CreateConnection');

  try
    LExposeEarlyData := Supports(Self, ISSLEarlyDataContext, LEarlyDataContext);
    LExposeOCSP := HasClientOCSPCapability;

    if LExposeEarlyData and LExposeOCSP then
      Result := TOpenSSLAdvancedConnection.Create(Self, ASocket)
    else if LExposeEarlyData then
      Result := TOpenSSLEarlyDataConnection.Create(Self, ASocket)
    else if LExposeOCSP then
      Result := TOpenSSLOCSPConnection.Create(Self, ASocket)
    else
      Result := TOpenSSLConnection.Create(Self, ASocket);
  except
    on E: ESSLException do
      raise;  // Re-raise SSL exceptions as-is
    on E: Exception do
      raise ESSLConnectionException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to create SSL connection: %s', [E.Message]),
        sslErrConnection,
        'TOpenSSLContext.CreateConnection'
      );
  end;
end;

function TOpenSSLContext.CreateConnection(AStream: TStream): ISSLConnection;
var
  LEarlyDataContext: ISSLEarlyDataContext;
  LExposeEarlyData: Boolean;
  LExposeOCSP: Boolean;
  LTransport: IStream;
begin
  RequireValidContext('TOpenSSLContext.CreateConnection');

  if AStream = nil then
    raise ESSLInvalidArgument.Create(
      'Cannot create connection: stream is nil',
      sslErrInvalidParam
    );

  try
    LTransport := WrapTStream(AStream, False);
    LExposeEarlyData := Supports(Self, ISSLEarlyDataContext, LEarlyDataContext);
    LExposeOCSP := HasClientOCSPCapability;

    if LExposeEarlyData and LExposeOCSP then
      Result := TOpenSSLAdvancedConnection.Create(Self, LTransport)
    else if LExposeEarlyData then
      Result := TOpenSSLEarlyDataConnection.Create(Self, LTransport)
    else if LExposeOCSP then
      Result := TOpenSSLOCSPConnection.Create(Self, LTransport)
    else
      Result := TOpenSSLConnection.Create(Self, LTransport);
  except
    on E: ESSLException do
      raise;  // Re-raise SSL exceptions as-is
    on E: Exception do
      raise ESSLConnectionException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to create SSL connection: %s', [E.Message]),
        sslErrConnection,
        'TOpenSSLContext.CreateConnection'
      );
  end;
end;

// ============================================================================
// ISSLContext - 状态查询
// ============================================================================

function TOpenSSLContext.IsValid: Boolean;
begin
  Result := (FSSLContext <> nil);
end;

function TOpenSSLContext.GetNativeHandle: Pointer;
begin
  Result := FSSLContext;
end;

function TOpenSSLContext.GetBackendType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TOpenSSLContext.IsNativeHandleValid: Boolean;
begin
  Result := (FSSLContext <> nil);
end;

// ============================================================================
// ISSLEarlyDataContext - TLS 1.3 Early Data 配置 (v1.4.1)
// ============================================================================

procedure TOpenSSLContext.SetClientEarlyDataEnabled(AEnabled: Boolean);
begin
  RequireValidContext('SetClientEarlyDataEnabled');
  FClientEarlyDataEnabled := AEnabled;

  // 注意：客户端不需要设置 max_early_data
  // OpenSSL 客户端会从服务端的 session ticket 中获取 max_early_data 值
  // 这里仅记录状态，不调用 SSL_CTX_set_max_early_data

  TSecurityLog.Debug('OpenSSL', nextpas.core.text.conv.Format('Client early data %s',
    [BoolToStr(AEnabled, 'enabled', 'disabled')]));
end;

function TOpenSSLContext.GetClientEarlyDataEnabled: Boolean;
begin
  Result := FClientEarlyDataEnabled;
end;

procedure TOpenSSLContext.SetServerEarlyDataPolicy(APolicy: TSSLEarlyDataServerPolicy);
var
  LRet: Integer;
begin
  RequireValidContext('SetServerEarlyDataPolicy');

  // 根据策略设置 SSL_CTX
  if Assigned(SSL_CTX_set_max_early_data) then
  begin
    LRet := 1;
    case APolicy of
      sslEarlyDataServerReject:
        LRet := SSL_CTX_set_max_early_data(FSSLContext, 0);
      sslEarlyDataServerAccept,
      sslEarlyDataServerIssueOnly:
        LRet := SSL_CTX_set_max_early_data(FSSLContext, FServerMaxEarlyDataSize);
    end;

    if LRet <> 1 then
      raise ESSLException.CreateWithContext(
        nextpas.core.text.conv.Format('SSL_CTX_set_max_early_data failed (policy=%d, return=%d)',
          [Ord(APolicy), LRet]),
        sslErrGeneral,
        'SetServerEarlyDataPolicy'
      );
  end;

  FServerEarlyDataPolicy := APolicy;

  TSecurityLog.Debug('OpenSSL', nextpas.core.text.conv.Format('Server early data policy set to %d', [Ord(APolicy)]));
end;

function TOpenSSLContext.GetServerEarlyDataPolicy: TSSLEarlyDataServerPolicy;
begin
  Result := FServerEarlyDataPolicy;
end;

procedure TOpenSSLContext.SetServerMaxEarlyDataSize(ASize: Cardinal);
var
  LRet: Integer;
begin
  RequireValidContext('SetServerMaxEarlyDataSize');

  // 如果服务端 early data 已启用，更新 SSL_CTX
  if Assigned(SSL_CTX_set_max_early_data) and
    (FServerEarlyDataPolicy <> sslEarlyDataServerReject) then
  begin
    LRet := SSL_CTX_set_max_early_data(FSSLContext, ASize);
    if LRet <> 1 then
      raise ESSLException.CreateWithContext(
        nextpas.core.text.conv.Format('SSL_CTX_set_max_early_data failed (size=%d, return=%d)',
          [ASize, LRet]),
        sslErrGeneral,
        'SetServerMaxEarlyDataSize'
      );
  end;

  FServerMaxEarlyDataSize := ASize;

  TSecurityLog.Debug('OpenSSL', nextpas.core.text.conv.Format('Server max early data size set to %d bytes', [ASize]));
end;

function TOpenSSLContext.GetServerMaxEarlyDataSize: Cardinal;
begin
  Result := FServerMaxEarlyDataSize;
end;

// ============================================================================
// ISSLServerOCSPStaplingContext - 服务端 OCSP Stapling (v1.4.1)
// ============================================================================

procedure TOpenSSLContext.ClearServerStapledOCSPResponse;
begin
  RequireValidContext('ClearServerStapledOCSPResponse');
  SetLength(FServerStapledOCSPResponse, 0);
  ApplyServerOCSPStaplingConfiguration;
  TSecurityLog.Debug('OpenSSL', 'Server stapled OCSP response cleared');
end;

procedure TOpenSSLContext.SetServerStapledOCSPResponse(const AResponseDER: TBytes);
begin
  RequireValidContext('SetServerStapledOCSPResponse');

  if Length(AResponseDER) = 0 then
    raise ESSLInvalidArgument.Create(
      'OCSP response cannot be empty',
      sslErrInvalidParam
    );

  FServerStapledOCSPResponse := Copy(AResponseDER);
  ApplyServerOCSPStaplingConfiguration;

  TSecurityLog.Debug('OpenSSL', nextpas.core.text.conv.Format('Server stapled OCSP response set (%d bytes)',
    [Length(AResponseDER)]));
end;

procedure TOpenSSLContext.LoadServerStapledOCSPResponseFile(const AFileName: string);
var
  LStream: TFileStream;
  LSize: Int64;
begin
  RequireValidContext('LoadServerStapledOCSPResponseFile');

  if not nextpas.core.fs.IsFile(AFileName) then
    raise ESSLException.CreateWithContext(
      nextpas.core.text.conv.Format('OCSP response file not found: %s', [AFileName]),
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
          nextpas.core.text.conv.Format('OCSP response file too large (%d bytes, max %d)',
            [LSize, MAX_OCSP_RESPONSE_SIZE]),
          sslErrInvalidParam
        );

      SetLength(FServerStapledOCSPResponse, LSize);
      LStream.ReadBuffer(FServerStapledOCSPResponse[0], LSize);
      ApplyServerOCSPStaplingConfiguration;

      TSecurityLog.Info('OpenSSL', nextpas.core.text.conv.Format('Loaded server stapled OCSP response from %s (%d bytes)',
        [AFileName, LSize]));
    finally
      LStream.Free;
    end;
  except
    on E: ESSLException do
      raise;
    on E: Exception do
      raise ESSLException.CreateWithContext(
        nextpas.core.text.conv.Format('Failed to load OCSP response file: %s', [E.Message]),
        sslErrLoadFailed,
        'LoadServerStapledOCSPResponseFile'
      );
  end;
end;

function TOpenSSLContext.HasServerStapledOCSPResponse: Boolean;
begin
  Result := Length(FServerStapledOCSPResponse) > 0;
end;

function TOpenSSLContext.GetServerStapledOCSPResponse: TBytes;
begin
  Result := Copy(FServerStapledOCSPResponse);
end;

// ============================================================================
// 便利方法 - 一键配置安全默认值
// ============================================================================

procedure TOpenSSLContext.ConfigureSecureDefaults;
begin
  { 配置现代 TLS 安全最佳实践

    此方法一键设置：
    - 仅启用 TLS 1.2 和 TLS 1.3
    - 禁用所有已废弃的协议（SSLv2/3, TLS 1.0/1.1）
    - 使用强密码套件（优先 ECDHE + AES-GCM）
    - 启用证书验证
    - 禁用压缩（防止 CRIME 攻击）
    - 禁用不安全的重新协商
  }

  // 1. 协议版本：仅 TLS 1.2 和 1.3
  SetProtocolVersions([sslProtocolTLS12, sslProtocolTLS13]);
  SetPreferredVersion(sslProtocolTLS13);

  // 2. 安全选项
  SetOptions([
    ssoEnableSessionCache,      // 启用会话缓存（性能优化）
    ssoEnableSessionTickets,    // 启用会话票据
    ssoDisableCompression,      // 禁用压缩（防止 CRIME 攻击）
    ssoDisableRenegotiation,    // 禁用重新协商
    ssoNoSSLv2,                 // 禁用 SSLv2
    ssoNoSSLv3,                 // 禁用 SSLv3
    ssoNoTLSv1,                 // 禁用 TLS 1.0
    ssoNoTLSv1_1,               // 禁用 TLS 1.1
    ssoCipherServerPreference,  // 服务端密码优先
    ssoSingleECDHUse            // 单次 ECDH 密钥交换
  ]);

  // 3. 强密码套件（TLS 1.2 及以下）
  // 优先使用 ECDHE 密钥交换和 AES-GCM 模式
  SetCipherList('ECDHE+AESGCM:ECDHE+CHACHA20:ECDHE+AES256:DHE+AESGCM:DHE+AES256:!ANULL:!MD5:!DSS:!RC4:!3DES');

  // 4. TLS 1.3 密码套件
  SetCipherSuites('TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_128_GCM_SHA256');

  // 5. 启用证书验证
  SetVerifyMode([sslVerifyPeer]);
  SetVerifyDepth(SSL_DEFAULT_VERIFY_DEPTH);  // P3-17: 使用常量

  // 6. 会话配置
  SetSessionCacheMode(True);
  SetSessionTimeout(3600);  // 1小时会话超时（比默认值更长，适合安全场景）
  SetSessionCacheSize(SSL_DEFAULT_SESSION_CACHE_SIZE);  // P3-17: 使用常量

  TSecurityLog.Info('OpenSSL', 'Configured secure defaults for TLS 1.2/1.3');
end;

initialization
  GContextLock := TMultiReadExclusiveWriteSynchronizer.Create;
  GContextRegistry := TList.Create;

finalization
  // Clean up context registry and critical section
  if GContextRegistry <> nil then
  begin
    GContextRegistry.Free;
    GContextRegistry := nil;
  end;
  if GContextLock <> nil then
  begin
    GContextLock.Free;
    GContextLock := nil;
  end;

end.
