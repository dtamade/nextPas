unit nextpas.core.tls.freepascal.engine;

{$mode objfpc}{$H+}
{$WARN 5093 off}

interface

uses nextpas.core.base, nextpas.core.tls.base, nextpas.core.tls.engine; type TFreePascalEngine = class(TInterfacedObject, ISSLEngine) private FContext: ISSLContext;
    FRole: TSSLEngineRole;
    FConnection: ISSLConnection;
    FClientConnection: ISSLClientConnection;
    FHandshakeComplete: Boolean;
    FPlaintextOut: TBytes;
    FCiphertextOut: TBytes;
    FLastError: string;
    FLastErrorCode: TSSLErrorCode;
    FServerName: string;
    FALPNProtocols: string;
    FSocket: THandle;
  public
    constructor Create(AContext: ISSLContext; ARole: TSSLEngineRole; ASocket: THandle);
    destructor Destroy; override;

    procedure SetServerName(const AName: string);
    procedure SetALPNProtocols(const AProtocols: string);

    procedure InjectCiphertext(const AData: TBytes; AOffset, ALength: Integer);
    procedure InjectCiphertext(const AData: TBytes);

    function ProcessHandshake: TSSLEngineAction;

    function Encrypt(const APlaintext: TBytes; AOffset, ALength: Integer): TSSLEngineAction;
    function Encrypt(const APlaintext: TBytes): TSSLEngineAction;

    function Decrypt: TSSLEngineAction;

    function ExtractCiphertext: TBytes;
    function ExtractPlaintext: TBytes;

    function HasPendingCiphertext: Boolean;
    function HasPendingPlaintext: Boolean;
    function IsHandshakeComplete: Boolean;

    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
    function GetSelectedALPNProtocol: string;
    function GetLastError: string;
    function GetLastErrorCode: TSSLErrorCode;
  end;

function CreateFreePascalEngine(AContext: ISSLContext; ARole: TSSLEngineRole; ASocket: THandle): ISSLEngine;

implementation

uses nextpas.core.tls.freepascal.connection; constructor TFreePascalEngine.Create(AContext: ISSLContext; ARole: TSSLEngineRole; ASocket: THandle);
begin
  inherited Create;
  FContext := AContext;
  FRole := ARole;
  FSocket := ASocket;
  FHandshakeComplete := False;
  SetLength(FPlaintextOut, 0);
  SetLength(FCiphertextOut, 0);
  FLastError := '';
  FLastErrorCode := sslErrNone;
  FServerName := '';
  FALPNProtocols := '';
end;

destructor TFreePascalEngine.Destroy;
begin
  FConnection := nil;
  FClientConnection := nil;
  inherited Destroy;
end;

procedure TFreePascalEngine.SetServerName(const AName: string);
begin
  FServerName := AName;
end;

procedure TFreePascalEngine.SetALPNProtocols(const AProtocols: string);
begin
  FALPNProtocols := AProtocols;
end;

procedure TFreePascalEngine.InjectCiphertext(const AData: TBytes; AOffset, ALength: Integer);
begin
  // Not used in socket mode — data comes from the socket directly
end;

procedure TFreePascalEngine.InjectCiphertext(const AData: TBytes);
begin
  // Not used in socket mode
end;

function TFreePascalEngine.ProcessHandshake: TSSLEngineAction;
var
  LSuccess: Boolean;
begin
  if FHandshakeComplete then
    Exit(eaHandshakeComplete);

  if FConnection = nil then
  begin
    FConnection := FContext.CreateConnection(FSocket);
    if Supports(FConnection, ISSLClientConnection, FClientConnection) then
    begin
      if FServerName <> '' then
        FClientConnection.SetServerName(FServerName);
    end;
  end;

  try
    if FRole = erClient then
      LSuccess := FConnection.Connect
    else
      LSuccess := FConnection.Accept;
  except
    on E: Exception do
    begin
      FLastError := E.ClassName + ': ' + E.Message;
      FLastErrorCode := sslErrHandshake;
      Exit(eaError);
    end;
  end;

  if LSuccess then
  begin
    FHandshakeComplete := True;
    Exit(eaHandshakeComplete);
  end;

  FLastError := FConnection.GetVerifyResultString;
  FLastErrorCode := sslErrHandshake;
  Result := eaError;
end;

function TFreePascalEngine.Encrypt(const APlaintext: TBytes; AOffset, ALength: Integer): TSSLEngineAction;
var
  LWritten: Integer;
begin
  if not FHandshakeComplete then
  begin
    FLastError := 'Cannot encrypt before handshake is complete';
    FLastErrorCode := sslErrHandshake;
    Exit(eaError);
  end;

  LWritten := FConnection.Write(APlaintext[AOffset], ALength);
  if LWritten > 0 then
    Exit(eaNone);

  FLastError := 'Write failed';
  FLastErrorCode := sslErrIO;
  Result := eaError;
end;

function TFreePascalEngine.Encrypt(const APlaintext: TBytes): TSSLEngineAction;
begin
  Result := Encrypt(APlaintext, 0, Length(APlaintext));
end;

function TFreePascalEngine.Decrypt: TSSLEngineAction;
var
  LBuf: array[0..16383] of Byte;
  LRead: Integer;
begin
  if not FHandshakeComplete then
  begin
    FLastError := 'Cannot decrypt before handshake is complete';
    FLastErrorCode := sslErrHandshake;
    Exit(eaError);
  end;

  LRead := FConnection.Read(LBuf[0], SizeOf(LBuf));
  if LRead > 0 then
  begin
    SetLength(FPlaintextOut, Length(FPlaintextOut) + LRead);
    Move(LBuf[0], FPlaintextOut[Length(FPlaintextOut) - LRead], LRead);
    Exit(eaHasPlaintext);
  end;

  if LRead = 0 then
    Exit(eaClosed);

  Result := eaNeedMoreInput;
end;

function TFreePascalEngine.ExtractCiphertext: TBytes;
begin
  Result := FCiphertextOut;
  SetLength(FCiphertextOut, 0);
end;

function TFreePascalEngine.ExtractPlaintext: TBytes;
begin
  Result := FPlaintextOut;
  SetLength(FPlaintextOut, 0);
end;

function TFreePascalEngine.HasPendingCiphertext: Boolean;
begin
  Result := Length(FCiphertextOut) > 0;
end;

function TFreePascalEngine.HasPendingPlaintext: Boolean;
begin
  Result := Length(FPlaintextOut) > 0;
end;

function TFreePascalEngine.IsHandshakeComplete: Boolean;
begin
  Result := FHandshakeComplete;
end;

function TFreePascalEngine.GetProtocolVersion: TSSLProtocolVersion;
begin
  if FConnection <> nil then
    Result := FConnection.GetProtocolVersion
  else
    Result := sslProtocolUnknown;
end;

function TFreePascalEngine.GetCipherName: string;
begin
  if FConnection <> nil then
    Result := FConnection.GetCipherName
  else
    Result := '';
end;

function TFreePascalEngine.GetPeerCertificate: ISSLCertificate;
begin
  if FConnection <> nil then
    Result := FConnection.GetPeerCertificate
  else
    Result := nil;
end;

function TFreePascalEngine.GetSelectedALPNProtocol: string;
begin
  if FConnection <> nil then
    Result := FConnection.GetSelectedALPNProtocol
  else
    Result := '';
end;

function TFreePascalEngine.GetLastError: string;
begin
  Result := FLastError;
end;

function TFreePascalEngine.GetLastErrorCode: TSSLErrorCode;
begin
  Result := FLastErrorCode;
end;

function CreateFreePascalEngine(AContext: ISSLContext; ARole: TSSLEngineRole; ASocket: THandle): ISSLEngine;
begin
  Result := TFreePascalEngine.Create(AContext, ARole, ASocket);
end;

end.
