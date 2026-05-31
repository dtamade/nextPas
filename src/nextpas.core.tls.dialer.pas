unit nextpas.core.tls.dialer;

{$mode ObjFPC}{$H+}{$J-}

interface

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.tls;

type
  TSSLDialResult = record
    Connection: ISSLConnection;
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

uses
  {$IFDEF UNIX}Sockets, BaseUnix, netdb,{$ENDIF}
  nextpas.core.tls.quick,
  nextpas.core.tls.connection.builder;

{$IFDEF UNIX}
function ResolveAndConnect(const AHost: string; APort: Word;
  out ASocket: THandle; out AError: string): Boolean;
var
  LSock: LongInt;
  LAddr: TInetSockAddr;
  LIP: in_addr;
  LHostEntry: THostEntry;
  LResolved: Boolean;
begin
  ASocket := THandle(-1);
  AError := '';
  Result := False;

  // Try as IP literal first
  LIP := StrToNetAddr(AHost);
  if LIP.s_addr = 0 then
  begin
    // DNS resolve
    LResolved := ResolveHostByName(AHost, LHostEntry);
    if not LResolved then
    begin
      AError := 'DNS resolution failed for: ' + AHost;
      Exit;
    end;
    LIP := LHostEntry.Addr;
  end;

  LSock := fpSocket(AF_INET, SOCK_STREAM, 0);
  if LSock < 0 then
  begin
    AError := 'Socket creation failed';
    Exit;
  end;

  FillChar(LAddr, SizeOf(LAddr), 0);
  LAddr.sin_family := AF_INET;
  LAddr.sin_port := htons(APort);
  LAddr.sin_addr := LIP;

  if fpConnect(LSock, @LAddr, SizeOf(LAddr)) <> 0 then
  begin
    fpClose(LSock);
    AError := 'TCP connect failed to ' + AHost + ':' + IntToStr(APort);
    Exit;
  end;

  ASocket := THandle(LSock);
  Result := True;
end;
{$ENDIF}

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

  {$IFDEF UNIX}
  if not ResolveAndConnect(AHost, APort, LSocket, LError) then
  begin
    Result.Error := TSSLOperationResult.Err(sslErrIO, LError);
    Exit;
  end;
  {$ELSE}
  Result.Error := TSSLOperationResult.Err(sslErrUnsupported, 'Dial not implemented for this platform');
  Exit;
  {$ENDIF}

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
      Result.Error := TSSLOperationResult.Err(sslErrOther, E.Message);
      {$IFDEF UNIX}fpClose(LongInt(LSocket));{$ENDIF}
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
