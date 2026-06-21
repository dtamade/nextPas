unit nextpas.core.tls.dialer;

{$mode ObjFPC}{$H+}{$J-}

interface

uses
  nextpas.core.base, nextpas.core.tls.base, nextpas.core.tls.tls,
  nextpas.core.text.conv, nextpas.core.system.classes;

type
  TSSLDialResult = record
    Connection: ISSLConnection;
    Stream: IStream;
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
      out AStream: IStream; out AError: string): Boolean;
    function WrapSocket(ASocket: THandle; const AHostname: string): TSSLDialResult;

    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property Config: ISSLContext read FConfig;
  end;

implementation

uses nextpas.core.platform.socket, nextpas.core.net.base, nextpas.core.net.resolve, nextpas.core.tls.quick, nextpas.core.tls.connection.builder, nextpas.core.exception;

{ Helper: wrap a THandle back into TPlatformSocket for platform calls }
function HandleToSocket(AHandle: THandle): TPlatformSocket; inline;
begin
  Result.Value := {$IFDEF NEXTPAS_WINDOWS}PtrUInt{$ELSE}LongInt{$ENDIF}(AHandle);
end;

function ResolveAndConnect(const AHost: string; APort: Word;
  out ASocket: THandle; out AError: string): Boolean;
var
  LAddr: TNetAddress;
  LSock: TPlatformSocket;
  LSockAddr: TPlatformSockAddr;
  LAddrIpv4: UInt32;
  LErr: Int32;
begin
  ASocket := THandle(-1);
  AError := '';
  Result := False;

  LAddr := NetResolve(AHost);
  if LAddr.IP = '' then
  begin
    AError := 'DNS resolution failed for: ' + AHost;
    Exit;
  end;

  LErr := platform_socket_create(PLATFORM_AF_INET, PLATFORM_SOCK_STREAM, 0, LSock);
  if LErr <> 0 then
  begin
    AError := 'Socket creation failed';
    Exit;
  end;

  LErr := platform_socket_resolve_ipv4(PAnsiChar(AnsiString(LAddr.IP)), LAddrIpv4);
  if LErr <> 0 then
  begin
    platform_socket_close(LSock);
    AError := 'Address resolution failed for: ' + LAddr.IP;
    Exit;
  end;

  LErr := platform_sockaddr_ipv4(APort, LAddrIpv4, LSockAddr);
  if LErr <> 0 then
  begin
    platform_socket_close(LSock);
    AError := 'Sockaddr construction failed';
    Exit;
  end;

  LErr := platform_socket_connect(LSock, @LSockAddr.Storage, LSockAddr.Len);
  if LErr <> 0 then
  begin
    platform_socket_close(LSock);
    AError := 'TCP connect failed to ' + AHost + ':' + IntToStr(APort);
    Exit;
  end;

  ASocket := THandle(LSock.Value);
  Result := True;
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
  LSockToClose: TPlatformSocket;
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
      LSockToClose := HandleToSocket(LSocket);
      platform_socket_close(LSockToClose);
      Exit;
    end;

    Result.Stream := IStream.Create(Result.Connection);
  except
    on E: Exception do
    begin
      LSockToClose := HandleToSocket(LSocket);
      platform_socket_close(LSockToClose);
      Result.Error := TSSLOperationResult.Err(sslErrOther, E.Message);
    end;
  end;
end;

function TSSLDialer.TryDial(const AHost: string; APort: Word;
  out AStream: IStream; out AError: string): Boolean;
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
      Result.Stream := IStream.Create(Result.Connection);
  except
    on E: Exception do
      Result.Error := TSSLOperationResult.Err(sslErrOther, E.Message);
  end;
end;

end.
