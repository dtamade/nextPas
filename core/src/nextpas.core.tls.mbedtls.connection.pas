{**
 * Unit: nextpas.core.tls.mbedtls.connection
 * Purpose: MbedTLS 连接实现
 *
 * 继承 TBaseSSLConnection 基类，实现 MbedTLS 后端的连接功能。
 * 负责 TLS 握手、数据传输和连接管理。
 *
 * @author fafafa.ssl team
 * @version 2.0.0
 * @since 2026-01-10
 * @updated 2026-02-04 - 重构为使用 TBaseSSLConnection 基类
 *}

unit nextpas.core.tls.mbedtls.connection;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  nextpas.core.base,
  nextpas.core.text.conv, nextpas.core.system.classes, Sockets,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.connection.base,
  nextpas.core.io.intf,
  nextpas.core.io.stream_adapter,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.native_handle,
  nextpas.core.tls.mbedtls.api;

type
  PMbedTLSIOContext = ^TMbedTLSIOContext;
  TMbedTLSIOContext = record
    Stream: IStream;
  end;

  { TMbedTLSConnection - MbedTLS 连接类 }
  TMbedTLSConnection = class(TBaseSSLConnection, ISSLClientConnection,
    ISSLNativeHandleAccess)
  private
    FSSLConfig: Pmbedtls_ssl_config;
    FSSLContext: Pmbedtls_ssl_context;
    FSocket: THandle;
    FStream: IStream;
    FIOContext: PMbedTLSIOContext;
    FServerName: string;
    FALPNProtocols: string;
    FNegotiatedALPN: string;
    FLastNativeError: Integer;
    FSessionReused: Boolean;

    procedure AllocateSSLContext;
    procedure SetupTransportBIO;
    procedure FreeIOContext;
    procedure FreeSSLContext;

  protected
    { 抽象方法实现 }
    function DoRead(var ABuffer; ACount: Integer): Integer; override;
    function DoWrite(const ABuffer; ACount: Integer): Integer; override;
    function DoConnect: Boolean; override;
    function DoAccept: Boolean; override;
    function DoHandshakeInternal: TSSLHandshakeState; override;
    function DoShutdown: Boolean; override;
    procedure DoClose; override;
    function DoRenegotiate: Boolean; override;
    function DoGetError(ARet: Integer): TSSLErrorCode; override;
    function DoWantRead: Boolean; override;
    function DoWantWrite: Boolean; override;
    function DoGetProtocolVersion: TSSLProtocolVersion; override;
    function DoGetCipherName: string; override;
    function DoGetPeerCertificate: ISSLCertificate; override;
    function DoGetPeerCertificateChain: TSSLCertificateArray; override;
    function DoGetVerifyResult: Integer; override;
    function DoGetVerifyResultString: string; override;
    function DoGetSession: ISSLSession; override;
    procedure DoSetSession(ASession: ISSLSession); override;
    function DoIsSessionReused: Boolean; override;
    function DoGetConnectionInfoServerName: string; override;
    function DoGetSelectedALPNProtocol: string; override;
    function DoGetState: string; override;
    function DoGetNativeHandle: Pointer; override;

    { OCSP 方法覆盖 }
    function DoGetOCSPStaplingEnabled: Boolean; override;
    function DoGetOCSPResponse: TBytes; override;
    function DoIsOCSPResponseVerified: Boolean; override;
    function DoGetOCSPResponseStatus: string; override;

  public
    constructor Create(AContext: ISSLContext; ASSLConfig: Pmbedtls_ssl_config; ASocket: THandle); overload;
    constructor Create(AContext: ISSLContext; ASSLConfig: Pmbedtls_ssl_config; AStream: TStream); overload;
    constructor Create(AContext: ISSLContext; ASSLConfig: Pmbedtls_ssl_config; AStream: IStream); overload;
    destructor Destroy; override;

    function GetConnectionInfo: TSSLConnectionInfo; override;

    { SNI/ALPN 设置 }
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;

    { 额外方法 }
    function GetNegotiatedProtocol: TSSLProtocolVersion;
    function GetNegotiatedCipher: string;
    function GetNegotiatedALPN: string;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
    function GetLastError: Integer;
    function GetLastErrorString: string;
  end;

implementation

uses
  nextpas.core.tls.mbedtls.certificate,
  nextpas.core.tls.mbedtls.session;

const
  MBEDTLS_SSL_CONTEXT_SIZE = 4096;  // Increased for safety
  MBEDTLS_X509_CRT_CHAIN_MAX_DEPTH = 16;
  {$IFDEF CPU64}
  // Verified against the MbedTLS 3.x 64-bit x509_crt layout shipped on the
  // supported CI/runtime targets; this reaches the `next` chain link.
  MBEDTLS_X509_CRT_NEXT_OFFSET = 736;
  {$ENDIF}

type
  PPmbedtls_x509_crt = ^Pmbedtls_x509_crt;

function TryGetNextPeerCertificateInChain(
  ACurrent: Pmbedtls_x509_crt;
  out ANext: Pmbedtls_x509_crt
): Boolean;
var
  LNextPtr: PPmbedtls_x509_crt;
begin
  ANext := nil;
  {$IFDEF CPU64}
  if ACurrent = nil then
    Exit(False);

  LNextPtr := PPmbedtls_x509_crt(PtrUInt(ACurrent) + MBEDTLS_X509_CRT_NEXT_OFFSET);
  ANext := LNextPtr^;
  Result := ANext <> nil;
  {$ELSE}
  Result := False;
  {$ENDIF}
end;

function MaterializePeerCertificateChain(
  AHead: Pmbedtls_x509_crt
): TSSLCertificateArray;
var
  LCursor: Pmbedtls_x509_crt;
  LNext: Pmbedtls_x509_crt;
  LTempCert: TMbedTLSCertificate;
  LClone: ISSLCertificate;
  I: Integer;
begin
  SetLength(Result, 0);
  if AHead = nil then
    Exit;

  LCursor := AHead;
  while (LCursor <> nil) and (Length(Result) < MBEDTLS_X509_CRT_CHAIN_MAX_DEPTH) do
  begin
    LTempCert := TMbedTLSCertificate.Create(LCursor, False);
    try
      LClone := LTempCert.Clone;
    finally
      LTempCert.Free;
    end;

    if LClone = nil then
    begin
      SetLength(Result, 0);
      Exit;
    end;

    SetLength(Result, Length(Result) + 1);
    Result[High(Result)] := LClone;

    if not TryGetNextPeerCertificateInChain(LCursor, LNext) then
      Break;
    LCursor := LNext;
  end;

  for I := 0 to High(Result) - 1 do
    Result[I].SetIssuerCertificate(Result[I + 1]);
end;

{ Socket BIO callbacks for MbedTLS }
function MbedTLSSocketSend(ctx: Pointer; const buf: PByte; len: NativeUInt): Integer; cdecl;
var
  LSocket: TSocket;
begin
  LSocket := TSocket(PtrUInt(ctx));
  Result := fpSend(LSocket, buf, len, 0);
  if Result < 0 then
    Result := MBEDTLS_ERR_SSL_WANT_WRITE;
end;

function MbedTLSSocketRecv(ctx: Pointer; buf: PByte; len: NativeUInt): Integer; cdecl;
var
  LSocket: TSocket;
begin
  LSocket := TSocket(PtrUInt(ctx));
  Result := fpRecv(LSocket, buf, len, 0);
  if Result < 0 then
    Result := MBEDTLS_ERR_SSL_WANT_READ
  else if Result = 0 then
    Result := MBEDTLS_ERR_SSL_CONN_EOF;
end;

{ Stream BIO callbacks for MbedTLS }
function MbedTLSStreamSend(ctx: Pointer; const buf: PByte; len: NativeUInt): Integer; cdecl;
var
  LContext: PMbedTLSIOContext;
begin
  LContext := PMbedTLSIOContext(ctx);
  if (LContext = nil) or (LContext^.Stream = nil) then
    Exit(MBEDTLS_ERR_SSL_WANT_WRITE);
  try
    Result := Integer(LContext^.Stream.Write(buf^, len));
    if Result <= 0 then
      Result := MBEDTLS_ERR_SSL_WANT_WRITE;
  except
    Result := MBEDTLS_ERR_SSL_WANT_WRITE;
  end;
end;

function MbedTLSStreamRecv(ctx: Pointer; buf: PByte; len: NativeUInt): Integer; cdecl;
var
  LContext: PMbedTLSIOContext;
begin
  LContext := PMbedTLSIOContext(ctx);
  if (LContext = nil) or (LContext^.Stream = nil) then
    Exit(MBEDTLS_ERR_SSL_WANT_READ);
  try
    Result := Integer(LContext^.Stream.Read(buf^, len));
    if Result < 0 then
      Result := MBEDTLS_ERR_SSL_WANT_READ
    else if Result = 0 then
      Result := MBEDTLS_ERR_SSL_CONN_EOF;
  except
    Result := MBEDTLS_ERR_SSL_WANT_READ;
  end;
end;

{ TMbedTLSConnection }

constructor TMbedTLSConnection.Create(AContext: ISSLContext; ASSLConfig: Pmbedtls_ssl_config; ASocket: THandle);
begin
  inherited Create(AContext);
  FSSLConfig := ASSLConfig;
  FSocket := ASocket;
  FStream := nil;
  FIOContext := nil;
  FSSLContext := nil;
  FServerName := '';
  FALPNProtocols := '';
  FNegotiatedALPN := '';
  FLastNativeError := 0;
  FSessionReused := False;

  AllocateSSLContext;
end;

constructor TMbedTLSConnection.Create(AContext: ISSLContext; ASSLConfig: Pmbedtls_ssl_config; AStream: TStream);
begin
  Create(AContext, ASSLConfig, WrapTStream(AStream, False));
end;

constructor TMbedTLSConnection.Create(AContext: ISSLContext; ASSLConfig: Pmbedtls_ssl_config; AStream: IStream);
begin
  inherited Create(AContext);
  FSSLConfig := ASSLConfig;
  FSocket := 0;
  FStream := AStream;
  FIOContext := nil;
  FSSLContext := nil;
  FServerName := '';
  FALPNProtocols := '';
  FNegotiatedALPN := '';
  FLastNativeError := 0;
  FSessionReused := False;

  AllocateSSLContext;
end;

destructor TMbedTLSConnection.Destroy;
begin
  if FConnected then
    DoShutdown;
  FreeIOContext;
  FreeSSLContext;
  inherited Destroy;
end;

procedure TMbedTLSConnection.AllocateSSLContext;
var
  LRet: Integer;
begin
  if FSSLContext <> nil then
    FreeSSLContext;

  // Allocate SSL context
  GetMem(FSSLContext, MBEDTLS_SSL_CONTEXT_SIZE);
  FillChar(FSSLContext^, MBEDTLS_SSL_CONTEXT_SIZE, 0);

  if Assigned(mbedtls_ssl_init) then
    mbedtls_ssl_init(FSSLContext);

  // Setup SSL context with config
  if Assigned(mbedtls_ssl_setup) and (FSSLConfig <> nil) then
  begin
    LRet := mbedtls_ssl_setup(FSSLContext, FSSLConfig);
    if LRet <> 0 then
      raise ESSLException.CreateFmt('mbedtls_ssl_setup failed: 0x%04X', [-LRet]);
  end;
end;

procedure TMbedTLSConnection.SetupTransportBIO;
begin
  if (FSSLContext = nil) or (not Assigned(mbedtls_ssl_set_bio)) then
    Exit;

  if FStream <> nil then
  begin
    if FIOContext = nil then
    begin
      New(FIOContext);
      FillChar(FIOContext^, SizeOf(TMbedTLSIOContext), 0);
    end;
    FIOContext^.Stream := FStream;
    mbedtls_ssl_set_bio(FSSLContext, Pointer(FIOContext),
      @MbedTLSStreamSend, @MbedTLSStreamRecv, nil);
    Exit;
  end;

  mbedtls_ssl_set_bio(FSSLContext, Pointer(PtrUInt(FSocket)),
    @MbedTLSSocketSend, @MbedTLSSocketRecv, nil);
end;

procedure TMbedTLSConnection.FreeIOContext;
begin
  if FIOContext = nil then
    Exit;
  FIOContext^.Stream := nil;
  Dispose(FIOContext);
  FIOContext := nil;
end;

procedure TMbedTLSConnection.FreeSSLContext;
begin
  if FSSLContext <> nil then
  begin
    if Assigned(mbedtls_ssl_free) then
      mbedtls_ssl_free(FSSLContext);
    FreeMem(FSSLContext);
    FSSLContext := nil;
  end;
end;

{ 抽象方法实现 }

function TMbedTLSConnection.DoRead(var ABuffer; ACount: Integer): Integer;
begin
  Result := -1;
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_read) then Exit;

  Result := mbedtls_ssl_read(FSSLContext, @ABuffer, ACount);
  if Result < 0 then
    FLastNativeError := Result;
end;

function TMbedTLSConnection.DoWrite(const ABuffer; ACount: Integer): Integer;
begin
  Result := -1;
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_write) then Exit;

  Result := mbedtls_ssl_write(FSSLContext, @ABuffer, ACount);
  if Result < 0 then
    FLastNativeError := Result;
end;

function TMbedTLSConnection.DoConnect: Boolean;
var
  LResult: Integer;
begin
  Result := False;
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_handshake) then Exit;
  SetupTransportBIO;

  LResult := mbedtls_ssl_handshake(FSSLContext);
  FLastNativeError := LResult;
  Result := LResult = 0;
end;

function TMbedTLSConnection.DoAccept: Boolean;
begin
  Result := DoConnect;
end;

function TMbedTLSConnection.DoHandshakeInternal: TSSLHandshakeState;
begin
  if FHandshakeComplete then
    Result := sslHsCompleted
  else if DoConnect then
    Result := sslHsCompleted
  else
  begin
    // 检查是否需要重试
    if DoWantRead or DoWantWrite then
      Result := sslHsInProgress
    else
      Result := sslHsFailed;
  end;
end;

function TMbedTLSConnection.DoShutdown: Boolean;
var
  LResult: Integer;
begin
  Result := False;
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_close_notify) then Exit;

  LResult := mbedtls_ssl_close_notify(FSSLContext);
  Result := LResult >= 0;
end;

procedure TMbedTLSConnection.DoClose;
begin
  DoShutdown;
  FreeIOContext;
end;

function TMbedTLSConnection.DoRenegotiate: Boolean;
begin
  RecordError(
    sslErrUnsupported,
    'TLS renegotiation is not supported by the current MbedTLS backend. ' +
    'Close the connection and establish a new one instead.'
  );
  Result := False;
end;

function TMbedTLSConnection.DoGetError(ARet: Integer): TSSLErrorCode;
begin
  if (ARet < 0) and (FLastErrorCode <> sslErrNone) then
    Exit(FLastErrorCode);

  Result := MbedTLSErrorToSSLError(ARet);
end;

function TMbedTLSConnection.DoWantRead: Boolean;
begin
  Result := FLastNativeError = MBEDTLS_ERR_SSL_WANT_READ;
end;

function TMbedTLSConnection.DoWantWrite: Boolean;
begin
  Result := FLastNativeError = MBEDTLS_ERR_SSL_WANT_WRITE;
end;

function TMbedTLSConnection.DoGetProtocolVersion: TSSLProtocolVersion;
var
  LVersion: PAnsiChar;
begin
  Result := sslProtocolTLS12;  // Default fallback
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_get_version) then Exit;

  LVersion := mbedtls_ssl_get_version(FSSLContext);
  if LVersion = nil then Exit;

  // Map MbedTLS version string to TSSLProtocolVersion
  if Pos('TLSv1.3', string(LVersion)) > 0 then
    Result := sslProtocolTLS13
  else if Pos('TLSv1.2', string(LVersion)) > 0 then
    Result := sslProtocolTLS12
  else if Pos('TLSv1.1', string(LVersion)) > 0 then
    Result := sslProtocolTLS11
  else if Pos('TLSv1.0', string(LVersion)) > 0 then
    Result := sslProtocolTLS10
  else if Pos('SSLv3', string(LVersion)) > 0 then
    Result := sslProtocolSSL3;
end;

function TMbedTLSConnection.DoGetCipherName: string;
begin
  Result := '';
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_get_ciphersuite) then Exit;

  Result := string(mbedtls_ssl_get_ciphersuite(FSSLContext));
end;

function TMbedTLSConnection.DoGetPeerCertificate: ISSLCertificate;
var
  LPeerCert: Pmbedtls_x509_crt;
  LChain: TSSLCertificateArray;
begin
  Result := nil;
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_get_peer_cert) then Exit;

  LPeerCert := mbedtls_ssl_get_peer_cert(FSSLContext);
  if LPeerCert <> nil then
  begin
    LChain := MaterializePeerCertificateChain(LPeerCert);
    if Length(LChain) > 0 then
      Result := LChain[0];
  end;
end;

function TMbedTLSConnection.DoGetPeerCertificateChain: TSSLCertificateArray;
var
  LPeerCert: Pmbedtls_x509_crt;
begin
  SetLength(Result, 0);
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_get_peer_cert) then Exit;

  LPeerCert := mbedtls_ssl_get_peer_cert(FSSLContext);
  if LPeerCert <> nil then
    Result := MaterializePeerCertificateChain(LPeerCert);
end;

function TMbedTLSConnection.DoGetVerifyResult: Integer;
begin
  Result := -1;
  if not FHandshakeComplete then Exit;
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_get_verify_result) then Exit;

  Result := mbedtls_ssl_get_verify_result(FSSLContext);
end;

function TMbedTLSConnection.DoGetVerifyResultString: string;
var
  LBuf: array[0..511] of AnsiChar;
  LFlags: Cardinal;
begin
  if (FLastErrorCode <> sslErrNone) and (FLastErrorString <> '') then
    Exit(FLastErrorString);

  if not FHandshakeComplete then
    Exit('Not verified');

  Result := 'Verification status unavailable';
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_get_verify_result) then Exit;
  if not Assigned(mbedtls_x509_crt_verify_info) then Exit;

  LFlags := mbedtls_ssl_get_verify_result(FSSLContext);
  if LFlags = 0 then
  begin
    Result := 'OK';
    Exit;
  end;

  FillChar(LBuf, SizeOf(LBuf), 0);
  mbedtls_x509_crt_verify_info(@LBuf[0], SizeOf(LBuf), '', LFlags);
  Result := Trim(string(LBuf));
end;

function TMbedTLSConnection.DoGetSession: ISSLSession;
begin
  Result := TMbedTLSSession.FromContext(FSSLContext);
end;

procedure TMbedTLSConnection.DoSetSession(ASession: ISSLSession);
var
  LRet: Integer;
begin
  FSessionReused := False;
  if ASession = nil then Exit;
  if FSSLContext = nil then Exit;
  if not Assigned(mbedtls_ssl_set_session) then Exit;

  LRet := mbedtls_ssl_set_session(FSSLContext, Pmbedtls_ssl_session(GetNativeHandleSafe(ASession, 'TMbedTLSConnection.DoSetSession')));
  if LRet <> 0 then
    Exit;
end;

function TMbedTLSConnection.DoIsSessionReused: Boolean;
begin
  Result := FSessionReused;
end;

function TMbedTLSConnection.DoGetConnectionInfoServerName: string;
begin
  Result := FServerName;
end;

function TMbedTLSConnection.GetConnectionInfo: TSSLConnectionInfo;
var
  LCipherSuiteId: Integer;
  LCipherSuiteName: PAnsiChar;
  LCipherSuiteInfo: Pmbedtls_ssl_ciphersuite_info;
  LMdInfo: Pointer;
begin
  Result := inherited GetConnectionInfo;

  if FSSLContext = nil then
    Exit;

  LCipherSuiteId := 0;
  if Assigned(mbedtls_ssl_get_ciphersuite_id_from_ssl) then
    LCipherSuiteId := mbedtls_ssl_get_ciphersuite_id_from_ssl(FSSLContext);

  if (LCipherSuiteId <= 0) and Assigned(mbedtls_ssl_get_ciphersuite) and
     Assigned(mbedtls_ssl_get_ciphersuite_id) then
  begin
    LCipherSuiteName := mbedtls_ssl_get_ciphersuite(FSSLContext);
    if LCipherSuiteName <> nil then
      LCipherSuiteId := mbedtls_ssl_get_ciphersuite_id(LCipherSuiteName);
  end;

  if LCipherSuiteId <= 0 then
    Exit;

  Result.CipherSuiteId := Word(LCipherSuiteId and $FFFF);

  if not Assigned(mbedtls_ssl_ciphersuite_from_id) then
    Exit;

  LCipherSuiteInfo := mbedtls_ssl_ciphersuite_from_id(LCipherSuiteId);
  if LCipherSuiteInfo = nil then
    Exit;

  if (Result.KeySize = 0) and Assigned(mbedtls_ssl_ciphersuite_get_cipher_key_bitlen) then
    Result.KeySize := Integer(mbedtls_ssl_ciphersuite_get_cipher_key_bitlen(LCipherSuiteInfo));

  if (Result.MacSize = 0) and (LCipherSuiteInfo^.mac <> MBEDTLS_MD_NONE) and
     Assigned(mbedtls_md_info_from_type) and Assigned(mbedtls_md_get_size) then
  begin
    LMdInfo := mbedtls_md_info_from_type(LCipherSuiteInfo^.mac);
    if LMdInfo <> nil then
      Result.MacSize := Integer(mbedtls_md_get_size(LMdInfo));
  end;
end;

function TMbedTLSConnection.DoGetSelectedALPNProtocol: string;
begin
  Result := FNegotiatedALPN;
  if (Result = '') and (FSSLContext <> nil) and Assigned(mbedtls_ssl_get_alpn_protocol) then
  begin
    Result := string(mbedtls_ssl_get_alpn_protocol(FSSLContext));
    FNegotiatedALPN := Result;
  end;
end;

function TMbedTLSConnection.DoGetState: string;
begin
  if FHandshakeComplete then
    Result := 'CONNECTED'
  else
    Result := 'DISCONNECTED';
end;

function TMbedTLSConnection.DoGetNativeHandle: Pointer;
begin
  Result := FSSLContext;
end;

{ OCSP 方法覆盖 }

function TMbedTLSConnection.DoGetOCSPStaplingEnabled: Boolean;
begin
  // MbedTLS 不支持客户端 OCSP Stapling
  // 只有服务器端可以发送 OCSP 响应
  Result := False;
end;

function TMbedTLSConnection.DoGetOCSPResponse: TBytes;
begin
  // MbedTLS 客户端无法接收 OCSP Stapling 响应
  Result := nil;
end;

function TMbedTLSConnection.DoIsOCSPResponseVerified: Boolean;
begin
  // MbedTLS 不支持客户端 OCSP Stapling
  Result := False;
end;

function TMbedTLSConnection.DoGetOCSPResponseStatus: string;
begin
  // MbedTLS 库限制：不支持客户端 OCSP Stapling
  Result := 'Not Supported (MbedTLS limitation)';
end;

{ SNI/ALPN 设置 }

procedure TMbedTLSConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
  if (FSSLContext <> nil) and (FServerName <> '') and Assigned(mbedtls_ssl_set_hostname) then
    mbedtls_ssl_set_hostname(FSSLContext, PAnsiChar(AnsiString(FServerName)));
end;

function TMbedTLSConnection.GetServerName: string;
begin
  Result := FServerName;
end;

{ 额外方法 }

function TMbedTLSConnection.GetNegotiatedProtocol: TSSLProtocolVersion;
begin
  Result := DoGetProtocolVersion;
end;

function TMbedTLSConnection.GetNegotiatedCipher: string;
begin
  Result := DoGetCipherName;
end;

function TMbedTLSConnection.GetNegotiatedALPN: string;
begin
  Result := DoGetSelectedALPNProtocol;
end;

function TMbedTLSConnection.GetBackendType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TMbedTLSConnection.IsNativeHandleValid: Boolean;
begin
  Result := (FSSLContext <> nil);
end;

function TMbedTLSConnection.GetLastError: Integer;
begin
  Result := FLastNativeError;
end;

function TMbedTLSConnection.GetLastErrorString: string;
var
  LBuf: array[0..255] of AnsiChar;
begin
  Result := '';
  if FLastNativeError = 0 then Exit;
  if not Assigned(mbedtls_strerror) then Exit;

  FillChar(LBuf, SizeOf(LBuf), 0);
  mbedtls_strerror(FLastNativeError, @LBuf[0], SizeOf(LBuf));
  Result := string(LBuf);
end;

end.
