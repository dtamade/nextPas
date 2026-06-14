unit nextpas.core.tls.dialer;

{$mode ObjFPC}{$H+}{$J-}

interface

uses nextpas.core.tls.base, nextpas.core.tls.tls, nextpas.core.text.conv; type TSSLDialResult = record Connection: ISSLConnection;
    Stream: TSSLStream;
    Error: TSSLOperationResult;
  end;

  TSSLDialer = class
  private
    FConfig: ISSLContext;
    FTimeoutMs: Integer;
  public
    constructor Create(AConfig: ISSLContext);
    constructor CreateDefault;
    destructor Destroy; override;

    function Dial(const AHost: string; APort: Word): TSSLDialResult;
    function TryDial(const AHost: string; APort: Word;
      out AStream: TSSLStream; out AError: string): Boolean;
    function WrapSocket(ASocket: THandle; const AHostname: string): TSSLDialResult;

    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property Config: ISSLContext read FConfig;
  end;

implementation

uses Sockets, BaseUnix, WinSock2, nextpas.core.net.base, nextpas.core.net.resolve, nextpas.core.tls.quick, nextpas.core.tls.connection.builder, nextpas.core.text.conv; function ResolveAndConnect(const AHost: string; APort: Word;
  out ASocket: THandle; out AError: string): Boolean;
var
  LAddr: TNetAddress;
  {$IFDEF UNIX}
  LSock: LongInt;
  LSockAddr: TInetSockAddr;
  {$ENDIF}
begin
  ASocket := THandle(-1);
  AError := '';
  Result := False;

  // Use framework DNS resolver
  LAddr := NetResolve(AHost);
  if LAddr.IP = '' then
  begin
    AError := 'DNS resolution failed for: ' + AHost;
    Exit;
  end;

  {$IFDEF UNIX}
  LSock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if LSock < 0 then
  begin
    AError := 'Socket creation failed';
    Exit;
  end;

  FillChar(LSockAddr, SizeOf(LSockAddr), 0);
  LSockAddr.sin_family := AF_INET;
  LSockAddr.sin_port := htons(APort);
  LSockAddr.sin_addr := StrToNetAddr(LAddr.IP);

  if fpConnect(LSock, @LSockAddr, SizeOf(LSockAddr)) <> 0 then
  begin
    fpClose(LSock);
    AError := 'TCP connect failed to ' + AHost + ':' + IntToStr(APort);
    Exit;
  end;

  ASocket := THandle(LSock);
  Result := True;
  {$ELSE}
  AError := 'Platform not yet supported for TLS dialer';
  {$ENDIF}
end;

constructor TSSLDialer.Create(AConfig: ISSLContext);
begin
  inherited Create;
  FConfig := AConfig;
  FTimeoutMs := 30000;
end;

constructor TSSLDialer.CreateDefault;
begin
  inherited Create;
  FConfig := TSSLQuick.SecureClient;
  FTimeoutMs := 30000;
end;

destructor TSSLDialer.Destroy;
begin
  FConfig := nil;
  inherited Destroy;
end;

function TSSLDialer.Dial(const AHost: string; APort: Word): TSSLDialResult;
var
  LSocket: THandle;
  LError: string;
  LBuilder: ISSLConnectionBuilder;
begin
  Result.Connection := nil;
  Result.Stream := nil;
  Result.Error := TSSLOperationResult.Ok;

  if AHost = '' then
  begin
    Result.Error := TSSLOperationResult.Err(sslErrIO, 'TLS dial: empty hostname');
    Exit;
  end;

  if APort = 0 then
  begin
    Result.Error := TSSLOperationResult.Err(sslErrIO, 'TLS dial: port cannot be 0');
    Exit;
  end;

  if not ResolveAndConnect(AHost, APort, LSocket, LError) then
  begin
    Result.Error := TSSLOperationResult.Err(sslErrIO, LError);
    Exit;
  end;

  try
    LBuilder := TSSLConnectionBuilder.CreateWithContext(FConfig);
    LBuilder.WithSocket(LSocket);
    LBuilder.WithHostname(AHost);
    if FTimeoutMs > 0 then
      LBuilder.WithTimeout(FTimeoutMs);

    Result.Error := LBuilder.TryBuildClient(Result.Connection);
    if Result.Error.IsErr then
    begin
      {$IFDEF UNIX}fpClose(LongInt(LSocket));{$ENDIF}
      Exit;
    end;

    Result.Stream := TSSLStream.Create(Result.Connection);
  except
    on E: Exception do
    begin
      {$IFDEF UNIX}fpClose(LongInt(LSocket));{$ENDIF}
      Result.Error := TSSLOperationResult.Err(sslErrOther, E.Message);
    end;
  end;
end;

function TSSLDialer.TryDial(const AHost: string; APort: Word;
  out AStream: TSSLStream; out AError: string): Boolean;
var
  LResult: TSSLDialResult;
begin
  AStream := nil;
  AError := '';
  LResult := Dial(AHost, APort);
  if LResult.Error.IsErr then
  begin
    AError := LResult.Error.ErrorMessage;
    Result := False;
  end
  else
  begin
    AStream := LResult.Stream;
    Result := True;
  end;
end;

function TSSLDialer.WrapSocket(ASocket: THandle; const AHostname: string): TSSLDialResult;
var
  LBuilder: ISSLConnectionBuilder;
begin
  Result.Connection := nil;
  Result.Stream := nil;
  Result.Error := TSSLOperationResult.Ok;

  try
    LBuilder := TSSLConnectionBuilder.CreateWithContext(FConfig);
    LBuilder.WithSocket(ASocket);
    LBuilder.WithHostname(AHostname);
    if FTimeoutMs > 0 then
      LBuilder.WithTimeout(FTimeoutMs);

    Result.Error := LBuilder.TryBuildClient(Result.Connection);
    if Result.Error.IsOk then
      Result.Stream := TSSLStream.Create(Result.Connection);
  except
    on E: Exception do
      Result.Error := TSSLOperationResult.Err(sslErrOther, E.Message);
  end;
end;

end.
