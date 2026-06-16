{**
 * Unit: nextpas.core.tls.wolfssl.connection
 * Purpose: WolfSSL SSL 连接实现
 *
 * 继承 TBaseSSLConnection 基类，实现 WolfSSL 后端的连接功能。
 * 支持基于 Socket 和 Stream 的 TLS 连接。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-02-04
 *}

unit nextpas.core.tls.wolfssl.connection;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.text.conv, Classes,
  nextpas.core.io.intf,
  nextpas.core.io.stream_adapter,
  nextpas.core.tls.base,
  nextpas.core.tls.errors,
  nextpas.core.tls.exceptions,
  nextpas.core.tls.connection.base,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.native_handle,
  nextpas.core.tls.wolfssl.api;

type
  PWolfSSLIOContext = ^TWolfSSLIOContext;
  TWolfSSLIOContext = record
    Stream: IStream;
  end;

  { TWolfSSLConnection - WolfSSL SSL 连接类 }
  TWolfSSLConnection = class(TBaseSSLConnection, ISSLClientConnection,
    ISSLNativeHandleAccess)
  private
    FWolfSSLCtx: PWOLFSSL_CTX;
    FWolfSSL: PWOLFSSL;
    FSocket: THandle;
    FStream: IStream;
    FIOContext: PWolfSSLIOContext;
    FServerName: string;
    FALPNProtocols: string;
    FNegotiatedALPN: string;
    FLastNativeError: Integer;
    FConfiguredSession: ISSLSession;
    FEarlyDataPayload: TBytes;
    FEarlyDataStatus: TSSLEarlyDataStatus;
    FEarlyDataLimit: Cardinal;

    procedure SetupSocket;
    procedure SetupStream;
    procedure FreeIOContext;
    procedure SetupSNI;
    procedure SetupALPN;
    function CompleteStreamHandshake(AIsClient: Boolean): Boolean;
    function ApplyPreHandshakeOCSPStaplingRequest: Boolean;
    function ApplyPreHandshakeServerOCSPStaplingConfiguration: Boolean;
    function MaterializePeerCertificateFromDER(const ADER: TBytes): ISSLCertificate;
    function MaterializePeerCertificateChain: TSSLCertificateArray;
    function FindIssuerCertificate(const ALeaf: ISSLCertificate;
      const ACertificates: TSSLCertificateArray): ISSLCertificate;
    procedure LinkPeerCertificateIssuerLinks(const ACertificates: TSSLCertificateArray);
    function ResolveEarlyDataLimitFromSession(const ASession: ISSLSession): Cardinal;
    function SendQueuedEarlyData: Boolean;
    procedure UpdateEarlyDataStatusFromNative;
    function ValidateRequiredOCSPStapling: Boolean;

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
    constructor Create(AContext: ISSLContext; ASocket: THandle); overload;
    constructor Create(AContext: ISSLContext; AStream: TStream); overload;
    constructor Create(AContext: ISSLContext; AStream: IStream); overload;
    destructor Destroy; override;

    function GetConnectionInfo: TSSLConnectionInfo; override;

    { SNI/ALPN 设置 }
    procedure SetServerName(const AServerName: string);
    function GetServerName: string;

    { ISSLEarlyDataConnection }
    function SetEarlyData(const AData: TBytes): TSSLOperationResult;
    function GetEarlyDataStatus: TSSLEarlyDataStatus;
    function GetEarlyDataLimit: Cardinal;

    { 额外方法 }
    function GetNegotiatedProtocol: TSSLProtocolVersion;
    function GetNegotiatedCipher: string;
    function GetNegotiatedALPN: string;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
    function GetLastError: Integer;
    function GetLastErrorString: string;
  end;

  { 仅在运行时 OCSP capability 可用时才暴露该接口 }
  TWolfSSLOCSPConnection = class(TWolfSSLConnection, ISSLOCSPStapling)
  end;

  { 仅在运行时 early-data capability 可用时才暴露该接口 }
  TWolfSSLEarlyDataConnection = class(TWolfSSLConnection, ISSLEarlyDataConnection)
  end;

  { 同时暴露 early-data 与 OCSP 两类可选接口 }
  TWolfSSLAdvancedConnection = class(TWolfSSLEarlyDataConnection, ISSLOCSPStapling)
  end;

implementation

uses
  nextpas.core.tls.wolfssl.certificate,
  nextpas.core.tls.wolfssl.session;

{ WolfSSL I/O 回调函数（用于流支持）}

function NormalizeWolfCertificateLinkText(const AValue: string): string;
begin
  Result := Trim(UpperCase(AValue));
  Result := StringReplace(Result, ',', '', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
end;

function WolfSSL_StreamRecvCallback(ssl: PWOLFSSL; buf: PAnsiChar; sz: Integer;
  ctx: Pointer): Integer; cdecl;
var
  LContext: PWolfSSLIOContext;
  LBytesRead: Integer;
begin
  Result := -1;
  if ctx = nil then Exit;

  LContext := PWolfSSLIOContext(ctx);
  if (LContext = nil) or (LContext^.Stream = nil) then
    Exit;
  try
    LBytesRead := Integer(LContext^.Stream.Read(buf^, sz));
    if LBytesRead = 0 then
      Result := -2  // WOLFSSL_CBIO_ERR_WANT_READ
    else if LBytesRead < 0 then
      Result := -1  // WOLFSSL_CBIO_ERR_GENERAL
    else
      Result := LBytesRead;
  except
    Result := -1;  // WOLFSSL_CBIO_ERR_GENERAL
  end;
end;

function WolfSSL_StreamSendCallback(ssl: PWOLFSSL; buf: PAnsiChar; sz: Integer;
  ctx: Pointer): Integer; cdecl;
var
  LContext: PWolfSSLIOContext;
  LBytesWritten: Integer;
begin
  Result := -1;
  if ctx = nil then Exit;

  LContext := PWolfSSLIOContext(ctx);
  if (LContext = nil) or (LContext^.Stream = nil) then
    Exit;
  try
    LBytesWritten := Integer(LContext^.Stream.Write(buf^, sz));
    if LBytesWritten = 0 then
      Result := -3  // WOLFSSL_CBIO_ERR_WANT_WRITE
    else if LBytesWritten < 0 then
      Result := -1  // WOLFSSL_CBIO_ERR_GENERAL
    else
      Result := LBytesWritten;
  except
    Result := -1;  // WOLFSSL_CBIO_ERR_GENERAL
  end;
end;

{ TWolfSSLConnection }

constructor TWolfSSLConnection.Create(AContext: ISSLContext; ASocket: THandle);
begin
  inherited Create(AContext);
  FWolfSSLCtx := PWOLFSSL_CTX(GetNativeHandleSafe(AContext, 'TWolfSSLConnection.Create'));
  FSocket := ASocket;
  FStream := nil;
  FIOContext := nil;
  FWolfSSL := nil;
  FServerName := '';
  FALPNProtocols := AContext.GetALPNProtocols;
  FNegotiatedALPN := '';
  FLastNativeError := 0;
  FConfiguredSession := nil;
  SetLength(FEarlyDataPayload, 0);
  FEarlyDataStatus := sslEarlyDataNone;
  FEarlyDataLimit := 0;

  if FWolfSSLCtx = nil then
    raise ESSLException.Create('Invalid WolfSSL context');

  if not Assigned(wolfSSL_new) then
    raise ESSLException.Create('wolfSSL_new not available');

  FWolfSSL := wolfSSL_new(FWolfSSLCtx);
  if FWolfSSL = nil then
    raise ESSLException.Create('Failed to create WolfSSL connection');

  SetupSocket;
  SetupSNI;
  SetupALPN;
end;

constructor TWolfSSLConnection.Create(AContext: ISSLContext; AStream: TStream);
begin
  Create(AContext, WrapTStream(AStream, False));
end;

constructor TWolfSSLConnection.Create(AContext: ISSLContext; AStream: IStream);
begin
  inherited Create(AContext);
  FWolfSSLCtx := PWOLFSSL_CTX(GetNativeHandleSafe(AContext, 'TWolfSSLConnection.Create'));
  FSocket := 0;
  FStream := AStream;
  FIOContext := nil;
  FWolfSSL := nil;
  FServerName := '';
  FALPNProtocols := AContext.GetALPNProtocols;
  FNegotiatedALPN := '';
  FLastNativeError := 0;
  FConfiguredSession := nil;
  SetLength(FEarlyDataPayload, 0);
  FEarlyDataStatus := sslEarlyDataNone;
  FEarlyDataLimit := 0;

  if AStream = nil then
    raise ESSLException.Create('Stream cannot be nil');

  if FWolfSSLCtx = nil then
    raise ESSLException.Create('Invalid WolfSSL context');

  if not Assigned(wolfSSL_new) then
    raise ESSLException.Create('wolfSSL_new not available');

  FWolfSSL := wolfSSL_new(FWolfSSLCtx);
  if FWolfSSL = nil then
    raise ESSLException.Create('Failed to create WolfSSL connection');

  SetupStream;
  SetupSNI;
  SetupALPN;
end;

destructor TWolfSSLConnection.Destroy;
begin
  if FConnected then
    DoShutdown;
  FreeIOContext;
  if FWolfSSL <> nil then
  begin
    if Assigned(wolfSSL_free) then
      wolfSSL_free(FWolfSSL);
    FWolfSSL := nil;
  end;
  inherited Destroy;
end;

procedure TWolfSSLConnection.SetupSocket;
begin
  if Assigned(wolfSSL_set_fd) then
    wolfSSL_set_fd(FWolfSSL, Integer(FSocket));
end;

procedure TWolfSSLConnection.SetupStream;
begin
  // 检查 I/O 回调是否可用
  if ((not Assigned(wolfSSL_SSLSetIORecv)) or
      (not Assigned(wolfSSL_SSLSetIOSend))) and
    ((not Assigned(wolfSSL_CTX_SetIORecv)) or
      (not Assigned(wolfSSL_CTX_SetIOSend))) then
    raise ESSLException.Create('WolfSSL I/O callbacks not available - stream connections not supported');

  // 优先在具体 SSL 对象上挂接 I/O 回调，避免晚于 wolfSSL_new(...)
  // 才修改 ctx 时，当前连接仍回落到默认 socket I/O。
  if Assigned(wolfSSL_SSLSetIORecv) and Assigned(wolfSSL_SSLSetIOSend) then
  begin
    wolfSSL_SSLSetIORecv(FWolfSSL, @WolfSSL_StreamRecvCallback);
    wolfSSL_SSLSetIOSend(FWolfSSL, @WolfSSL_StreamSendCallback);
  end
  else
  begin
    wolfSSL_CTX_SetIORecv(FWolfSSLCtx, @WolfSSL_StreamRecvCallback);
    wolfSSL_CTX_SetIOSend(FWolfSSLCtx, @WolfSSL_StreamSendCallback);
  end;

  // 设置 I/O 上下文（传递流指针）
  if Assigned(wolfSSL_SetIOReadCtx) and Assigned(wolfSSL_SetIOWriteCtx) then
  begin
    if FIOContext = nil then
    begin
      New(FIOContext);
      FillChar(FIOContext^, SizeOf(TWolfSSLIOContext), 0);
    end;
    FIOContext^.Stream := FStream;
    wolfSSL_SetIOReadCtx(FWolfSSL, FIOContext);
    wolfSSL_SetIOWriteCtx(FWolfSSL, FIOContext);
  end;
end;

procedure TWolfSSLConnection.FreeIOContext;
begin
  if FIOContext = nil then
    Exit;
  FIOContext^.Stream := nil;
  Dispose(FIOContext);
  FIOContext := nil;
end;

procedure TWolfSSLConnection.SetupSNI;
begin
  if (FServerName <> '') and Assigned(wolfSSL_UseSNI) then
    wolfSSL_UseSNI(FWolfSSL, 0, PAnsiChar(AnsiString(FServerName)), Length(FServerName));
end;

procedure TWolfSSLConnection.SetupALPN;
begin
  if (FALPNProtocols <> '') and Assigned(wolfSSL_UseALPN) then
    wolfSSL_UseALPN(FWolfSSL, PAnsiChar(AnsiString(FALPNProtocols)),
      Length(FALPNProtocols), 0);  // 0 = WOLFSSL_ALPN_CONTINUE_ON_MISMATCH
end;

function TWolfSSLConnection.CompleteStreamHandshake(AIsClient: Boolean): Boolean;
const
  MAX_STREAM_HANDSHAKE_ATTEMPTS = 64;
var
  LAttempt: Integer;
  LResult: Integer;
begin
  Result := False;

  if FWolfSSL = nil then
    Exit;

  for LAttempt := 1 to MAX_STREAM_HANDSHAKE_ATTEMPTS do
  begin
    if AIsClient then
      LResult := wolfSSL_connect(FWolfSSL)
    else
      LResult := wolfSSL_accept(FWolfSSL);

    if LResult = WOLFSSL_SUCCESS then
    begin
      FLastNativeError := 0;
      Exit(True);
    end;

    if Assigned(wolfSSL_get_error) then
      FLastNativeError := wolfSSL_get_error(FWolfSSL, LResult)
    else
      FLastNativeError := LResult;

    if (FLastNativeError <> WOLFSSL_ERROR_WANT_READ) and
      (FLastNativeError <> WOLFSSL_ERROR_WANT_WRITE) then
      Exit(False);
  end;
end;

function TWolfSSLConnection.ApplyPreHandshakeOCSPStaplingRequest: Boolean;
var
  LOptions: TSSLOptions;
begin
  Result := True;

  if (FWolfSSL = nil) or (FContext = nil) or
    (not ContextTypeSupportsClientConnectionRole(FContext.GetContextType)) then
    Exit;

  LOptions := FContext.GetOptions;
  if not ((ssoEnableOCSPStapling in LOptions) or
          (ssoRequireOCSPStapling in LOptions)) then
    Exit;

  if Assigned(wolfSSL_CTX_EnableOCSPStapling) and (FWolfSSLCtx <> nil) and
    (wolfSSL_CTX_EnableOCSPStapling(FWolfSSLCtx) <> WOLFSSL_SUCCESS) then
  begin
    FLastNativeError := WOLFSSL_FAILURE;
    Exit(False);
  end;

  if not Assigned(wolfSSL_UseOCSPStapling) then
  begin
    FLastNativeError := WOLFSSL_FAILURE;
    Exit(False);
  end;

  if wolfSSL_UseOCSPStapling(FWolfSSL, WOLFSSL_CSR_OCSP,
    WOLFSSL_CSR_OCSP_USE_NONCE) <> WOLFSSL_SUCCESS then
  begin
    FLastNativeError := WOLFSSL_FAILURE;
    Exit(False);
  end;
end;

function TWolfSSLConnection.ApplyPreHandshakeServerOCSPStaplingConfiguration: Boolean;
var
  LServerStapling: ISSLServerOCSPStaplingContext;
  LRet: PtrInt;
begin
  Result := True;

  if (FWolfSSL = nil) or (FContext = nil) or
    (not ContextTypeSupportsServerConnectionRole(FContext.GetContextType)) then
    Exit;

  if not Supports(FContext, ISSLServerOCSPStaplingContext, LServerStapling) then
    Exit;

  if not LServerStapling.HasServerStapledOCSPResponse then
    Exit;

  if Assigned(wolfSSL_EnableOCSPStapling) and
    (wolfSSL_EnableOCSPStapling(FWolfSSL) <> WOLFSSL_SUCCESS) then
  begin
    FLastNativeError := WOLFSSL_FAILURE;
    Exit(False);
  end;

  if not Assigned(wolfSSL_set_tlsext_status_type) then
    Exit;

  LRet := wolfSSL_set_tlsext_status_type(FWolfSSL, WOLFSSL_CSR_OCSP);
  if LRet < 0 then
  begin
    FLastNativeError := Integer(LRet);
    Exit(False);
  end;
end;

function TWolfSSLConnection.ResolveEarlyDataLimitFromSession(
  const ASession: ISSLSession): Cardinal;
var
  LSession: PWOLFSSL_SESSION;
  LNativeLimit: Integer;
begin
  Result := 0;

  if (ASession <> nil) and Assigned(wolfSSL_SESSION_get_max_early_data) and
    TryGetNativeHandle(ASession, Pointer(LSession)) and (LSession <> nil) then
    Exit(wolfSSL_SESSION_get_max_early_data(LSession));

  if (FWolfSSL <> nil) and Assigned(wolfSSL_get_max_early_data) then
  begin
    LNativeLimit := wolfSSL_get_max_early_data(FWolfSSL);
    if LNativeLimit > 0 then
      Exit(Cardinal(LNativeLimit));
  end;

  if (FWolfSSLCtx <> nil) and Assigned(wolfSSL_CTX_get_max_early_data) then
    Result := wolfSSL_CTX_get_max_early_data(FWolfSSLCtx);
end;

procedure TWolfSSLConnection.UpdateEarlyDataStatusFromNative;
var
  LNativeStatus: Integer;
begin
  if (FWolfSSL = nil) or (not Assigned(wolfSSL_get_early_data_status)) then
    Exit;

  LNativeStatus := wolfSSL_get_early_data_status(FWolfSSL);
  case LNativeStatus of
    WOLFSSL_EARLY_DATA_ACCEPTED:
      FEarlyDataStatus := sslEarlyDataAccepted;
    WOLFSSL_EARLY_DATA_REJECTED:
      FEarlyDataStatus := sslEarlyDataRejected;
    WOLFSSL_EARLY_DATA_NOT_SENT:
      begin
        if FEarlyDataStatus = sslEarlyDataQueued then
          FEarlyDataStatus := sslEarlyDataRejected
        else
          FEarlyDataStatus := sslEarlyDataNone;
      end;
  end;
end;

function TWolfSSLConnection.SendQueuedEarlyData: Boolean;
var
  LRet, LOutSz, LOffset: Integer;
begin
  Result := True;

  if (FEarlyDataStatus <> sslEarlyDataQueued) or (Length(FEarlyDataPayload) = 0) then
    Exit;

  if (FWolfSSL = nil) or (not Assigned(wolfSSL_write_early_data)) then
    Exit(False);

  LOffset := 0;
  while LOffset < Length(FEarlyDataPayload) do
  begin
    LOutSz := 0;
    LRet := wolfSSL_write_early_data(FWolfSSL, @FEarlyDataPayload[LOffset],
      Length(FEarlyDataPayload) - LOffset, @LOutSz);
    if LRet = WOLFSSL_SUCCESS then
    begin
      Inc(LOffset, LOutSz);
      Continue;
    end;

    if Assigned(wolfSSL_get_error) then
      FLastNativeError := wolfSSL_get_error(FWolfSSL, LRet)
    else
      FLastNativeError := LRet;
    Exit(False);
  end;
end;

function TWolfSSLConnection.ValidateRequiredOCSPStapling: Boolean;
begin
  Result := True;

  if (FContext = nil) or
    (not ContextTypeSupportsClientConnectionRole(FContext.GetContextType)) then
    Exit;

  if not (ssoRequireOCSPStapling in FContext.GetOptions) then
    Exit;

  Result := Length(DoGetOCSPResponse) > 0;
  if not Result then
    FLastNativeError := WOLFSSL_FAILURE;
end;

{ 抽象方法实现 }

function TWolfSSLConnection.DoRead(var ABuffer; ACount: Integer): Integer;
begin
  Result := -1;
  if FWolfSSL = nil then Exit;
  if not Assigned(wolfSSL_read) then Exit;

  Result := wolfSSL_read(FWolfSSL, @ABuffer, ACount);
  if Result < 0 then
    FLastNativeError := wolfSSL_get_error(FWolfSSL, Result);
end;

function TWolfSSLConnection.DoWrite(const ABuffer; ACount: Integer): Integer;
begin
  Result := -1;
  if FWolfSSL = nil then Exit;
  if not Assigned(wolfSSL_write) then Exit;

  Result := wolfSSL_write(FWolfSSL, @ABuffer, ACount);
  if Result < 0 then
    FLastNativeError := wolfSSL_get_error(FWolfSSL, Result);
end;

function TWolfSSLConnection.DoConnect: Boolean;
var
  LResult: Integer;
begin
  Result := False;
  if FWolfSSL = nil then Exit;
  if not Assigned(wolfSSL_connect) then Exit;

  if not ApplyPreHandshakeOCSPStaplingRequest then
    Exit(False);

  if not SendQueuedEarlyData then
    Exit(False);

  if FStream <> nil then
  begin
    Result := CompleteStreamHandshake(True);
    if Result then
    begin
      UpdateEarlyDataStatusFromNative;
      Result := ValidateRequiredOCSPStapling;
    end;
    Exit;
  end;

  LResult := wolfSSL_connect(FWolfSSL);
  if LResult <> WOLFSSL_SUCCESS then
    FLastNativeError := wolfSSL_get_error(FWolfSSL, LResult);
  Result := LResult = WOLFSSL_SUCCESS;
  if Result then
  begin
    UpdateEarlyDataStatusFromNative;
    Result := ValidateRequiredOCSPStapling;
  end;
end;

function TWolfSSLConnection.DoAccept: Boolean;
var
  LResult: Integer;
begin
  Result := False;
  if FWolfSSL = nil then Exit;
  if not Assigned(wolfSSL_accept) then Exit;

  if not ApplyPreHandshakeServerOCSPStaplingConfiguration then
    Exit(False);

  if FStream <> nil then
  begin
    Result := CompleteStreamHandshake(False);
    Exit;
  end;

  LResult := wolfSSL_accept(FWolfSSL);
  if LResult <> WOLFSSL_SUCCESS then
    FLastNativeError := wolfSSL_get_error(FWolfSSL, LResult);
  Result := LResult = WOLFSSL_SUCCESS;
end;

function TWolfSSLConnection.DoHandshakeInternal: TSSLHandshakeState;
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

function TWolfSSLConnection.DoShutdown: Boolean;
var
  LResult: Integer;
begin
  Result := False;
  if FWolfSSL = nil then Exit;
  if not Assigned(wolfSSL_shutdown) then Exit;

  LResult := wolfSSL_shutdown(FWolfSSL);
  Result := LResult >= 0;
end;

procedure TWolfSSLConnection.DoClose;
begin
  DoShutdown;
  FreeIOContext;
end;

function TWolfSSLConnection.DoRenegotiate: Boolean;
begin
  RecordError(
    sslErrUnsupported,
    'TLS renegotiation is not supported by the current WolfSSL backend. ' +
    'Close the connection and establish a new one instead.'
  );
  Result := False;
end;

function TWolfSSLConnection.DoGetError(ARet: Integer): TSSLErrorCode;
var
  LErr: Integer;
begin
  if (FLastNativeError = 0) and (FLastErrorCode <> sslErrNone) then
    Exit(FLastErrorCode);

  if FWolfSSL = nil then
    Exit(sslErrGeneral);

  if Assigned(wolfSSL_get_error) then
    LErr := wolfSSL_get_error(FWolfSSL, ARet)
  else
    LErr := FLastNativeError;

  Result := WolfSSLErrorToSSLError(LErr);
end;

function TWolfSSLConnection.DoWantRead: Boolean;
begin
  Result := FLastNativeError = WOLFSSL_ERROR_WANT_READ;
end;

function TWolfSSLConnection.DoWantWrite: Boolean;
begin
  Result := FLastNativeError = WOLFSSL_ERROR_WANT_WRITE;
end;

function TWolfSSLConnection.DoGetProtocolVersion: TSSLProtocolVersion;
var
  LVersion: PAnsiChar;
begin
  Result := sslProtocolTLS12;  // 默认值
  if FWolfSSL = nil then Exit;

  if Assigned(wolfSSL_get_version) then
  begin
    LVersion := wolfSSL_get_version(FWolfSSL);
    if LVersion <> nil then
    begin
      if Pos('TLSv1.3', string(LVersion)) > 0 then
        Result := sslProtocolTLS13
      else if Pos('TLSv1.2', string(LVersion)) > 0 then
        Result := sslProtocolTLS12
      else if Pos('TLSv1.1', string(LVersion)) > 0 then
        Result := sslProtocolTLS11
      else if Pos('TLSv1', string(LVersion)) > 0 then
        Result := sslProtocolTLS10;
    end;
  end;
end;

function TWolfSSLConnection.DoGetCipherName: string;
var
  LCipher: Pointer;
  LName: PAnsiChar;
begin
  Result := '';
  if FWolfSSL = nil then Exit;

  if Assigned(wolfSSL_get_current_cipher) and Assigned(wolfSSL_CIPHER_get_name) then
  begin
    LCipher := wolfSSL_get_current_cipher(FWolfSSL);
    if LCipher <> nil then
    begin
      LName := wolfSSL_CIPHER_get_name(LCipher);
      if LName <> nil then
        Result := string(LName);
    end;
  end;
end;

function TWolfSSLConnection.MaterializePeerCertificateFromDER(
  const ADER: TBytes
): ISSLCertificate;
var
  LCert: TWolfSSLCertificate;
begin
  Result := nil;
  if Length(ADER) = 0 then
    Exit;

  LCert := TWolfSSLCertificate.Create;
  try
    if not LCert.LoadFromDER(ADER) then
      Exit;
    Result := LCert;
    LCert := nil;
  finally
    LCert.Free;
  end;
end;

function TWolfSSLConnection.FindIssuerCertificate(const ALeaf: ISSLCertificate;
  const ACertificates: TSSLCertificateArray): ISSLCertificate;
var
  I: Integer;
  LTargetIssuer: string;
  LLeafFingerprint: string;
  LCandidateFingerprint: string;
begin
  Result := nil;
  if ALeaf = nil then
    Exit;

  LTargetIssuer := NormalizeWolfCertificateLinkText(ALeaf.GetIssuer);
  if LTargetIssuer = '' then
    Exit;

  LLeafFingerprint := ALeaf.GetFingerprintSHA256;
  for I := 0 to High(ACertificates) do
  begin
    if ACertificates[I] = nil then
      Continue;

    LCandidateFingerprint := ACertificates[I].GetFingerprintSHA256;
    if SameText(LCandidateFingerprint, LLeafFingerprint) then
      Continue;

    if NormalizeWolfCertificateLinkText(ACertificates[I].GetSubject) = LTargetIssuer then
    begin
      Result := ACertificates[I];
      Exit;
    end;
  end;
end;

procedure TWolfSSLConnection.LinkPeerCertificateIssuerLinks(
  const ACertificates: TSSLCertificateArray
);
var
  I: Integer;
begin
  for I := 0 to High(ACertificates) do
    if ACertificates[I] <> nil then
      ACertificates[I].SetIssuerCertificate(
        FindIssuerCertificate(ACertificates[I], ACertificates));
end;

function TWolfSSLConnection.MaterializePeerCertificateChain: TSSLCertificateArray;
var
  LChain: PWOLFSSL_X509_CHAIN;
  LCount: Integer;
  I: Integer;
  LDERPtr: PByte;
  LDERLen: Integer;
  LDER: TBytes;
begin
  SetLength(Result, 0);

  if FWolfSSL = nil then
    Exit;

  if (not Assigned(wolfSSL_get_peer_chain)) or
    (not Assigned(wolfSSL_get_chain_count)) or
    (not Assigned(wolfSSL_get_chain_length)) or
    (not Assigned(wolfSSL_get_chain_cert)) then
    Exit;

  LChain := wolfSSL_get_peer_chain(FWolfSSL);
  if LChain = nil then
    Exit;

  LCount := wolfSSL_get_chain_count(LChain);
  if LCount <= 0 then
    Exit;

  SetLength(Result, LCount);
  for I := 0 to LCount - 1 do
  begin
    LDERLen := wolfSSL_get_chain_length(LChain, I);
    LDERPtr := wolfSSL_get_chain_cert(LChain, I);
    if (LDERLen <= 0) or (LDERPtr = nil) then
    begin
      SetLength(Result, 0);
      Exit;
    end;

    SetLength(LDER, LDERLen);
    Move(LDERPtr^, LDER[0], LDERLen);
    Result[I] := MaterializePeerCertificateFromDER(LDER);
    if Result[I] = nil then
    begin
      SetLength(Result, 0);
      Exit;
    end;
  end;

  LinkPeerCertificateIssuerLinks(Result);
end;

function TWolfSSLConnection.DoGetPeerCertificate: ISSLCertificate;
var
  LX509: PWOLFSSL_X509;
  LDER: TBytes;
  LTemp: TWolfSSLCertificate;
  LChain: TSSLCertificateArray;
  LIssuer: ISSLCertificate;
begin
  Result := nil;
  if FWolfSSL = nil then Exit;
  if not Assigned(wolfSSL_get_peer_certificate) then Exit;

  LX509 := wolfSSL_get_peer_certificate(FWolfSSL);
  if LX509 = nil then
    Exit;

  LTemp := TWolfSSLCertificate.Create(LX509);
  try
    LDER := LTemp.SaveToDER;
    if Length(LDER) = 0 then
      Exit;

    Result := MaterializePeerCertificateFromDER(LDER);
    if Result = nil then
      Exit;

    LChain := MaterializePeerCertificateChain;
    LIssuer := FindIssuerCertificate(Result, LChain);
    if LIssuer <> nil then
      Result.SetIssuerCertificate(LIssuer);
  finally
    LTemp.Free;
  end;
end;

function TWolfSSLConnection.DoGetPeerCertificateChain: TSSLCertificateArray;
begin
  Result := MaterializePeerCertificateChain;
end;

function TWolfSSLConnection.DoGetVerifyResult: Integer;
begin
  // WolfSSL 没有直接的 get_verify_result API
  // 使用 FLastNativeError 来跟踪验证错误
  // pre-handshake 路径不能伪装成验证通过
  if FLastNativeError <> 0 then
    Exit(FLastNativeError);

  if not FHandshakeComplete then
    Exit(-1);

  Result := 0;
end;

function TWolfSSLConnection.DoGetVerifyResultString: string;
var
  LResult: Integer;
begin
  if (FLastErrorCode <> sslErrNone) and (FLastErrorString <> '') then
    Exit(FLastErrorString);

  if not FHandshakeComplete then
    Exit('Not verified');

  LResult := DoGetVerifyResult;
  if LResult = 0 then
    Result := 'OK'
  else if LResult = WOLFSSL_SUCCESS then
    Result := 'OK'
  else
    Result := GetLastErrorString;
end;

function TWolfSSLConnection.DoGetSession: ISSLSession;
begin
  Result := TWolfSSLSession.FromConnection(FWolfSSL);
end;

procedure TWolfSSLConnection.DoSetSession(ASession: ISSLSession);
var
  LSession: PWOLFSSL_SESSION;
begin
  FConfiguredSession := ASession;
  FEarlyDataLimit := 0;

  if ASession = nil then Exit;
  if FWolfSSL = nil then Exit;
  if not Assigned(wolfSSL_set_session) then Exit;

  if not TryGetNativeHandle(ASession, Pointer(LSession)) then
    Exit;

  if LSession <> nil then
  begin
    if wolfSSL_set_session(FWolfSSL, LSession) = WOLFSSL_SUCCESS then
      FEarlyDataLimit := ResolveEarlyDataLimitFromSession(ASession);
  end;
end;

function TWolfSSLConnection.DoIsSessionReused: Boolean;
begin
  Result := False;
  if FWolfSSL = nil then Exit;
  if not Assigned(wolfSSL_session_reused) then Exit;

  Result := wolfSSL_session_reused(FWolfSSL) = 1;
end;

function TWolfSSLConnection.DoGetConnectionInfoServerName: string;
begin
  Result := FServerName;
end;

function TWolfSSLConnection.GetConnectionInfo: TSSLConnectionInfo;
begin
  Result := inherited GetConnectionInfo;

  if FWolfSSL = nil then
    Exit;

  if (Result.MacSize = 0) and Assigned(wolfSSL_GetHmacSize) then
  begin
    Result.MacSize := wolfSSL_GetHmacSize(FWolfSSL);
    if Result.MacSize < 0 then
      Result.MacSize := 0;
  end;
end;

function TWolfSSLConnection.DoGetSelectedALPNProtocol: string;
var
  LProtocol: PAnsiChar;
  LSize: Word;
begin
  Result := '';
  if FWolfSSL = nil then Exit;

  // 如果已经缓存了协商结果，直接返回
  if FNegotiatedALPN <> '' then
  begin
    Result := FNegotiatedALPN;
    Exit;
  end;

  // 从 WolfSSL 获取协商的 ALPN 协议
  if Assigned(wolfSSL_ALPN_GetProtocol) then
  begin
    LProtocol := nil;
    LSize := 0;
    if wolfSSL_ALPN_GetProtocol(FWolfSSL, @LProtocol, @LSize) = WOLFSSL_SUCCESS then
    begin
      if (LProtocol <> nil) and (LSize > 0) then
      begin
        SetString(FNegotiatedALPN, LProtocol, LSize);
        Result := FNegotiatedALPN;
      end;
    end;
  end;
end;

function TWolfSSLConnection.DoGetState: string;
begin
  if FHandshakeComplete then
    Result := 'CONNECTED'
  else
    Result := 'DISCONNECTED';
end;

function TWolfSSLConnection.DoGetNativeHandle: Pointer;
begin
  Result := FWolfSSL;
end;

{ OCSP 方法覆盖 }

function TWolfSSLConnection.DoGetOCSPStaplingEnabled: Boolean;
begin
  Result := Length(DoGetOCSPResponse) > 0;
end;

function TWolfSSLConnection.DoGetOCSPResponse: TBytes;
var
  LRespPtr: PByte;
  LRespLen: Integer;
begin
  SetLength(Result, 0);

  if FWolfSSL = nil then Exit;

  if not Assigned(wolfSSL_GetOCSP_Response) then Exit;

  LRespPtr := nil;
  LRespLen := wolfSSL_GetOCSP_Response(FWolfSSL, @LRespPtr);

  if (LRespLen > 0) and (LRespPtr <> nil) then
  begin
    SetLength(Result, LRespLen);
    Move(LRespPtr^, Result[0], LRespLen);
  end;
end;

function TWolfSSLConnection.DoIsOCSPResponseVerified: Boolean;
var
  LResp: TBytes;
begin
  // 简化实现：如果能获取到响应，认为已验证
  // WolfSSL 会在握手期间验证 OCSP 响应
  LResp := DoGetOCSPResponse;
  Result := Length(LResp) > 0;
end;

function TWolfSSLConnection.DoGetOCSPResponseStatus: string;
var
  LResp: TBytes;
begin
  if not Assigned(wolfSSL_GetOCSP_Response) then
  begin
    Result := 'OCSP API not available';
    Exit;
  end;

  LResp := DoGetOCSPResponse;
  if Length(LResp) = 0 then
    Result := 'No OCSP Response'
  else
    Result := 'Response Available';
end;

{ SNI/ALPN 设置 }

procedure TWolfSSLConnection.SetServerName(const AServerName: string);
begin
  FServerName := AServerName;
  if (FWolfSSL <> nil) and (FServerName <> '') and Assigned(wolfSSL_UseSNI) then
    wolfSSL_UseSNI(FWolfSSL, 0, PAnsiChar(AnsiString(FServerName)), Length(FServerName));
end;

function TWolfSSLConnection.GetServerName: string;
begin
  Result := FServerName;
end;

function TWolfSSLConnection.SetEarlyData(
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

function TWolfSSLConnection.GetEarlyDataStatus: TSSLEarlyDataStatus;
begin
  if FHandshakeComplete or FConnected then
    UpdateEarlyDataStatusFromNative;
  Result := FEarlyDataStatus;
end;

function TWolfSSLConnection.GetEarlyDataLimit: Cardinal;
begin
  Result := FEarlyDataLimit;
end;

{ 额外方法 }

function TWolfSSLConnection.GetNegotiatedProtocol: TSSLProtocolVersion;
begin
  Result := DoGetProtocolVersion;
end;

function TWolfSSLConnection.GetNegotiatedCipher: string;
begin
  Result := DoGetCipherName;
end;

function TWolfSSLConnection.GetNegotiatedALPN: string;
begin
  Result := DoGetSelectedALPNProtocol;
end;

function TWolfSSLConnection.GetBackendType: TSSLLibraryType;
begin
  Result := sslWolfSSL;
end;

function TWolfSSLConnection.IsNativeHandleValid: Boolean;
begin
  Result := FWolfSSL <> nil;
end;

function TWolfSSLConnection.GetLastError: Integer;
begin
  if FLastNativeError <> 0 then
    Result := FLastNativeError
  else if (FWolfSSL <> nil) and Assigned(wolfSSL_get_error) then
    Result := wolfSSL_get_error(FWolfSSL, 0)
  else
    Result := 0;
end;

function TWolfSSLConnection.GetLastErrorString: string;
var
  LError: Integer;
  LBuf: array[0..255] of AnsiChar;
begin
  Result := '';
  LError := GetLastError;
  if (LError <> 0) and Assigned(wolfSSL_ERR_error_string) then
  begin
    FillChar(LBuf, SizeOf(LBuf), 0);
    wolfSSL_ERR_error_string(LError, @LBuf[0]);
    Result := string(PAnsiChar(@LBuf[0]));
  end;
end;

end.
