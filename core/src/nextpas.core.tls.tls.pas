{
  nextpas.core.tls.tls - Rust 风格 TLS 门面（Connector/Acceptor + Stream）

  目标:
    - 提供更贴近 rustls / tokio-rustls 的使用体验：
      * TSSLConnector：客户端连接器
      * TSSLAcceptor：服务端接收器
      * TSSLStream：将 ISSLConnection 封装为 TStream

  重要语义:
    - SNI/hostname 属于“连接级别”配置。
      使用 ISSLClientConnection.SetServerName，而不是把 hostname 存在共享 ISSLContext 上。

  版本: 1.0
  创建: 2025-12-31
}

unit nextpas.core.tls.tls;

{$mode ObjFPC}{$H+}
{$modeswitch advancedrecords}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

interface

uses
  nextpas.core.exception, nextpas.core.base.utils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.pending,
  nextpas.core.tls.safety,
  nextpas.core.tls.exceptions;

type
  { TSSLStream - 将 ISSLConnection 封装为 TStream }
  TSSLStream = class(TStream)
  private
    FConnection: ISSLConnection;
  public
    constructor Create(AConnection: ISSLConnection);
    destructor Destroy; override;

    function Read(var Buffer; Count: Longint): Longint; override;
    function Write(const Buffer; Count: Longint): Longint; override;
    function Seek(const Offset: Int64; Origin: TSeekOrigin): Int64; override;

    procedure Close;
    procedure SetReadTimeout(AMs: Integer);
    procedure SetWriteTimeout(AMs: Integer);
    function GetSelectedALPN: string;

    property Connection: ISSLConnection read FConnection;
  end;

  { TSSLConnector - 客户端连接器（Rust 风格门面） }
  TSSLConnector = record
  private
    FContext: ISSLContext;
    FTimeout: Integer;
    FHandshakeTimeout: Integer;
    FReadTimeout: Integer;
    FWriteTimeout: Integer;
    FBlocking: Boolean;
    FSession: ISSLSession;
    FSessionReuse: Boolean;
    FEarlyData: TBytes;
    FALPN: string;

    procedure ApplyClientOptions(AConn: ISSLConnection; const AServerName: string);
    function TryQueueEarlyData(AConn: ISSLConnection): TSSLOperationResult;
  public
    class function FromContext(AContext: ISSLContext): TSSLConnector; static;

    function WithTimeout(AMs: Integer): TSSLConnector; overload;
    function WithTimeout(const ATimeout: TTimeoutDuration): TSSLConnector; overload;
    function WithHandshakeTimeout(AMs: Integer): TSSLConnector;
    function WithReadTimeout(AMs: Integer): TSSLConnector;
    function WithWriteTimeout(AMs: Integer): TSSLConnector;
    function WithBlocking(ABlocking: Boolean): TSSLConnector;
    function WithSession(ASession: ISSLSession): TSSLConnector;
    function WithSessionReuse(AEnabled: Boolean): TSSLConnector;
    function WithEarlyData(const AData: TBytes): TSSLConnector;
    function WithALPN(const AProtocols: string): TSSLConnector;

    function ConnectSocket(ASocket: THandle; const AServerName: string): TSSLStream;
    function TryConnectSocket(ASocket: THandle; const AServerName: string;
      out AStream: TSSLStream): TSSLOperationResult;

    function ConnectStream(ATransport: TStream; const AServerName: string): TSSLStream;
    function TryConnectStream(ATransport: TStream; const AServerName: string;
      out AStream: TSSLStream): TSSLOperationResult;

    function BeginConnectSocket(ASocket: THandle; const AServerName: string): TSSLPendingClientConnect;
  end;

  { TSSLAcceptor - 服务端接收器（Rust 风格门面） }
  TSSLAcceptor = record
  private
    FContext: ISSLContext;
    FTimeout: Integer;
    FBlocking: Boolean;

    procedure ApplyServerOptions(AConn: ISSLConnection);
  public
    class function FromContext(AContext: ISSLContext): TSSLAcceptor; static;

    function WithTimeout(AMs: Integer): TSSLAcceptor; overload;
    function WithTimeout(const ATimeout: TTimeoutDuration): TSSLAcceptor; overload;
    function WithBlocking(ABlocking: Boolean): TSSLAcceptor;

    function AcceptSocket(ASocket: THandle): TSSLStream;
    function TryAcceptSocket(ASocket: THandle; out AStream: TSSLStream): TSSLOperationResult;

    function AcceptStream(ATransport: TStream): TSSLStream;
    function TryAcceptStream(ATransport: TStream; out AStream: TSSLStream): TSSLOperationResult;
  end;

implementation

function TimeoutDurationToConnectionTimeout(
  const ATimeout: TTimeoutDuration): Integer;
var
  LMilliseconds: Int64;
begin
  if ATimeout.IsInfinite then
    Exit(-1);

  LMilliseconds := ATimeout.ToMilliseconds;
  if (LMilliseconds < Low(Integer)) or (LMilliseconds > High(Integer)) then
    raise ESSLInvalidArgument.Create(
      'Timeout duration exceeds Integer millisecond range',
      sslErrInvalidParam
    );

  Result := Integer(LMilliseconds);
end;

procedure ReadConnectionVerificationSurface(
  AConn: ISSLConnection;
  out AVerifyRes: Integer;
  out AVerifyStr: string
);
var
  LCertVerify: ISSLCertificateVerification;
begin
  AVerifyRes := 0;
  AVerifyStr := '';
  if AConn = nil then
    Exit;

  if Supports(AConn, ISSLCertificateVerification, LCertVerify) then
  begin
    AVerifyRes := LCertVerify.GetVerifyResult;
    AVerifyStr := LCertVerify.GetVerifyResultString;
  end
  else
  begin
    {$PUSH}{$WARN 6058 off}{$WARN SYMBOL_DEPRECATED OFF}
    AVerifyRes := AConn.GetVerifyResult;
    AVerifyStr := AConn.GetVerifyResultString;
    {$POP}
  end;
end;

procedure ApplyConnectionControlOverrides(
  AConn: ISSLConnection;
  ATimeout: Integer;
  ABlocking: Boolean
);
var
  LConnectionControl: ISSLConnectionControl;
begin
  if AConn = nil then
    Exit;

  if Supports(AConn, ISSLConnectionControl, LConnectionControl) then
  begin
    LConnectionControl.SetTimeout(ATimeout);
    LConnectionControl.SetBlocking(ABlocking);
  end
  else
  begin
    AConn.SetTimeout(ATimeout);
    AConn.SetBlocking(ABlocking);
  end;
end;

{ TSSLStream }

constructor TSSLStream.Create(AConnection: ISSLConnection);
begin
  inherited Create;
  if AConnection = nil then
    raise ESSLException.CreateWithContext(
      'SSL connection is required',
      sslErrInvalidParam,
      'TSSLStream.Create'
    );
  FConnection := AConnection;
end;

destructor TSSLStream.Destroy;
begin
  try
    Close;
  except
    // best-effort cleanup
  end;
  inherited Destroy;
end;

function TSSLStream.Read(var Buffer; Count: Longint): Longint;
var
  R: Integer;
begin
  if FConnection = nil then
    Exit(0);

  R := FConnection.Read(Buffer, Count);
  if R < 0 then
    raise ESSLConnectionException.CreateWithContext(
      'TLS read failed',
      FConnection.GetError(R),
      'TSSLStream.Read'
    );
  Result := R;
end;

function TSSLStream.Write(const Buffer; Count: Longint): Longint;
var
  R: Integer;
begin
  if FConnection = nil then
    Exit(0);

  R := FConnection.Write(Buffer, Count);
  if R < 0 then
    raise ESSLConnectionException.CreateWithContext(
      'TLS write failed',
      FConnection.GetError(R),
      'TSSLStream.Write'
    );
  Result := R;
end;

function TSSLStream.Seek(const Offset: Int64; Origin: TSeekOrigin): Int64;
begin
  // TLS/SSL 连接是流式的，不支持 seek。
  Result := 0;
  raise EStreamError.Create('TLS stream is not seekable');
end;

procedure TSSLStream.Close;
begin
  if FConnection <> nil then
  begin
    try
      FConnection.Shutdown;
    except
      // ignore
    end;
    try
      FConnection.Close;
    except
      // ignore
    end;
  end;
end;

procedure TSSLStream.SetReadTimeout(AMs: Integer);
begin
  if FConnection <> nil then
    FConnection.SetTimeout(AMs);
end;

procedure TSSLStream.SetWriteTimeout(AMs: Integer);
begin
  if FConnection <> nil then
    FConnection.SetTimeout(AMs);
end;

function TSSLStream.GetSelectedALPN: string;
var
  LInfo: ISSLConnectionInfo;
begin
  Result := '';
  if (FConnection <> nil) and Supports(FConnection, ISSLConnectionInfo, LInfo) then
    Result := LInfo.GetSelectedALPNProtocol;
end;

{ TSSLConnector }

class function TSSLConnector.FromContext(AContext: ISSLContext): TSSLConnector;
begin
  Result.FContext := nil;
  Result.FTimeout := 0;
  Result.FBlocking := False;
  Result.FSession := nil;
  Result.FSessionReuse := False;
  SetLength(Result.FEarlyData, 0);

  Result.FContext := AContext;
  Result.FTimeout := SSL_DEFAULT_HANDSHAKE_TIMEOUT;
  Result.FBlocking := True;
  Result.FSession := nil;
  Result.FSessionReuse := True;
  SetLength(Result.FEarlyData, 0);
end;

function TSSLConnector.WithTimeout(AMs: Integer): TSSLConnector;
begin
  Result := Self;
  Result.FTimeout := AMs;
end;

function TSSLConnector.WithTimeout(const ATimeout: TTimeoutDuration): TSSLConnector;
begin
  Result := WithTimeout(TimeoutDurationToConnectionTimeout(ATimeout));
end;

function TSSLConnector.WithBlocking(ABlocking: Boolean): TSSLConnector;
begin
  Result := Self;
  Result.FBlocking := ABlocking;
end;

function TSSLConnector.WithSession(ASession: ISSLSession): TSSLConnector;
begin
  Result := Self;
  Result.FSession := ASession;
end;

function TSSLConnector.WithSessionReuse(AEnabled: Boolean): TSSLConnector;
begin
  Result := Self;
  Result.FSessionReuse := AEnabled;
end;

function TSSLConnector.WithEarlyData(const AData: TBytes): TSSLConnector;
begin
  Result := Self;
  Result.FEarlyData := Copy(AData);
end;

function TSSLConnector.WithHandshakeTimeout(AMs: Integer): TSSLConnector;
begin
  Result := Self;
  Result.FHandshakeTimeout := AMs;
end;

function TSSLConnector.WithReadTimeout(AMs: Integer): TSSLConnector;
begin
  Result := Self;
  Result.FReadTimeout := AMs;
end;

function TSSLConnector.WithWriteTimeout(AMs: Integer): TSSLConnector;
begin
  Result := Self;
  Result.FWriteTimeout := AMs;
end;

function TSSLConnector.WithALPN(const AProtocols: string): TSSLConnector;
begin
  Result := Self;
  Result.FALPN := AProtocols;
end;

procedure TSSLConnector.ApplyClientOptions(AConn: ISSLConnection; const AServerName: string);
var
  ClientConn: ISSLClientConnection;
  SessionResumption: ISSLSessionResumption;
begin
  if AConn = nil then
    Exit;

  ApplyConnectionControlOverrides(AConn, FTimeout, FBlocking);

  if FSessionReuse and (FSession <> nil) then
  begin
    if not Supports(AConn, ISSLSessionResumption, SessionResumption) then
      raise ESSLException.CreateWithContext(
        'Backend does not expose ISSLSessionResumption for session reuse',
        sslErrUnsupported,
        'TSSLConnector.ApplyClientOptions'
      );
    SessionResumption.SetSession(FSession);
  end;

  if Supports(AConn, ISSLClientConnection, ClientConn) then
    ClientConn.SetServerName(AServerName)
  else if AServerName <> '' then
    raise ESSLException.CreateWithContext(
      'Backend does not support per-connection server name',
      sslErrUnsupported,
      'TSSLConnector.ApplyClientOptions'
    );
end;

function TSSLConnector.TryQueueEarlyData(AConn: ISSLConnection): TSSLOperationResult;
var
  EarlyDataConn: ISSLEarlyDataConnection;
begin
  if Length(FEarlyData) = 0 then
    Exit(TSSLOperationResult.Ok);

  if not Supports(AConn, ISSLEarlyDataConnection, EarlyDataConn) then
    Exit(TSSLOperationResult.Err(
      sslErrUnsupported,
      'Connection does not expose early-data interface'
    ));

  Result := EarlyDataConn.SetEarlyData(FEarlyData);
end;

function TSSLConnector.TryConnectSocket(ASocket: THandle; const AServerName: string;
  out AStream: TSSLStream): TSSLOperationResult;
var
  Conn: ISSLConnection;
  QueueRes: TSSLOperationResult;
  VerifyRes: Integer;
  VerifyStr: string;
begin
  AStream := nil;

  if FContext = nil then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Context is required'));

  if ASocket = THandle(-1) then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Socket is required'));

  try
    Conn := FContext.CreateConnection(ASocket);
    if Conn = nil then
      Exit(TSSLOperationResult.Err(sslErrConnection, 'Failed to create connection'));

    ApplyClientOptions(Conn, AServerName);
    QueueRes := TryQueueEarlyData(Conn);
    if not QueueRes.Success then
    begin
      try
        Conn.Close;
      except
        // best-effort cleanup
      end;
      Exit(QueueRes);
    end;

    if not Conn.Connect then
    begin
      ReadConnectionVerificationSurface(Conn, VerifyRes, VerifyStr);

      try
        Conn.Close;
      except
        // best-effort cleanup
      end;

      if VerifyRes <> 0 then
        Exit(TSSLOperationResult.Err(sslErrVerificationFailed, 'Client handshake failed: ' + VerifyStr));
      Exit(TSSLOperationResult.Err(sslErrHandshake, 'Client handshake failed: ' + VerifyStr));
    end;

    AStream := TSSLStream.Create(Conn);
    Result := TSSLOperationResult.Ok;
  except
    on E: ESSLException do
      Result := TSSLOperationResult.Err(E.ErrorCode, E.Message);
    on E: Exception do
      Result := TSSLOperationResult.Err(sslErrGeneral, E.Message);
  end;
end;

function TSSLConnector.ConnectSocket(ASocket: THandle; const AServerName: string): TSSLStream;
var
  R: TSSLOperationResult;
begin
  R := TryConnectSocket(ASocket, AServerName, Result);
  if not R.Success then
    raise ESSLConnectionException.CreateWithContext(
      R.ErrorMessage,
      R.ErrorCode,
      'TSSLConnector.ConnectSocket'
    );
end;

function TSSLConnector.TryConnectStream(ATransport: TStream; const AServerName: string;
  out AStream: TSSLStream): TSSLOperationResult;
var
  Conn: ISSLConnection;
  QueueRes: TSSLOperationResult;
  VerifyRes: Integer;
  VerifyStr: string;
begin
  AStream := nil;

  if FContext = nil then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Context is required'));

  if ATransport = nil then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Stream is required'));

  try
    Conn := FContext.CreateConnection(ATransport);
    if Conn = nil then
      Exit(TSSLOperationResult.Err(sslErrConnection, 'Failed to create connection'));

    ApplyClientOptions(Conn, AServerName);
    QueueRes := TryQueueEarlyData(Conn);
    if not QueueRes.Success then
    begin
      try
        Conn.Close;
      except
        // best-effort cleanup
      end;
      Exit(QueueRes);
    end;

    if not Conn.Connect then
    begin
      ReadConnectionVerificationSurface(Conn, VerifyRes, VerifyStr);

      try
        Conn.Close;
      except
        // best-effort cleanup
      end;

      if VerifyRes <> 0 then
        Exit(TSSLOperationResult.Err(sslErrVerificationFailed, 'Client handshake failed: ' + VerifyStr));
      Exit(TSSLOperationResult.Err(sslErrHandshake, 'Client handshake failed: ' + VerifyStr));
    end;

    AStream := TSSLStream.Create(Conn);
    Result := TSSLOperationResult.Ok;
  except
    on E: ESSLException do
      Result := TSSLOperationResult.Err(E.ErrorCode, E.Message);
    on E: Exception do
      Result := TSSLOperationResult.Err(sslErrGeneral, E.Message);
  end;
end;

function TSSLConnector.ConnectStream(ATransport: TStream; const AServerName: string): TSSLStream;
var
  R: TSSLOperationResult;
begin
  R := TryConnectStream(ATransport, AServerName, Result);
  if not R.Success then
    raise ESSLConnectionException.CreateWithContext(
      R.ErrorMessage,
      R.ErrorCode,
      'TSSLConnector.ConnectStream'
    );
end;

function TSSLConnector.BeginConnectSocket(ASocket: THandle;
  const AServerName: string): TSSLPendingClientConnect;
var
  LConn: ISSLConnection;
begin
  LConn := FContext.CreateConnection(ASocket);
  ApplyClientOptions(LConn, AServerName);
  LConn.SetBlocking(False);
  Result := TSSLPendingClientConnect.Create(LConn);
end;

{ TSSLAcceptor }

class function TSSLAcceptor.FromContext(AContext: ISSLContext): TSSLAcceptor;
begin
  Result.FContext := nil;
  Result.FTimeout := 0;
  Result.FBlocking := False;

  Result.FContext := AContext;
  Result.FTimeout := SSL_DEFAULT_HANDSHAKE_TIMEOUT;
  Result.FBlocking := True;
end;

function TSSLAcceptor.WithTimeout(AMs: Integer): TSSLAcceptor;
begin
  Result := Self;
  Result.FTimeout := AMs;
end;

function TSSLAcceptor.WithTimeout(const ATimeout: TTimeoutDuration): TSSLAcceptor;
begin
  Result := WithTimeout(TimeoutDurationToConnectionTimeout(ATimeout));
end;

function TSSLAcceptor.WithBlocking(ABlocking: Boolean): TSSLAcceptor;
begin
  Result := Self;
  Result.FBlocking := ABlocking;
end;

procedure TSSLAcceptor.ApplyServerOptions(AConn: ISSLConnection);
begin
  if AConn = nil then
    Exit;

  ApplyConnectionControlOverrides(AConn, FTimeout, FBlocking);
end;

function TSSLAcceptor.TryAcceptSocket(ASocket: THandle; out AStream: TSSLStream): TSSLOperationResult;
var
  Conn: ISSLConnection;
  VerifyRes: Integer;
  VerifyStr: string;
begin
  AStream := nil;

  if FContext = nil then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Context is required'));

  if ASocket = THandle(-1) then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Socket is required'));

  try
    Conn := FContext.CreateConnection(ASocket);
    if Conn = nil then
      Exit(TSSLOperationResult.Err(sslErrConnection, 'Failed to create connection'));

    ApplyServerOptions(Conn);

    if not Conn.Accept then
    begin
      ReadConnectionVerificationSurface(Conn, VerifyRes, VerifyStr);

      try
        Conn.Close;
      except
        // best-effort cleanup
      end;

      if VerifyRes <> 0 then
        Exit(TSSLOperationResult.Err(sslErrVerificationFailed, 'Server accept failed: ' + VerifyStr));
      Exit(TSSLOperationResult.Err(sslErrHandshake, 'Server accept failed: ' + VerifyStr));
    end;

    AStream := TSSLStream.Create(Conn);
    Result := TSSLOperationResult.Ok;
  except
    on E: ESSLException do
      Result := TSSLOperationResult.Err(E.ErrorCode, E.Message);
    on E: Exception do
      Result := TSSLOperationResult.Err(sslErrGeneral, E.Message);
  end;
end;

function TSSLAcceptor.AcceptSocket(ASocket: THandle): TSSLStream;
var
  R: TSSLOperationResult;
begin
  R := TryAcceptSocket(ASocket, Result);
  if not R.Success then
    raise ESSLConnectionException.CreateWithContext(
      R.ErrorMessage,
      R.ErrorCode,
      'TSSLAcceptor.AcceptSocket'
    );
end;

function TSSLAcceptor.TryAcceptStream(ATransport: TStream; out AStream: TSSLStream): TSSLOperationResult;
var
  Conn: ISSLConnection;
  VerifyRes: Integer;
  VerifyStr: string;
begin
  AStream := nil;

  if FContext = nil then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Context is required'));

  if ATransport = nil then
    Exit(TSSLOperationResult.Err(sslErrInvalidParam, 'Stream is required'));

  try
    Conn := FContext.CreateConnection(ATransport);
    if Conn = nil then
      Exit(TSSLOperationResult.Err(sslErrConnection, 'Failed to create connection'));

    ApplyServerOptions(Conn);

    if not Conn.Accept then
    begin
      ReadConnectionVerificationSurface(Conn, VerifyRes, VerifyStr);

      try
        Conn.Close;
      except
        // best-effort cleanup
      end;

      if VerifyRes <> 0 then
        Exit(TSSLOperationResult.Err(sslErrVerificationFailed, 'Server accept failed: ' + VerifyStr));
      Exit(TSSLOperationResult.Err(sslErrHandshake, 'Server accept failed: ' + VerifyStr));
    end;

    AStream := TSSLStream.Create(Conn);
    Result := TSSLOperationResult.Ok;
  except
    on E: ESSLException do
      Result := TSSLOperationResult.Err(E.ErrorCode, E.Message);
    on E: Exception do
      Result := TSSLOperationResult.Err(sslErrGeneral, E.Message);
  end;
end;

function TSSLAcceptor.AcceptStream(ATransport: TStream): TSSLStream;
var
  R: TSSLOperationResult;
begin
  R := TryAcceptStream(ATransport, Result);
  if not R.Success then
    raise ESSLConnectionException.CreateWithContext(
      R.ErrorMessage,
      R.ErrorCode,
      'TSSLAcceptor.AcceptStream'
    );
end;

end.
