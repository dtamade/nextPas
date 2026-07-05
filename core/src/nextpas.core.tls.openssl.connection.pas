{**
 * Unit: nextpas.core.tls.openssl.connection
 * Purpose: OpenSSL 连接实现
 *
 * 继承 TBaseSSLConnection 基类，实现 OpenSSL 后端的连接功能。
 * 支持 Socket 和 Stream 两种传输模式，包含完整的证书验证。
 *
 * @author fafafa.ssl team
 * @version 2.0.0
 * @since 2025-11-02
 * @updated 2026-02-04 - 重构为使用 TBaseSSLConnection 基类
 *}

unit nextpas.core.tls.openssl.connection;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  nextpas.core.base,
  nextpas.core.sync,
  nextpas.core.base.utils,
  nextpas.core.io.intf,
  nextpas.core.io.stream_adapter,
  nextpas.core.io.util,
  nextpas.core.text.conv,
  nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.net.hooks,
  nextpas.core.tls.ocsp,
  nextpas.core.tls.x509,
  nextpas.core.tls.connection.base,
  nextpas.core.tls.openssl.errors,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.loader,
  nextpas.core.tls.openssl.native_handle,  // 原生句柄辅助函数
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.evp,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.api.x509,
  nextpas.core.tls.openssl.api.stack,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.err,
  nextpas.core.tls.openssl.api.ocsp,
  nextpas.core.tls.openssl.x509.chain,
  nextpas.core.tls.openssl.certificate,
  nextpas.core.tls.openssl.session,
  nextpas.core.tls.cert.verify.cache,
  nextpas.core.tls.logging;

type
  TOpenSSLConnection = class(TBaseSSLConnection, ISSLClientConnection,
    ISSLNativeHandleAccess)
  private
    FSocket: THandle;
    FStream: IStream;
    FSSL: PSSL;
    FBioRead: PBIO;
    FBioWrite: PBIO;
    FServerName: string;
    FLastSSLError: Integer;
    FConfiguredSession: ISSLSession;
    FEarlyDataPayload: TBytes;
    FEarlyDataStatus: TSSLEarlyDataStatus;
    FEarlyDataLimit: Cardinal;

    function HasStreamTransport: Boolean;
    function PumpStreamToBIO: Integer;
    function PumpBIOToStream: Integer;
    function CreateCertificateFromOwnedRef(AX509: PX509): ISSLCertificate;
    function CreateRetainedCertificate(AX509: PX509): ISSLCertificate;
    function FindRetainedPeerIssuerCertificate(APeerX509: PX509): ISSLCertificate;
    procedure LinkPeerCertificateChainIssuerLinks(const AChain: PSTACK_OF_X509;
      const ACertificates: TSSLCertificateArray);
    function InternalHandshake(AIsClient: Boolean): Boolean;
    function ValidatePostHandshake(AIsClient: Boolean): Boolean;
    procedure ApplyPreHandshakeOCSPStatusRequest(AIsClient: Boolean);
    function ResolveEarlyDataLimitFromSession(const ASession: ISSLSession): Cardinal;
    function SendQueuedEarlyData: Boolean;
    procedure UpdateEarlyDataStatusFromNative;

  protected
    { B51-M5: required OCSP stapling fail-closed policy helper }
    function ValidateRequiredOCSPStapling(AIsClient: Boolean): Boolean;

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
    constructor Create(AContext: ISSLContext; ASocket: THandle); overload;
    constructor Create(AContext: ISSLContext; AStream: IStream); overload;
    destructor Destroy; override;

    { ISSLClientConnection }
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;

    { ISSLEarlyDataConnection }
    function SetEarlyData(const AData: TBytes): TSSLOperationResult;
    function GetEarlyDataStatus: TSSLEarlyDataStatus;
    function GetEarlyDataLimit: Cardinal;

    { ISSLNativeHandleAccess }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    { 覆盖基类方法以添加日志 }
    function DoHandshake: TSSLHandshakeState; reintroduce;

    { 覆盖 GetConnectionInfo 以提供更多详情 }
    function GetConnectionInfo: TSSLConnectionInfo; override;

    { 覆盖 GetStateString }
    function GetStateString: string; override;
  end;

  { 仅在 parent context 暴露 OCSP capability 时才暴露该接口 }
  TOpenSSLOCSPConnection = class(TOpenSSLConnection, ISSLOCSPStapling)
  end;

  { 仅在 parent context 暴露 early-data capability 时才暴露该接口 }
  TOpenSSLEarlyDataConnection = class(TOpenSSLConnection, ISSLEarlyDataConnection)
  end;

  { 同时暴露 early-data 与 OCSP 两类可选接口 }
  TOpenSSLAdvancedConnection = class(TOpenSSLEarlyDataConnection, ISSLOCSPStapling)
  end;

implementation

const
  SSL_IO_BUFFER_SIZE = 8192;
  SSL_EARLY_DATA_NOT_SENT = 0;
  SSL_EARLY_DATA_REJECTED = 1;
  SSL_EARLY_DATA_ACCEPTED = 2;

constructor TOpenSSLConnection.Create(AContext: ISSLContext; ASocket: THandle);
var
  Ctx: PSSL_CTX;
begin
  inherited Create(AContext);
  FSocket := ASocket;
  FStream := nil;
  FBioRead := nil;
  FBioWrite := nil;
  FLastSSLError := 0;
  FConfiguredSession := nil;
  SetLength(FEarlyDataPayload, 0);
  FEarlyDataStatus := sslEarlyDataNone;
  FEarlyDataLimit := 0;

  // 使用辅助函数安全获取原生句柄
  Ctx := PSSL_CTX(GetNativeHandleSafe(AContext, 'TOpenSSLConnection.Create'));

  if not Assigned(SSL_new) then
    RaiseFunctionNotAvailable('SSL_new');

  FSSL := SSL_new(Ctx);
  if FSSL = nil then
    RaiseSSLInitError(
      'Failed to create SSL object',
      'TOpenSSLConnection.Create'
    );

  FServerName := '';

  if not Assigned(SSL_set_fd) then
    RaiseFunctionNotAvailable('SSL_set_fd');

  SSL_set_fd(FSSL, ASocket);
end;

constructor TOpenSSLConnection.Create(AContext: ISSLContext; AStream: IStream);
var
  Ctx: PSSL_CTX;
  LConstructed: Boolean;

  procedure CleanupUnattachedBIO(var ABIO: PBIO);
  begin
    if ABIO <> nil then
    begin
      if Assigned(BIO_free) then
        BIO_free(ABIO);
      ABIO := nil;
    end;
  end;
begin
  inherited Create(AContext);
  FSocket := THandle(-1);
  FStream := AStream;
  FBioRead := nil;
  FBioWrite := nil;
  FLastSSLError := 0;
  FConfiguredSession := nil;
  SetLength(FEarlyDataPayload, 0);
  FEarlyDataStatus := sslEarlyDataNone;
  FEarlyDataLimit := 0;

  // 使用辅助函数安全获取原生句柄
  Ctx := PSSL_CTX(GetNativeHandleSafe(AContext, 'TOpenSSLConnection.Create'));

  if not Assigned(SSL_new) then
    RaiseFunctionNotAvailable('SSL_new');

  FSSL := SSL_new(Ctx);
  if FSSL = nil then
    RaiseSSLInitError(
      'Failed to create SSL object',
      'TOpenSSLConnection.Create'
    );

  LConstructed := False;
  try
    FServerName := '';

    // Ensure BIO API is available
    if not TOpenSSLLoader.IsModuleLoaded(osmBIO) then
      LoadOpenSSLBIO;

    if (not Assigned(BIO_new)) or (not Assigned(BIO_s_mem)) or
      (not Assigned(SSL_set_bio)) then
      RaiseFunctionNotAvailable('OpenSSL BIO API (BIO_new/BIO_s_mem/SSL_set_bio)');

    // Create separate memory BIOs for incoming and outgoing encrypted data
    FBioRead := BIO_new(BIO_s_mem());
    if FBioRead = nil then
      RaiseMemoryError('create read BIO');

    FBioWrite := BIO_new(BIO_s_mem());
    if FBioWrite = nil then
      RaiseMemoryError('create write BIO');

    // Attach BIOs to SSL; SSL takes ownership and will free them in SSL_free
    SSL_set_bio(FSSL, FBioRead, FBioWrite);
    LConstructed := True;
  finally
    if not LConstructed then
    begin
      CleanupUnattachedBIO(FBioRead);
      CleanupUnattachedBIO(FBioWrite);
      if FSSL <> nil then
      begin
        if Assigned(SSL_free) then
          SSL_free(FSSL);
        FSSL := nil;
      end;
    end;
  end;
end;

destructor TOpenSSLConnection.Destroy;
begin
  if FConnected then
    DoShutdown;
  if FSSL <> nil then
  begin
    if Assigned(SSL_free) then
      SSL_free(FSSL);
    FSSL := nil;
  end;
  inherited Destroy;
end;

procedure TOpenSSLConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;

  // Apply SNI on the underlying SSL handle (must be set before handshake)
  if (FServerName <> '') and Assigned(SSL_set_tlsext_host_name) and Assigned(FSSL) then
    SSL_set_tlsext_host_name(FSSL, PAnsiChar(AnsiString(FServerName)));
end;

function TOpenSSLConnection.GetServerName: string;
begin
  Result := FServerName;
end;

function TOpenSSLConnection.ResolveEarlyDataLimitFromSession(
  const ASession: ISSLSession): Cardinal;
var
  LNativeSession: PSSL_SESSION;
begin
  Result := 0;

  if (ASession <> nil) and Assigned(SSL_SESSION_get_max_early_data) and
    TryGetNativeHandle(ASession, Pointer(LNativeSession)) and
    (LNativeSession <> nil) then
    Exit(SSL_SESSION_get_max_early_data(LNativeSession));

  if (FSSL <> nil) and Assigned(SSL_get_max_early_data) then
    Result := SSL_get_max_early_data(FSSL);
end;

procedure TOpenSSLConnection.UpdateEarlyDataStatusFromNative;
var
  LNativeStatus: Integer;
begin
  if (FSSL = nil) or (not Assigned(SSL_get_early_data_status)) then
    Exit;

  LNativeStatus := SSL_get_early_data_status(FSSL);
  case LNativeStatus of
    SSL_EARLY_DATA_ACCEPTED:
      FEarlyDataStatus := sslEarlyDataAccepted;
    SSL_EARLY_DATA_REJECTED:
      FEarlyDataStatus := sslEarlyDataRejected;
    SSL_EARLY_DATA_NOT_SENT:
      begin
        if FEarlyDataStatus = sslEarlyDataQueued then
          FEarlyDataStatus := sslEarlyDataRejected
        else
          FEarlyDataStatus := sslEarlyDataNone;
      end;
  end;
end;

function TOpenSSLConnection.SendQueuedEarlyData: Boolean;
var
  LRet, LErr: Integer;
  LWritten, LRemaining, LOffset: NativeUInt;
begin
  Result := True;

  if (FEarlyDataStatus <> sslEarlyDataQueued) or (Length(FEarlyDataPayload) = 0) then
    Exit;

  if (FSSL = nil) or (not Assigned(SSL_write_early_data)) or
    (not Assigned(SSL_get_error)) then
    Exit(False);

  if Assigned(SSL_set_connect_state) then
    SSL_set_connect_state(FSSL);

  LOffset := 0;
  while LOffset < NativeUInt(Length(FEarlyDataPayload)) do
  begin
    LWritten := 0;
    LRemaining := NativeUInt(Length(FEarlyDataPayload)) - LOffset;
    LRet := SSL_write_early_data(FSSL, @FEarlyDataPayload[LOffset],
      LRemaining, @LWritten);
    if LRet = 1 then
    begin
      Inc(LOffset, LWritten);
      if HasStreamTransport then
        PumpBIOToStream;
      Continue;
    end;

    LErr := SSL_get_error(FSSL, LRet);
    FLastSSLError := LErr;
    case LErr of
      SSL_ERROR_WANT_READ:
        begin
          if HasStreamTransport then
          begin
            PumpBIOToStream;
            if PumpStreamToBIO <= 0 then
              Exit(False);
          end
          else
            Exit(False);
        end;
      SSL_ERROR_WANT_WRITE:
        begin
          if HasStreamTransport then
          begin
            if PumpBIOToStream <= 0 then
              Exit(False);
          end
          else
            Exit(False);
        end;
      SSL_ERROR_ZERO_RETURN:
        begin
          if HasStreamTransport then
            PumpBIOToStream;
          Exit(False);
        end;
    else
      if HasStreamTransport then
        PumpBIOToStream;
      Exit(False);
    end;
  end;
end;

{ 抽象方法实现 }

function TOpenSSLConnection.DoRead(var ABuffer; ACount: Integer): Integer;
var
  LRet, LErr: Integer;
begin
  Result := -1;
  if FSSL = nil then Exit;

  // Stream-based blocking read using BIO <-> IStream bridge
  if HasStreamTransport then
  begin
    // Ensure handshake completed
    if not FConnected then
    begin
      if (FContext <> nil) and
        ContextTypeRequiresExplicitHandshakeRole(FContext.GetContextType) then
      begin
        RecordError(
          sslErrConfiguration,
          RolelessHandshakeAmbiguityMessage('TLS read')
        );
        Exit;
      end;

      if not InternalHandshake(FContext.GetContextType = sslCtxClient) then
        Exit;
    end;

    if not Assigned(SSL_read) then
      Exit;

    while True do
    begin
      LRet := SSL_read(FSSL, @ABuffer, ACount);
      if LRet > 0 then
      begin
        Result := LRet;
        Exit;
      end;

      if not Assigned(SSL_get_error) then
      begin
        Result := -1;
        Exit;
      end;

      LErr := SSL_get_error(FSSL, LRet);
      FLastSSLError := LErr;
      case LErr of
        SSL_ERROR_WANT_READ:
          begin
            PumpBIOToStream;
            if PumpStreamToBIO <= 0 then
            begin
              Result := -1;
              Exit;
            end;
          end;
        SSL_ERROR_WANT_WRITE:
          begin
            if PumpBIOToStream <= 0 then
            begin
              Result := -1;
              Exit;
            end;
          end;
        SSL_ERROR_ZERO_RETURN:
          begin
            // Clean shutdown from peer
            PumpBIOToStream;
            Result := 0;
            Exit;
          end;
      else
        Result := -1;
        Exit;
      end;
    end;
  end
  else
  begin
    if not FConnected then Exit(-1);
    if not Assigned(SSL_read) then Exit(-1);
    Result := SSL_read(FSSL, @ABuffer, ACount);
    if (Result < 0) and Assigned(SSL_get_error) then
      FLastSSLError := SSL_get_error(FSSL, Result);
  end;
end;

function TOpenSSLConnection.DoWrite(const ABuffer; ACount: Integer): Integer;
var
  LRet, LErr: Integer;
begin
  Result := -1;
  if FSSL = nil then Exit;

  // Stream-based blocking write using BIO <-> IStream bridge
  if HasStreamTransport then
  begin
    // Ensure handshake completed
    if not FConnected then
    begin
      if (FContext <> nil) and
        ContextTypeRequiresExplicitHandshakeRole(FContext.GetContextType) then
      begin
        RecordError(
          sslErrConfiguration,
          RolelessHandshakeAmbiguityMessage('TLS write')
        );
        Exit;
      end;

      if not InternalHandshake(FContext.GetContextType = sslCtxClient) then
        Exit;
    end;

    if not Assigned(SSL_write) then
      Exit;

    while True do
    begin
      LRet := SSL_write(FSSL, @ABuffer, ACount);
      if LRet > 0 then
      begin
        // Flush any pending encrypted data to the underlying stream
        PumpBIOToStream;
        Result := LRet;
        Exit;
      end;

      if not Assigned(SSL_get_error) then
      begin
        Result := -1;
        Exit;
      end;

      LErr := SSL_get_error(FSSL, LRet);
      FLastSSLError := LErr;
      case LErr of
        SSL_ERROR_WANT_READ:
          begin
            // Peer expects us to read more encrypted data before continuing
            PumpBIOToStream;
            if PumpStreamToBIO <= 0 then
            begin
              Result := -1;
              Exit;
            end;
          end;
        SSL_ERROR_WANT_WRITE:
          begin
            if PumpBIOToStream <= 0 then
            begin
              Result := -1;
              Exit;
            end;
          end;
        SSL_ERROR_ZERO_RETURN:
          begin
            PumpBIOToStream;
            Result := 0;
            Exit;
          end;
      else
        Result := -1;
        Exit;
      end;
    end;
  end
  else
  begin
    if not FConnected then Exit(-1);
    if not Assigned(SSL_write) then Exit(-1);
    Result := SSL_write(FSSL, @ABuffer, ACount);
    if (Result < 0) and Assigned(SSL_get_error) then
      FLastSSLError := SSL_get_error(FSSL, Result);
  end;
end;

function TOpenSSLConnection.DoConnect: Boolean;
var
  Ret: Integer;
begin
  if FSSL = nil then Exit(False);

  ApplyPreHandshakeOCSPStatusRequest(True);

  // For stream-based transport, run an internal blocking handshake
  if HasStreamTransport then
  begin
    if not SendQueuedEarlyData then
      Exit(False);
    Result := InternalHandshake(True);
    if Result then
      UpdateEarlyDataStatusFromNative;
    Exit;
  end;

  if not Assigned(SSL_connect) then
    Exit(False);

  if not SendQueuedEarlyData then
    Exit(False);

  Ret := SSL_connect(FSSL);
  FConnected := (Ret = 1);
  if FConnected then
  begin
    // Strategy A: fail closed if validation fails
    if not ValidatePostHandshake(True) then
    begin
      FConnected := False;
      Result := False;
      Exit;
    end;
    UpdateEarlyDataStatusFromNative;
  end
  else if Assigned(SSL_get_error) then
    FLastSSLError := SSL_get_error(FSSL, Ret);
  Result := FConnected;
end;

function TOpenSSLConnection.DoAccept: Boolean;
var
  Ret: Integer;
begin
  if FSSL = nil then Exit(False);

  // For stream-based transport, run an internal blocking handshake
  if HasStreamTransport then
  begin
    Result := InternalHandshake(False);
    Exit;
  end;

  if not Assigned(SSL_accept) then
    Exit(False);

  Ret := SSL_accept(FSSL);
  FConnected := (Ret = 1);
  if FConnected then
  begin
    // Strategy A: fail closed if validation fails
    if not ValidatePostHandshake(False) then
    begin
      FConnected := False;
      Result := False;
      Exit;
    end;
  end
  else if Assigned(SSL_get_error) then
    FLastSSLError := SSL_get_error(FSSL, Ret);
  Result := FConnected;
end;

function TOpenSSLConnection.DoHandshakeInternal: TSSLHandshakeState;
begin
  if FHandshakeComplete then
    Result := sslHsCompleted
  else if FContext.GetContextType = sslCtxClient then
  begin
    if DoConnect then
      Result := sslHsCompleted
    else if DoWantRead or DoWantWrite then
      Result := sslHsInProgress
    else
      Result := sslHsFailed;
  end
  else
  begin
    if DoAccept then
      Result := sslHsCompleted
    else if DoWantRead or DoWantWrite then
      Result := sslHsInProgress
    else
      Result := sslHsFailed;
  end;
end;

function TOpenSSLConnection.DoHandshake: TSSLHandshakeState;
var
  LRole: string;
begin
  if (FContext <> nil) and
    ContextTypeRequiresExplicitHandshakeRole(FContext.GetContextType) then
    LRole := 'Dual'
  else if (FContext <> nil) and (FContext.GetContextType = sslCtxClient) then
    LRole := 'Client'
  else
    LRole := 'Server';

  TSecurityLog.Info('OpenSSL', nextpas.core.text.conv.Format('Starting handshake (%s)', [LRole]));

  Result := inherited DoHandshake;

  if Result = sslHsCompleted then
    TSecurityLog.Info('OpenSSL', nextpas.core.text.conv.Format('Handshake completed (%s). Cipher: %s', [LRole, GetCipherName]))
  else if Result = sslHsFailed then
    TSecurityLog.Error('OpenSSL', nextpas.core.text.conv.Format('Handshake failed (%s)', [LRole]));
end;

function TOpenSSLConnection.DoShutdown: Boolean;
begin
  if (FSSL <> nil) and Assigned(SSL_shutdown) then
    SSL_shutdown(FSSL);
  FConnected := False;
  Result := True;
end;

procedure TOpenSSLConnection.DoClose;
begin
  DoShutdown;
end;

function TOpenSSLConnection.DoRenegotiate: Boolean;
var
  Ret: Integer;
begin
  Result := False;

  if (FSSL = nil) or not FConnected then
    Exit;

  if not Assigned(SSL_renegotiate) then
    Exit;

  // 发起重协商
  Ret := SSL_renegotiate(FSSL);
  if Ret <> 1 then
    Exit;

  // 执行握手以完成重协商
  if not Assigned(SSL_do_handshake) then
    Exit;

  Ret := SSL_do_handshake(FSSL);
  Result := (Ret = 1);
end;

function TOpenSSLConnection.DoGetError(ARet: Integer): TSSLErrorCode;
var
  Err: Integer;
begin
  if FSSL = nil then
  begin
    Result := sslErrNone;
    Exit;
  end;

  // 与 WinSSL 路径保持一致：非负返回值一律视为无错误
  if ARet >= 0 then
  begin
    Result := sslErrNone;
    Exit;
  end;

  if not Assigned(SSL_get_error) then
  begin
    Result := sslErrOther;
    Exit;
  end;

  Err := SSL_get_error(FSSL, ARet);
  case Err of
    SSL_ERROR_NONE: Result := sslErrNone;
    SSL_ERROR_WANT_READ: Result := sslErrWantRead;
    SSL_ERROR_WANT_WRITE: Result := sslErrWantWrite;
  else
    Result := sslErrOther;
  end;
end;

function TOpenSSLConnection.DoWantRead: Boolean;
begin
  Result := FLastSSLError = SSL_ERROR_WANT_READ;
end;

function TOpenSSLConnection.DoWantWrite: Boolean;
begin
  Result := FLastSSLError = SSL_ERROR_WANT_WRITE;
end;

function TOpenSSLConnection.DoGetProtocolVersion: TSSLProtocolVersion;
var
  Ver: Integer;
begin
  Result := sslProtocolTLS12;
  if (FSSL = nil) or (not Assigned(SSL_version)) then Exit;

  Ver := SSL_version(FSSL);
  case Ver of
    SSL2_VERSION: Result := sslProtocolSSL2;
    SSL3_VERSION: Result := sslProtocolSSL3;
    TLS1_VERSION: Result := sslProtocolTLS10;
    TLS1_1_VERSION: Result := sslProtocolTLS11;
    TLS1_2_VERSION: Result := sslProtocolTLS12;
    TLS1_3_VERSION: Result := sslProtocolTLS13;
  else
    Result := sslProtocolTLS12;  // 未知版本时使用安全默认值
  end;
end;

function TOpenSSLConnection.DoGetCipherName: string;
var
  Cipher: PSSL_CIPHER;
  Name: PAnsiChar;
begin
  Result := '';
  if (FSSL = nil) or (not Assigned(SSL_get_current_cipher)) then Exit;

  Cipher := SSL_get_current_cipher(FSSL);
  if Cipher <> nil then
  begin
    if not Assigned(SSL_CIPHER_get_name) then
      Exit;
    Name := SSL_CIPHER_get_name(Cipher);
    if Name <> nil then
      Result := string(Name);
  end;
end;

function TOpenSSLConnection.CreateCertificateFromOwnedRef(AX509: PX509): ISSLCertificate;
begin
  Result := nil;
  if AX509 = nil then
    Exit;

  Result := TOpenSSLCertificate.Create(AX509, True);
end;

function TOpenSSLConnection.CreateRetainedCertificate(AX509: PX509): ISSLCertificate;
begin
  Result := nil;
  if (AX509 = nil) or (not Assigned(X509_up_ref)) then
    Exit;

  X509_up_ref(AX509);
  try
    Result := CreateCertificateFromOwnedRef(AX509);
  except
    if Assigned(X509_free) then
      X509_free(AX509);
    raise;
  end;
end;

function TOpenSSLConnection.FindRetainedPeerIssuerCertificate(APeerX509: PX509): ISSLCertificate;
var
  PeerChain: PSTACK_OF_X509;
  VerifiedChain: PSTACK_OF_X509;
  IssuerX509: PX509;
begin
  Result := nil;
  if (FSSL = nil) or (APeerX509 = nil) then
    Exit;

  IssuerX509 := nil;
  PeerChain := nil;
  if Assigned(SSL_get_peer_cert_chain) then
    PeerChain := SSL_get_peer_cert_chain(FSSL);

  if PeerChain <> nil then
    IssuerX509 := FindIssuerX509InChain(APeerX509, PeerChain);

  if (IssuerX509 = nil) and Assigned(SSL_get0_verified_chain) then
  begin
    VerifiedChain := SSL_get0_verified_chain(FSSL);
    if VerifiedChain <> nil then
      IssuerX509 := FindIssuerX509InChain(APeerX509, VerifiedChain);
  end;

  Result := CreateRetainedCertificate(IssuerX509);
end;

procedure TOpenSSLConnection.LinkPeerCertificateChainIssuerLinks(
  const AChain: PSTACK_OF_X509;
  const ACertificates: TSSLCertificateArray
);
var
  Count: Integer;
  I: Integer;
  J: Integer;
  LeafX509: PX509;
  IssuerX509: PX509;
begin
  if (AChain = nil) or (Length(ACertificates) = 0) or
     (not Assigned(sk_X509_num)) or (not Assigned(sk_X509_value)) then
    Exit;

  Count := sk_X509_num(AChain);
  if Count <= 0 then
    Exit;

  for I := 0 to Count - 1 do
  begin
    if (I > High(ACertificates)) or (ACertificates[I] = nil) then
      Continue;

    ACertificates[I].SetIssuerCertificate(nil);
    LeafX509 := sk_X509_value(AChain, I);
    if LeafX509 = nil then
      Continue;

    IssuerX509 := FindIssuerX509InChain(LeafX509, AChain);
    if IssuerX509 = nil then
      Continue;

    for J := 0 to Count - 1 do
      if (J <= High(ACertificates)) and (sk_X509_value(AChain, J) = IssuerX509) then
      begin
        ACertificates[I].SetIssuerCertificate(ACertificates[J]);
        Break;
      end;
  end;
end;

function TOpenSSLConnection.DoGetPeerCertificate: ISSLCertificate;
var
  X509Cert: PX509;
  IssuerCert: ISSLCertificate;
begin
  Result := nil;

  if (FSSL = nil) or (not Assigned(SSL_get_peer_certificate)) then
    Exit;

  X509Cert := SSL_get_peer_certificate(FSSL);
  if X509Cert = nil then
    Exit;

  // 创建证书对象（SSL_get_peer_certificate已增加引用计数）
  Result := CreateCertificateFromOwnedRef(X509Cert);
  if Result = nil then
    Exit;

  IssuerCert := FindRetainedPeerIssuerCertificate(X509Cert);
  if IssuerCert <> nil then
    Result.SetIssuerCertificate(IssuerCert);
end;

function TOpenSSLConnection.DoGetPeerCertificateChain: TSSLCertificateArray;
var
  Chain: PSTACK_OF_X509;
  Count, I: Integer;
  X509Cert: PX509;
begin
  SetLength(Result, 0);

  if (FSSL = nil) or
    (not Assigned(SSL_get_peer_cert_chain)) or
    (not Assigned(sk_X509_num)) or
    (not Assigned(sk_X509_value)) or
    (not Assigned(X509_up_ref)) then
    Exit;

  Chain := SSL_get_peer_cert_chain(FSSL);
  if Chain = nil then
    Exit;

  Count := sk_X509_num(Chain);
  if Count <= 0 then
    Exit;

  SetLength(Result, Count);
  for I := 0 to Count - 1 do
  begin
    X509Cert := sk_X509_value(Chain, I);
    if X509Cert <> nil then
      Result[I] := CreateRetainedCertificate(X509Cert);
  end;

  LinkPeerCertificateChainIssuerLinks(Chain, Result);
end;

function TOpenSSLConnection.DoGetVerifyResult: Integer;
begin
  if not FHandshakeComplete then
    Exit(-1);

  if (FSSL = nil) or (not Assigned(SSL_get_verify_result)) then Exit(-1);
  Result := SSL_get_verify_result(FSSL);
end;

function TOpenSSLConnection.DoGetVerifyResultString: string;
var
  Res: Integer;
  ErrStr: PAnsiChar;
begin
  if not FHandshakeComplete then
  begin
    Result := 'Not verified';
    Exit;
  end;

  Res := DoGetVerifyResult;
  if Res = X509_V_OK then
  begin
    Result := 'OK';
    Exit;
  end;

  if Res < 0 then
  begin
    Result := nextpas.core.text.conv.Format('Error: %d', [Res]);
    Exit;
  end;

  ErrStr := nil;
  if Assigned(X509_verify_cert_error_string) then
    ErrStr := X509_verify_cert_error_string(Res);

  if ErrStr <> nil then
    Result := string(ErrStr)
  else
    Result := nextpas.core.text.conv.Format('Error: %d', [Res]);
end;

function TOpenSSLConnection.DoGetSession: ISSLSession;
var
  Sess: PSSL_SESSION;
begin
  Result := nil;

  if FSSL = nil then
    Exit;

  if not Assigned(SSL_get1_session) then
    Exit;

  // 使用 SSL_get1_session（增加引用计数）
  Sess := SSL_get1_session(FSSL);
  if Sess = nil then
    Exit;

  Result := TOpenSSLSession.Create(Sess, True);
end;

procedure TOpenSSLConnection.DoSetSession(ASession: ISSLSession);
var
  Sess: PSSL_SESSION;
begin
  FConfiguredSession := ASession;
  FEarlyDataLimit := 0;

  if (FSSL = nil) or (ASession = nil) then
    Exit;

  if not Assigned(SSL_set_session) then
    Exit;

  // 使用 TryGetNativeHandle 因为会话可能不支持原生句柄
  if not TryGetNativeHandle(ASession, Pointer(Sess)) then
    Exit;

  if SSL_set_session(FSSL, Sess) = 1 then
    FEarlyDataLimit := ResolveEarlyDataLimitFromSession(ASession);
end;

function TOpenSSLConnection.SetEarlyData(
  const AData: TBytes): TSSLOperationResult;
var
  LEarlyDataContext: ISSLEarlyDataContext;
begin
  if (FContext = nil) or
    (not ContextTypeSupportsClientConnectionRole(FContext.GetContextType)) then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam,
      'Early data is only available on client connections'));

  if not Supports(FContext, ISSLEarlyDataContext, LEarlyDataContext) then
    Exit(TSSLOperationResult.Err(sslErrUnsupported,
      'Context does not expose early-data interface'));

  if not LEarlyDataContext.GetClientEarlyDataEnabled then
    Exit(TSSLOperationResult.Err(sslErrConfiguration,
      'Client early data is disabled on the context'));

  if (FConfiguredSession = nil) or (not FConfiguredSession.IsValid) or
    (not FConfiguredSession.IsResumable) then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam,
      'Early data requires a configured resumable session'));

  FEarlyDataLimit := ResolveEarlyDataLimitFromSession(FConfiguredSession);
  if FEarlyDataLimit = 0 then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam,
      'Configured session does not allow early data'));

  if Cardinal(Length(AData)) > FEarlyDataLimit then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam,
      'Early data payload exceeds max_early_data_size'));

  FEarlyDataPayload := Copy(AData, 0, Length(AData));
  if Length(FEarlyDataPayload) = 0 then
    FEarlyDataStatus := sslEarlyDataNone
  else
    FEarlyDataStatus := sslEarlyDataQueued;
  Result := TSSLOperationResult.Ok;
end;

function TOpenSSLConnection.GetEarlyDataStatus: TSSLEarlyDataStatus;
begin
  if FHandshakeComplete or FConnected then
    UpdateEarlyDataStatusFromNative;
  Result := FEarlyDataStatus;
end;

function TOpenSSLConnection.GetEarlyDataLimit: Cardinal;
begin
  Result := FEarlyDataLimit;
end;

function TOpenSSLConnection.DoIsSessionReused: Boolean;
begin
  if (FSSL = nil) or (not Assigned(SSL_session_reused)) then Exit(False);
  Result := (SSL_session_reused(FSSL) = 1);
end;

function TOpenSSLConnection.DoGetConnectionInfoServerName: string;
begin
  Result := FServerName;
end;

function TOpenSSLConnection.DoGetSelectedALPNProtocol: string;
var
  Data: PByte;
  Len: Cardinal;
begin
  Result := '';
  if (FSSL = nil) or not Assigned(SSL_get0_alpn_selected) then Exit;

  SSL_get0_alpn_selected(FSSL, @Data, @Len);
  if (Data <> nil) and (Len > 0) then
    SetString(Result, PAnsiChar(Data), Len);
end;

function TOpenSSLConnection.DoGetState: string;
begin
  if FSSL = nil then
    Exit('not_initialized');
  if not Assigned(SSL_state_string) then
    Exit('unknown');
  Result := string(SSL_state_string(FSSL));
end;

function TOpenSSLConnection.DoGetNativeHandle: Pointer;
begin
  Result := FSSL;
end;

{ ISSLNativeHandleAccess 实现 }

function TOpenSSLConnection.GetNativeHandle: Pointer;
begin
  Result := FSSL;
end;

function TOpenSSLConnection.GetBackendType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TOpenSSLConnection.IsNativeHandleValid: Boolean;
begin
  Result := (FSSL <> nil);
end;

{ OCSP 方法覆盖 }

function TOpenSSLConnection.DoGetOCSPStaplingEnabled: Boolean;
var
  RespLen: clong;
  RespPtr: PByte;
begin
  Result := False;
  if (FSSL = nil) or (not Assigned(SSL_get_tlsext_status_ocsp_resp)) then
    Exit;
  RespPtr := nil;
  RespLen := SSL_get_tlsext_status_ocsp_resp(FSSL, @RespPtr);
  Result := (RespLen > 0) and (RespPtr <> nil);
end;

function TOpenSSLConnection.DoGetOCSPResponse: TBytes;
var
  RespLen: clong;
  RespPtr: PByte;
begin
  SetLength(Result, 0);
  if (FSSL = nil) or (not Assigned(SSL_get_tlsext_status_ocsp_resp)) then
    Exit;

  RespPtr := nil;
  RespLen := SSL_get_tlsext_status_ocsp_resp(FSSL, @RespPtr);

  if (RespLen > 0) and (RespPtr <> nil) then
  begin
    SetLength(Result, RespLen);
    Move(RespPtr^, Result[0], RespLen);
  end;
end;

function TOpenSSLConnection.DoIsOCSPResponseVerified: Boolean;
var
  RespData: TBytes;
  OCSPResp: POCSP_RESPONSE;
  DataPtr: PByte;
  PeerCert: ISSLCertificate;
  PeerX509: PX509;
  IssuerX509: PX509;
  IssuerNeedsFree: Boolean;
  VerifyStore: PX509_STORE;
  PeerChain: PSTACK_OF_X509;
  StoreCtx: PX509_STORE_CTX;
  VerifiedChain: PSTACK_OF_X509;
begin
  Result := False;

  if (FSSL = nil) or (FContext = nil) then
    Exit;

  // 获取 stapled OCSP 响应
  RespData := DoGetOCSPResponse;
  if Length(RespData) = 0 then
    Exit;

  // Ensure OCSP APIs are available
  if not TOpenSSLLoader.IsModuleLoaded(osmOCSP) then
    LoadOpenSSLOCSP(GetCryptoLibHandle);

  if (not TOpenSSLLoader.IsModuleLoaded(osmOCSP)) or (not Assigned(d2i_OCSP_RESPONSE)) then
    Exit;

  DataPtr := @RespData[0];
  OCSPResp := d2i_OCSP_RESPONSE(nil, @DataPtr, Length(RespData));
  if OCSPResp = nil then
    Exit;

  IssuerX509 := nil;
  IssuerNeedsFree := False;

  try
    // 获取对端证书（需要用于响应验证）
    PeerCert := DoGetPeerCertificate;
    if PeerCert = nil then
      Exit;

    if not TryGetNativeHandle(PeerCert, Pointer(PeerX509)) then
      Exit;

    if PeerX509 = nil then
      Exit;

    // Try to obtain issuer cert from peer chain first
    PeerChain := nil;
    if Assigned(SSL_get_peer_cert_chain) then
      PeerChain := SSL_get_peer_cert_chain(FSSL);

    if PeerChain <> nil then
      IssuerX509 := FindIssuerX509InChain(PeerX509, PeerChain);

    // Prefer verified chain from handshake when available (avoids re-running X509_verify_cert)
    if (IssuerX509 = nil) and Assigned(SSL_get0_verified_chain) then
    begin
      VerifiedChain := SSL_get0_verified_chain(FSSL);
      if VerifiedChain <> nil then
        IssuerX509 := FindIssuerX509InChain(PeerX509, VerifiedChain);
    end;

    // Retrieve verify store from context
    VerifyStore := nil;
    if Assigned(SSL_CTX_get_cert_store) then
      VerifyStore := SSL_CTX_get_cert_store(
        PSSL_CTX(GetNativeHandleSafe(FContext, 'TOpenSSLConnection.DoIsOCSPResponseVerified')));

    // Fall back to verified chain building if issuer not found
    if (IssuerX509 = nil) and (VerifyStore <> nil) and
      Assigned(X509_STORE_CTX_new) and Assigned(X509_STORE_CTX_free) and
      Assigned(X509_STORE_CTX_init) and Assigned(X509_verify_cert) and
      Assigned(X509_STORE_CTX_get0_chain) then
    begin
      StoreCtx := X509_STORE_CTX_new();
      if StoreCtx <> nil then
      try
        PeerChain := nil;
        if Assigned(SSL_get_peer_cert_chain) then
          PeerChain := SSL_get_peer_cert_chain(FSSL);

        if X509_STORE_CTX_init(StoreCtx, VerifyStore, PeerX509, PeerChain) = 1 then
        begin
            if X509_verify_cert(StoreCtx) = 1 then
            begin
              VerifiedChain := X509_STORE_CTX_get0_chain(StoreCtx);
              if VerifiedChain <> nil then
              begin
                IssuerX509 := FindIssuerX509InChain(PeerX509, VerifiedChain);
                if IssuerX509 <> nil then
                begin
                  if not Assigned(X509_up_ref) then
                  begin
                    IssuerX509 := nil;
                    Exit(False);
                  end;

                  X509_up_ref(IssuerX509);
                  IssuerNeedsFree := True;
                end;
              end;
            end;
        end;
      finally
        X509_STORE_CTX_free(StoreCtx);
      end;
    end;

    // Use shared OCSP verification helper (signature + chain validation)
    Result := VerifyOCSPResponse(OCSPResp, PeerX509, IssuerX509, VerifyStore, nil);

  finally
    if IssuerNeedsFree and (IssuerX509 <> nil) and Assigned(X509_free) then
      X509_free(IssuerX509);

    if Assigned(OCSP_RESPONSE_free) then
      OCSP_RESPONSE_free(OCSPResp);
  end;
end;

function TOpenSSLConnection.DoGetOCSPResponseStatus: string;
var
  RespData: TBytes;
  OCSPResp: POCSP_RESPONSE;
  RespStatus: Integer;
  DataPtr: PByte;
begin
  Result := 'No OCSP Response';

  // 获取 OCSP 响应
  RespData := DoGetOCSPResponse;
  if Length(RespData) = 0 then Exit;

  // Ensure OCSP APIs are available
  if not TOpenSSLLoader.IsModuleLoaded(osmOCSP) then
    LoadOpenSSLOCSP(GetCryptoLibHandle);

  // 解析 OCSP 响应
  if not Assigned(d2i_OCSP_RESPONSE) then
  begin
    Result := 'OCSP API not available';
    Exit;
  end;

  if not Assigned(OCSP_RESPONSE_status) then
  begin
    Result := 'OCSP status API not available';
    Exit;
  end;

  DataPtr := @RespData[0];
  OCSPResp := d2i_OCSP_RESPONSE(nil, @DataPtr, Length(RespData));
  if OCSPResp = nil then
  begin
    Result := 'Failed to parse OCSP response';
    Exit;
  end;

  try
    RespStatus := OCSP_RESPONSE_status(OCSPResp);
    case RespStatus of
      OCSP_RESPONSE_STATUS_SUCCESSFUL:       Result := 'Successful';
      OCSP_RESPONSE_STATUS_MALFORMEDREQUEST: Result := 'Malformed Request';
      OCSP_RESPONSE_STATUS_INTERNALERROR:    Result := 'Internal Error';
      OCSP_RESPONSE_STATUS_TRYLATER:         Result := 'Try Later';
      OCSP_RESPONSE_STATUS_SIGREQUIRED:      Result := 'Signature Required';
      OCSP_RESPONSE_STATUS_UNAUTHORIZED:     Result := 'Unauthorized';
    else
      Result := nextpas.core.text.conv.Format('Unknown Status (%d)', [RespStatus]);
    end;
  finally
    if Assigned(OCSP_RESPONSE_free) then
      OCSP_RESPONSE_free(OCSPResp);
  end;
end;

{ 覆盖基类方法 }

function TOpenSSLConnection.GetConnectionInfo: TSSLConnectionInfo;
var
  Cipher: PSSL_CIPHER;
  CipherName: PAnsiChar;
  AlgBits: Integer;
  ServerNamePtr: PAnsiChar;
  CipherId: UInt32;
  DigestMd: PEVP_MD;
  DigestNid: Integer;
begin
  // 调用基类获取基本信息
  Result := inherited GetConnectionInfo;

  if FSSL = nil then
    Exit;

  // Cipher suite information
  if Assigned(SSL_get_current_cipher) then
  begin
    Cipher := SSL_get_current_cipher(FSSL);
    if Cipher <> nil then
    begin
      // Cipher suite name
      if Assigned(SSL_CIPHER_get_name) then
      begin
        CipherName := SSL_CIPHER_get_name(Cipher);
        if CipherName <> nil then
          Result.CipherSuite := string(CipherName);
      end;

      // Key size
      if Assigned(SSL_CIPHER_get_bits) then
      begin
        AlgBits := 0;
        Result.KeySize := SSL_CIPHER_get_bits(Cipher, @AlgBits);
      end;

      if Assigned(SSL_CIPHER_get_protocol_id) then
        Result.CipherSuiteId := SSL_CIPHER_get_protocol_id(Cipher)
      else if Assigned(SSL_CIPHER_get_id) then
      begin
        CipherId := SSL_CIPHER_get_id(Cipher);
        Result.CipherSuiteId := Word(CipherId and $FFFF);
      end;

      if (Result.MacSize = 0) and
         Assigned(SSL_CIPHER_is_aead) and
         (SSL_CIPHER_is_aead(Cipher) = 0) and
         Assigned(SSL_CIPHER_get_digest_nid) and
         Assigned(EVP_get_digestbynid) then
      begin
        DigestNid := SSL_CIPHER_get_digest_nid(Cipher);
        if DigestNid > 0 then
        begin
          DigestMd := EVP_get_digestbynid(DigestNid);
          if DigestMd <> nil then
          begin
            Result.MacSize := EVP_MD_size(DigestMd);
            if Result.MacSize < 0 then
              Result.MacSize := 0;
          end;
        end;
      end;
    end;
  end;

  // Server name (SNI)
  if Assigned(SSL_get_servername) then
  begin
    ServerNamePtr := SSL_get_servername(FSSL, TLSEXT_NAMETYPE_host_name);
    if ServerNamePtr <> nil then
      Result.ServerName := string(ServerNamePtr);
  end;
end;

function TOpenSSLConnection.GetStateString: string;
begin
  if FSSL = nil then
    Exit('Not initialized');
  if not Assigned(SSL_state_string_long) then
    Exit('Unknown state');
  Result := string(SSL_state_string_long(FSSL));
end;

{ 私有辅助方法 }

function TOpenSSLConnection.HasStreamTransport: Boolean;
begin
  Result := (FStream <> nil) and (FSocket = THandle(-1));
end;

function TOpenSSLConnection.PumpStreamToBIO: Integer;
var
  LBuffer: array[0..SSL_IO_BUFFER_SIZE - 1] of Byte;
  LRead, LOffset, LWritten: Integer;
begin
  Result := 0;

  if (not HasStreamTransport) or (FBioRead = nil) or
    (not Assigned(BIO_write)) or (FStream = nil) then
    Exit;

  // Blocking read from underlying stream (encrypted data from peer)
  LRead := FStream.Read(LBuffer[0], SSL_IO_BUFFER_SIZE);
  if LRead <= 0 then
    Exit;

  LOffset := 0;
  while LOffset < LRead do
  begin
    LWritten := BIO_write(FBioRead, @LBuffer[LOffset], LRead - LOffset);
    if LWritten <= 0 then
      Break;
    Inc(LOffset, LWritten);
  end;

  Result := LOffset;
end;

function TOpenSSLConnection.PumpBIOToStream: Integer;
var
  LBuffer: array[0..SSL_IO_BUFFER_SIZE - 1] of Byte;
  LPending, LToRead, LRead: Integer;
begin
  Result := 0;

  if (not HasStreamTransport) or (FBioWrite = nil) or
    (not Assigned(BIO_pending)) or (not Assigned(BIO_read)) or
    (FStream = nil) then
    Exit;

  // Drain all pending encrypted data from SSL's write BIO to the underlying stream
  while True do
  begin
    LPending := BIO_pending(FBioWrite);
    if LPending <= 0 then
      Break;

    if LPending > SSL_IO_BUFFER_SIZE then
      LToRead := SSL_IO_BUFFER_SIZE
    else
      LToRead := LPending;

    LRead := BIO_read(FBioWrite, @LBuffer[0], LToRead);
    if LRead <= 0 then
      Break;

    IoWriteAll(FStream, LBuffer[0], SizeUInt(LRead));
    Inc(Result, LRead);
  end;
end;

procedure TOpenSSLConnection.ApplyPreHandshakeOCSPStatusRequest(AIsClient: Boolean);
var
  Options: TSSLOptions;
  StatusType: Integer;
  LServerStaplingContext: ISSLServerOCSPStaplingContext;
begin
  if (FSSL = nil) or (FContext = nil) then
    Exit;

  if not Assigned(SSL_set_tlsext_status_type) then
    Exit;

  if AIsClient then
  begin
    Options := FContext.GetOptions;
    if ssoEnableOCSPStapling in Options then
      StatusType := TLSEXT_STATUSTYPE_ocsp
    else
      StatusType := 0;
  end
  else if Supports(FContext, ISSLServerOCSPStaplingContext, LServerStaplingContext) and
          LServerStaplingContext.HasServerStapledOCSPResponse then
    StatusType := TLSEXT_STATUSTYPE_ocsp
  else
    StatusType := 0;

  SSL_set_tlsext_status_type(FSSL, StatusType);
end;

function TOpenSSLConnection.InternalHandshake(AIsClient: Boolean): Boolean;
var
  LRet, LErr: Integer;
begin
  Result := False;

  if (FSSL = nil) or (not HasStreamTransport) then
    Exit;

  if Assigned(ERR_clear_error) then ERR_clear_error();

  if (not Assigned(SSL_do_handshake)) or (not Assigned(SSL_get_error)) then
    Exit;

  ApplyPreHandshakeOCSPStatusRequest(AIsClient);

  // Set initial handshake state explicitly for stream-based connections
  if AIsClient then
  begin
    if Assigned(SSL_set_connect_state) then
      SSL_set_connect_state(FSSL);
  end
  else
  begin
    if Assigned(SSL_set_accept_state) then
      SSL_set_accept_state(FSSL);
  end;

  while True do
  begin
    LRet := SSL_do_handshake(FSSL);
    if LRet = 1 then
    begin
      FConnected := True;
      // Flush any handshake data still buffered
      PumpBIOToStream;

      // Strategy A: fail closed if validation fails
      if not ValidatePostHandshake(AIsClient) then
      begin
        FConnected := False;
        Result := False;
        Exit;
      end;

      Result := True;
      Exit;
    end;

    LErr := SSL_get_error(FSSL, LRet);
    FLastSSLError := LErr;
    case LErr of
      SSL_ERROR_WANT_READ:
        begin
          PumpBIOToStream;
          if PumpStreamToBIO <= 0 then
            Exit(False);
        end;
      SSL_ERROR_WANT_WRITE:
        begin
          if PumpBIOToStream <= 0 then
            Exit(False);
        end;
      SSL_ERROR_ZERO_RETURN:
        begin
          PumpBIOToStream;
          Exit(False);
        end;
    else
      PumpBIOToStream;
      Exit(False);
    end;
  end;
end;

function TOpenSSLConnection.ValidateRequiredOCSPStapling(AIsClient: Boolean): Boolean;
var
  Options: TSSLOptions;
  Resp: TBytes;
begin
  Result := True;

  if (not AIsClient) or (FSSL = nil) or (FContext = nil) then
    Exit;

  Options := FContext.GetOptions;
  if not (ssoRequireOCSPStapling in Options) then
    Exit;

  Resp := DoGetOCSPResponse;
  if Length(Resp) = 0 then
  begin
    if Assigned(SSL_set_verify_result) then
      SSL_set_verify_result(FSSL, X509_V_ERR_OCSP_VERIFY_NEEDED);
    Exit(False);
  end;

  if not DoIsOCSPResponseVerified then
  begin
    if Assigned(SSL_set_verify_result) then
      SSL_set_verify_result(FSSL, X509_V_ERR_OCSP_VERIFY_FAILED);
    Exit(False);
  end;
end;

function TOpenSSLConnection.ValidatePostHandshake(AIsClient: Boolean): Boolean;
var
  VerifyModes: TSSLVerifyModes;
  VerifyFlags: TSSLCertVerifyFlags;
  ConnectionOptions: TSSLOptions;
  CertVerifyCacheEnabled: Boolean;
  CertVerifyCache: TCertVerifyCache;
  CachedVerifyResult: TCertVerifyResult;
  PerformVerifyCall: Boolean;
  RequirePeerCert: Boolean;
  PeerCert: ISSLCertificate;
  PeerX509: PX509;
  VerifyRes: Integer;
  Host: string;
  HostNormalized: string;
  HostA: AnsiString;
  IsIP: Boolean;
  OCSPUrl: string;
  IssuerX509: PX509;
  IssuerNeedsFree: Boolean;
  VerifyStore: PX509_STORE;
  OCSPStatus: Integer;
  OCSPTimeoutSec: Integer;
  LHttpHooksAccess: ISSLHttpHooksAccess;
  LHTTPHooks: TSSLHTTPHooks;
  LHTTPHooksScope: TSSLHTTPHooksScope;
  PeerDER: TBytes;
  ParsedCert: TX509Certificate;
  PeerChain: PSTACK_OF_X509;
  StoreCtx: PX509_STORE_CTX;
  VerifiedChain: PSTACK_OF_X509;

  function NormalizeHostForVerify(const S: string): string;
  var
    LHost: string;
    P, PEnd: SizeInt;
    PortPart: string;
    I: Integer;
  begin
    LHost := Trim(S);

    // Strip IPv6 brackets: [::1]
    if (LHost <> '') and (LHost[1] = '[') then
    begin
      PEnd := Pos(']', LHost);
      if PEnd > 0 then
        LHost := Copy(LHost, 2, PEnd - 2);
    end;

    // Strip zone id: fe80::1%eth0
    P := Pos('%', LHost);
    if P > 0 then
      LHost := Copy(LHost, 1, P - 1);

    // Strip port for the host:port case (not valid for plain IPv6 without brackets)
    if (Pos(':', LHost) > 0) and (Pos(':', LHost) = LastDelimiter(':', LHost)) then
    begin
      P := Pos(':', LHost);
      PortPart := Copy(LHost, P + 1, Length(LHost) - P);
      if PortPart <> '' then
      begin
        for I := 1 to Length(PortPart) do
          if not (PortPart[I] in ['0'..'9']) then
          begin
            PortPart := '';
            Break;
          end;
        if PortPart <> '' then
          LHost := Copy(LHost, 1, P - 1);
      end;
    end;

    Result := LHost;
  end;

  function IsValidIPv4(const S: string): Boolean;
  var
    Parts: TStringArray;
    Part: string;
    Value: Integer;
    I: Integer;
  begin
    Result := False;
    Parts := S.Split(['.']);
    if Length(Parts) <> 4 then
      Exit;

    for Part in Parts do
    begin
      if Part = '' then
        Exit;

      for I := 1 to Length(Part) do
        if not (Part[I] in ['0'..'9']) then
          Exit;

      if not TryStrToInt(Part, Value) then
        Exit;
      if (Value < 0) or (Value > 255) then
        Exit;
    end;

    Result := True;
  end;

begin
  Result := True;

  if (FSSL = nil) or (FContext = nil) then
    Exit(False);

  VerifyModes := FContext.GetVerifyMode;
  if not (sslVerifyPeer in VerifyModes) then
    Exit(True);

  if not Assigned(SSL_get_verify_result) then
    Exit(False);

  // Decide whether a peer certificate is required (align with WinSSL logic)
  RequirePeerCert := AIsClient or (sslVerifyFailIfNoPeerCert in VerifyModes);

  // Ensure X509 helpers are available before we materialize certificates
  if not Assigned(X509_free) then
    LoadOpenSSLX509;

  PeerCert := DoGetPeerCertificate;
  if PeerCert = nil then
  begin
    if RequirePeerCert then
    begin
      if Assigned(SSL_set_verify_result) then
        SSL_set_verify_result(FSSL, X509_V_ERR_APPLICATION_VERIFICATION);
      Result := False;
    end;
    Exit;
  end;

  // 安全获取对端证书的原生句柄
  if not TryGetNativeHandle(PeerCert, Pointer(PeerX509)) then
  begin
    Result := False;
    Exit;
  end;
  if PeerX509 = nil then
  begin
    if Assigned(SSL_set_verify_result) then
      SSL_set_verify_result(FSSL, X509_V_ERR_APPLICATION_VERIFICATION);
    Exit(False);
  end;

  VerifyRes := SSL_get_verify_result(FSSL);
  if VerifyRes <> X509_V_OK then
    Exit(False);

  VerifyFlags := FContext.GetCertVerifyFlags;
  ConnectionOptions := FContext.GetOptions;
  CertVerifyCacheEnabled := ssoEnableCertVerifyCache in ConnectionOptions;
  if CertVerifyCacheEnabled then
    CertVerifyCache := GetGlobalCertVerifyCache
  else
    CertVerifyCache := nil;

  // OCSP stapling required policy (fail-closed): require stapled response and verification success
  if not ValidateRequiredOCSPStapling(AIsClient) then
    Exit(False);

  // OCSP revocation checking (fail closed when requested)
  if sslCertVerifyCheckOCSP in VerifyFlags then
  begin
    IssuerX509 := nil;
    IssuerNeedsFree := False;

    try
      // Ensure OCSP APIs are loaded
      if not TOpenSSLLoader.IsModuleLoaded(osmOCSP) then
        LoadOpenSSLOCSP(GetCryptoLibHandle);

      if not TOpenSSLLoader.IsModuleLoaded(osmOCSP) then
      begin
        if Assigned(SSL_set_verify_result) then
          SSL_set_verify_result(FSSL, X509_V_ERR_OCSP_VERIFY_FAILED);
        Exit(False);
      end;

      // Extract responder URL from certificate AIA (pure-pascal parser)
      OCSPUrl := '';
      try
        PeerDER := PeerCert.SaveToDER;
        if Length(PeerDER) > 0 then
        begin
          ParsedCert := TX509Certificate.Create;
          try
            ParsedCert.LoadFromDER(PeerDER);
            OCSPUrl := GetOCSPURLFromCertificate(ParsedCert);
          finally
            ParsedCert.Free;
          end;
        end;
      except
        OCSPUrl := '';
      end;

      if OCSPUrl = '' then
      begin
        if Assigned(SSL_set_verify_result) then
          SSL_set_verify_result(FSSL, X509_V_ERR_OCSP_VERIFY_NEEDED);
        Exit(False);
      end;

      // Try to obtain issuer cert from the peer-provided chain first
      PeerChain := nil;
      if Assigned(SSL_get_peer_cert_chain) then
        PeerChain := SSL_get_peer_cert_chain(FSSL);

      if PeerChain <> nil then
        IssuerX509 := FindIssuerX509InChain(PeerX509, PeerChain);

      // Prefer verified chain from handshake when available (avoids re-running X509_verify_cert)
      if (IssuerX509 = nil) and Assigned(SSL_get0_verified_chain) then
      begin
        VerifiedChain := SSL_get0_verified_chain(FSSL);
        if VerifiedChain <> nil then
          IssuerX509 := FindIssuerX509InChain(PeerX509, VerifiedChain);
      end;

      // Fall back to verified chain building via X509_STORE if needed
      VerifyStore := nil;
      if Assigned(SSL_CTX_get_cert_store) then
        VerifyStore := SSL_CTX_get_cert_store(PSSL_CTX(GetNativeHandleSafe(FContext, 'TOpenSSLConnection.VerifyCertificateOCSP')));

      if (IssuerX509 = nil) and (VerifyStore <> nil) and
        Assigned(X509_STORE_CTX_new) and Assigned(X509_STORE_CTX_free) and
        Assigned(X509_STORE_CTX_init) and Assigned(X509_verify_cert) and
        Assigned(X509_STORE_CTX_get0_chain) then
      begin
        StoreCtx := X509_STORE_CTX_new();
        if StoreCtx <> nil then
        try
          PeerChain := nil;
          if Assigned(SSL_get_peer_cert_chain) then
            PeerChain := SSL_get_peer_cert_chain(FSSL);

          if X509_STORE_CTX_init(StoreCtx, VerifyStore, PeerX509, PeerChain) = 1 then
          begin
            PerformVerifyCall := True;

            if CertVerifyCacheEnabled and (CertVerifyCache <> nil) then
            begin
              if CertVerifyCache.TryGet(PeerX509, CachedVerifyResult) then
              begin
                if not CachedVerifyResult.Valid then
                begin
                  PerformVerifyCall := False;
                  TSecurityLog.Debug('OpenSSL',
                    'Cert verify cache hit (invalid result), skipping X509_verify_cert');
                end
                else
                  TSecurityLog.Debug('OpenSSL',
                    'Cert verify cache hit (valid result), refreshing X509_verify_cert');
              end
              else
                TSecurityLog.Debug('OpenSSL',
                  'Cert verify cache miss, executing X509_verify_cert');
            end;

            if PerformVerifyCall then
            begin
              VerifyRes := X509_verify_cert(StoreCtx);

              if CertVerifyCacheEnabled and (CertVerifyCache <> nil) then
              begin
                CachedVerifyResult.Valid := (VerifyRes = 1);
                if (VerifyRes = 1) then
                  CachedVerifyResult.ErrorCode := X509_V_OK
                else if Assigned(X509_STORE_CTX_get_error) then
                  CachedVerifyResult.ErrorCode := X509_STORE_CTX_get_error(StoreCtx)
                else
                  CachedVerifyResult.ErrorCode := X509_V_ERR_APPLICATION_VERIFICATION;
                CachedVerifyResult.ErrorMessage := '';
                CachedVerifyResult.VerifiedAt := nextpas.core.time.DateTimeNow;
                CertVerifyCache.Put(PeerX509, CachedVerifyResult);

                TSecurityLog.Debug('OpenSSL',
                  nextpas.core.text.conv.Format('Cert verify cache updated (valid=%s, code=%d)',
                    [BoolToStr(CachedVerifyResult.Valid, True), CachedVerifyResult.ErrorCode]));
              end;
            end
            else
            begin
              VerifyRes := 0;
              if Assigned(X509_STORE_CTX_set_error) and (CachedVerifyResult.ErrorCode <> 0) then
                X509_STORE_CTX_set_error(StoreCtx, CachedVerifyResult.ErrorCode);
            end;

            if VerifyRes = 1 then
            begin
              VerifiedChain := X509_STORE_CTX_get0_chain(StoreCtx);
              if VerifiedChain <> nil then
              begin
                IssuerX509 := FindIssuerX509InChain(PeerX509, VerifiedChain);
                if IssuerX509 <> nil then
                begin
                  if not Assigned(X509_up_ref) then
                    IssuerX509 := nil
                  else
                  begin
                    X509_up_ref(IssuerX509);
                    IssuerNeedsFree := True;
                  end;
                end;
              end;
            end;
          end;
        finally
          X509_STORE_CTX_free(StoreCtx);
        end;
      end;

      if IssuerX509 = nil then
      begin
        if Assigned(SSL_set_verify_result) then
          SSL_set_verify_result(FSSL, X509_V_ERR_UNABLE_TO_GET_ISSUER_CERT);
        Exit(False);
      end;

      // Map connection timeout (ms) to OCSP timeout (seconds)
      OCSPTimeoutSec := 10;
      if FTimeout > 0 then
      begin
        OCSPTimeoutSec := FTimeout div 1000;
        if OCSPTimeoutSec <= 0 then
          OCSPTimeoutSec := 1;
      end;

      // Perform OCSP check (HTTP transport via hooks; fafafa.ssl does not do networking).
      LHTTPHooks := TSSLHTTPHooks.Empty;
      if Supports(FContext, ISSLHttpHooksAccess, LHttpHooksAccess) then
        LHTTPHooks := TSSLHTTPHooks.Create(
          LHttpHooksAccess.GetHTTPGetCallback,
          LHttpHooksAccess.GetHTTPPostCallback
        );

      if not LHTTPHooks.IsEmpty then
      begin
        LHTTPHooksScope := TSSLHTTPHooksScope.Push(LHTTPHooks);
        try
          OCSPStatus := CheckCertificateStatus(PeerX509, IssuerX509, OCSPUrl, OCSPTimeoutSec, VerifyStore);
        finally
          LHTTPHooksScope.Pop;
        end;
      end
      else
        OCSPStatus := CheckCertificateStatus(PeerX509, IssuerX509, OCSPUrl, OCSPTimeoutSec, VerifyStore);
      case OCSPStatus of
        V_OCSP_CERTSTATUS_GOOD:
          ; // OK
        V_OCSP_CERTSTATUS_REVOKED:
          begin
            if Assigned(SSL_set_verify_result) then
              SSL_set_verify_result(FSSL, X509_V_ERR_CERT_REVOKED);
            Exit(False);
          end;
        V_OCSP_CERTSTATUS_UNKNOWN:
          begin
            if Assigned(SSL_set_verify_result) then
              SSL_set_verify_result(FSSL, X509_V_ERR_OCSP_CERT_UNKNOWN);
            Exit(False);
          end;
      else
        if Assigned(SSL_set_verify_result) then
          SSL_set_verify_result(FSSL, X509_V_ERR_OCSP_VERIFY_FAILED);
        Exit(False);
      end;

    finally
      if IssuerNeedsFree and (IssuerX509 <> nil) and Assigned(X509_free) then
        X509_free(IssuerX509);
    end;
  end;

  // Hostname verification: client-side only
  if AIsClient and not (sslCertVerifyIgnoreHostname in VerifyFlags) then
  begin
    Host := FServerName;
    HostNormalized := NormalizeHostForVerify(Host);

    if HostNormalized = '' then
    begin
      if Assigned(SSL_set_verify_result) then
        SSL_set_verify_result(FSSL, X509_V_ERR_HOSTNAME_MISMATCH);
      Exit(False);
    end;

    // Ensure hostname helpers are loaded
    if (not Assigned(X509_check_host)) and (not Assigned(X509_check_ip_asc)) then
      LoadOpenSSLX509;

    IsIP := IsValidIPv4(HostNormalized) or (Pos(':', HostNormalized) > 0);
    HostA := AnsiString(HostNormalized);

    if IsIP then
    begin
      if not Assigned(X509_check_ip_asc) then
      begin
        if Assigned(SSL_set_verify_result) then
          SSL_set_verify_result(FSSL, X509_V_ERR_APPLICATION_VERIFICATION);
        Exit(False);
      end;

      if X509_check_ip_asc(PeerX509, PAnsiChar(HostA), 0) <> 1 then
      begin
        if Assigned(SSL_set_verify_result) then
          SSL_set_verify_result(FSSL, X509_V_ERR_IP_ADDRESS_MISMATCH);
        Exit(False);
      end;
    end
    else
    begin
      if not Assigned(X509_check_host) then
      begin
        if Assigned(SSL_set_verify_result) then
          SSL_set_verify_result(FSSL, X509_V_ERR_APPLICATION_VERIFICATION);
        Exit(False);
      end;

      if X509_check_host(PeerX509, PAnsiChar(HostA), Length(HostA), 0, nil) <> 1 then
      begin
        if Assigned(SSL_set_verify_result) then
          SSL_set_verify_result(FSSL, X509_V_ERR_HOSTNAME_MISMATCH);
        Exit(False);
      end;
    end;
  end;

  Result := True;
end;

end.
