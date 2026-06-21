unit nextpas.core.tls.pending;

{$mode ObjFPC}{$H+}{$J-}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  
  Classes,
  nextpas.core.io.intf,
  nextpas.core.tls.base,
  nextpas.core.tls.exceptions;

type
  TSSLPendingClientConnect = class
  private
    FConnection: ISSLConnection;
    FCompleted: Boolean;
    FError: TSSLOperationResult;
  public
    constructor Create(AConnection: ISSLConnection);
    destructor Destroy; override;

    function Poll: TSSLHandshakeStepResult;
    function IsComplete: Boolean;
    function FinishIStream: IStream;
    function TryFinishIStream(out AStream: IStream): TSSLOperationResult;
    function FinishStream: IStream;
    function TryFinishStream(out AStream: IStream): TSSLOperationResult;
    procedure Cancel;

    property Connection: ISSLConnection read FConnection;
  end;

implementation

uses
  nextpas.core.io.stream_adapter,
  nextpas.core.tls.tls;

constructor TSSLPendingClientConnect.Create(AConnection: ISSLConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FCompleted := False;
  FError := TSSLOperationResult.Ok;
end;

destructor TSSLPendingClientConnect.Destroy;
begin
  if (not FCompleted) and (FConnection <> nil) then
  begin
    try FConnection.Close; except end;
  end;
  FConnection := nil;
  inherited Destroy;
end;

function TSSLPendingClientConnect.Poll: TSSLHandshakeStepResult;
var
  LState: TSSLHandshakeState;
begin
  Result.Progress := sslHandshakeFailed;
  Result.ErrorCode := sslErrNone;
  Result.ErrorMessage := '';

  if FCompleted then
  begin
    Result.Progress := sslHandshakeComplete;
    Exit;
  end;

  if FConnection = nil then
  begin
    Result.ErrorCode := sslErrOther;
    Result.ErrorMessage := 'No connection';
    Exit;
  end;

  LState := FConnection.DoHandshake;
  case LState of
    sslHsCompleted:
      begin
        FCompleted := True;
        Result.Progress := sslHandshakeComplete;
      end;
    sslHsInProgress, sslHsNotStarted:
      begin
        if FConnection.WantRead then
          Result.Progress := sslHandshakeWantRead
        else if FConnection.WantWrite then
          Result.Progress := sslHandshakeWantWrite
        else
          Result.Progress := sslHandshakeWantRead;
      end;
  else
    begin
      Result.Progress := sslHandshakeFailed;
      Result.ErrorCode := sslErrHandshake;
      Result.ErrorMessage := 'Handshake failed';
    end;
  end;
end;

function TSSLPendingClientConnect.IsComplete: Boolean;
begin
  Result := FCompleted;
end;

function TSSLPendingClientConnect.FinishIStream: IStream;
begin
  if not FCompleted then
    raise ESSLException.Create('Handshake not complete');
  Result := WrapIStream(TSSLStream.Create(FConnection), True);
end;

function TSSLPendingClientConnect.TryFinishIStream(out AStream: IStream): TSSLOperationResult;
begin
  AStream := nil;
  if not FCompleted then
    Exit(TSSLOperationResult.Err(sslErrHandshake, 'Handshake not complete'));
  AStream := WrapIStream(TSSLStream.Create(FConnection), True);
  Result := TSSLOperationResult.Ok;
end;

function TSSLPendingClientConnect.FinishStream: IStream;
begin
  Result := WrapIStream(FinishIStream);
end;

function TSSLPendingClientConnect.TryFinishStream(out AStream: IStream): TSSLOperationResult;
var
  LIStream: IStream;
begin
  AStream := nil;
  Result := TryFinishIStream(LIStream);
  if Result.IsOk then
    AStream := WrapIStream(LIStream);
end;

procedure TSSLPendingClientConnect.Cancel;
begin
  if FConnection <> nil then
  begin
    try FConnection.Close; except end;
    FConnection := nil;
  end;
  FCompleted := False;
end;

end.
