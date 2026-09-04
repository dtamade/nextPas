unit nextpas.core.websocket.upstream;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.thread.base,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.websocket;

type
  TUpstreamWsHeader = TWebSocketHeader;

  TUpstreamWsOptions = record
    Url: string;
    Headers: array of TWebSocketHeader;
    Subprotocols: array of string;
    PerMessageDeflate: Boolean;
    class function Create(const AUrl: string): TUpstreamWsOptions; static;
    function WithHeader(const AName, AValue: string): TUpstreamWsOptions;
    function WithSubprotocol(const AProtocol: string): TUpstreamWsOptions;
    function WithPerMessageDeflate(const AEnable: Boolean): TUpstreamWsOptions;
    function ToWebSocketOptions: TWebSocketOptions;
  end;

  TUpstreamWsReconnectPolicy = record
    MaxRetries: Integer;
    BaseMs: Integer;
    MaxMs: Integer;
    class function Default: TUpstreamWsReconnectPolicy; static;
    function ShouldRetry(const AAttempt: Integer): Boolean;
    function DelayMs(const AAttempt: Integer): Integer;
  end;

  TUpstreamWsOnFrame = procedure(const AFrame: TWebSocketFrame) of object;

  TUpstreamWsSession = class
  private
    FOptions: TUpstreamWsOptions;
    FPolicy: TUpstreamWsReconnectPolicy;
    FOnFrame: TUpstreamWsOnFrame;
    FSocket: IWebSocket;
    FReader: TWorkerThread;
    procedure StartReader;
    procedure StopReader;
    function GetIsConnected: Boolean;
  public
    constructor Create(const AOptions: TUpstreamWsOptions); overload;
    constructor Create(const AOptions: TUpstreamWsOptions;
      const APolicy: TUpstreamWsReconnectPolicy); overload;
    destructor Destroy; override;
    property Options: TUpstreamWsOptions read FOptions write FOptions;
    property ReconnectPolicy: TUpstreamWsReconnectPolicy read FPolicy write FPolicy;
    property OnFrame: TUpstreamWsOnFrame read FOnFrame write FOnFrame;
    property IsConnected: Boolean read GetIsConnected;
    procedure Connect;
    procedure Close;
    procedure SendText(const AText: string);
    procedure SendBinary(const AData: TBytes);
    function BuildWebSocketOptions: TWebSocketOptions;
    function ReconnectDelayMs(const AAttempt: Integer): Integer;
    function ShouldRetry(const AAttempt: Integer): Boolean;
  end;

implementation

uses
  nextpas.core.http.intf;

type
  TUpstreamWsReaderThread = class(TWorkerThread)
  private
    FSession: TUpstreamWsSession;
  protected
    procedure Execute; override;
  public
    constructor Create(ASession: TUpstreamWsSession);
  end;

constructor TUpstreamWsReaderThread.Create(ASession: TUpstreamWsSession);
begin
  inherited Create;
  FSession := ASession;
end;

procedure TUpstreamWsReaderThread.Execute;
var
  LFrame: TWebSocketFrame;
begin
  while not Terminated do
  begin
    if FSession.FSocket = nil then Exit;
    if not FSession.IsConnected then Exit;
    try
      LFrame := FSession.FSocket.ReadFrame;
    except
      Exit;
    end;
    if Assigned(FSession.FOnFrame) then
    begin
      try
        FSession.FOnFrame(LFrame);
      except
      end;
    end;
    if LFrame.Opcode = wsOpClose then Exit;
  end;
end;

class function TUpstreamWsOptions.Create(const AUrl: string): TUpstreamWsOptions;
begin
  Result.Url := AUrl;
  SetLength(Result.Headers, 0);
  SetLength(Result.Subprotocols, 0);
  Result.PerMessageDeflate := False;
end;

function TUpstreamWsOptions.WithHeader(const AName, AValue: string): TUpstreamWsOptions;
var
  N: Integer;
begin
  Result := Self;
  N := Length(Result.Headers);
  SetLength(Result.Headers, N + 1);
  Result.Headers[N].Name := AName;
  Result.Headers[N].Value := AValue;
end;

function TUpstreamWsOptions.WithSubprotocol(const AProtocol: string): TUpstreamWsOptions;
var
  N: Integer;
begin
  Result := Self;
  N := Length(Result.Subprotocols);
  SetLength(Result.Subprotocols, N + 1);
  Result.Subprotocols[N] := AProtocol;
end;

function TUpstreamWsOptions.WithPerMessageDeflate(const AEnable: Boolean): TUpstreamWsOptions;
begin
  Result := Self;
  Result.PerMessageDeflate := AEnable;
end;

function TUpstreamWsOptions.ToWebSocketOptions: TWebSocketOptions;
var
  I: Integer;
  LJoined: string;
begin
  Result := TWebSocketOptions.Default;
  Result.EnablePermessageDeflate := PerMessageDeflate;
  for I := 0 to High(Headers) do
    Result := Result.WithHeader(Headers[I].Name, Headers[I].Value);
  if Length(Subprotocols) > 0 then
  begin
    LJoined := Subprotocols[0];
    for I := 1 to High(Subprotocols) do
      LJoined := LJoined + ', ' + Subprotocols[I];
    Result := Result.WithHeader('Sec-WebSocket-Protocol', LJoined);
  end;
end;

class function TUpstreamWsReconnectPolicy.Default: TUpstreamWsReconnectPolicy;
begin
  Result.MaxRetries := 3;
  Result.BaseMs := 500;
  Result.MaxMs := 8000;
end;

function TUpstreamWsReconnectPolicy.ShouldRetry(const AAttempt: Integer): Boolean;
begin
  Result := (AAttempt >= 1) and (AAttempt <= MaxRetries);
end;

function TUpstreamWsReconnectPolicy.DelayMs(const AAttempt: Integer): Integer;
var
  LDelay: Int64;
  I: Integer;
begin
  if AAttempt < 1 then Exit(0);
  if not ShouldRetry(AAttempt) then Exit(MaxMs);
  LDelay := BaseMs;
  for I := 2 to AAttempt do
  begin
    LDelay := LDelay * 2;
    if LDelay > MaxMs then
    begin
      LDelay := MaxMs;
      Break;
    end;
  end;
  if LDelay > MaxMs then LDelay := MaxMs;
  if LDelay < 0 then LDelay := MaxMs;
  Result := Integer(LDelay);
end;

constructor TUpstreamWsSession.Create(const AOptions: TUpstreamWsOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FPolicy := TUpstreamWsReconnectPolicy.Default;
  FSocket := nil;
  FReader := nil;
end;

constructor TUpstreamWsSession.Create(const AOptions: TUpstreamWsOptions;
  const APolicy: TUpstreamWsReconnectPolicy);
begin
  inherited Create;
  FOptions := AOptions;
  FPolicy := APolicy;
  FSocket := nil;
  FReader := nil;
end;

destructor TUpstreamWsSession.Destroy;
begin
  Close;
  inherited Destroy;
end;

function TUpstreamWsSession.GetIsConnected: Boolean;
begin
  Result := (FSocket <> nil) and FSocket.IsOpen;
end;

function TUpstreamWsSession.BuildWebSocketOptions: TWebSocketOptions;
begin
  Result := FOptions.ToWebSocketOptions;
end;

function TUpstreamWsSession.ReconnectDelayMs(const AAttempt: Integer): Integer;
begin
  Result := FPolicy.DelayMs(AAttempt);
end;

function TUpstreamWsSession.ShouldRetry(const AAttempt: Integer): Boolean;
begin
  Result := FPolicy.ShouldRetry(AAttempt);
end;

procedure TUpstreamWsSession.StartReader;
begin
  if FReader <> nil then Exit;
  if not Assigned(FOnFrame) then Exit;
  if not IsConnected then Exit;
  FReader := TUpstreamWsReaderThread.Create(Self);
  FReader.Start;
end;

procedure TUpstreamWsSession.StopReader;
var
  LReader: TWorkerThread;
begin
  LReader := FReader;
  FReader := nil;
  if LReader = nil then Exit;
  LReader.Terminate;
  // Close socket to unblock ReadFrame if blocked
  if FSocket <> nil then
  begin
    try
      FSocket.Close(1000, '');
    except
    end;
  end;
  LReader.WaitFor;
  LReader.Free;
end;

procedure TUpstreamWsSession.Connect;
var
  LWsOpts: TWebSocketOptions;
begin
  if IsConnected then Exit;
  if FOptions.Url = '' then
    raise EArgumentError.Create('upstream websocket url must not be empty');
  LWsOpts := BuildWebSocketOptions;
  StopReader;
  FSocket := ConnectWebSocket(FOptions.Url, LWsOpts);
  if Assigned(FOnFrame) then
    StartReader;
end;

procedure TUpstreamWsSession.Close;
var
  LSocket: IWebSocket;
begin
  StopReader;
  LSocket := FSocket;
  FSocket := nil;
  if LSocket <> nil then
  begin
    try
      if LSocket.IsOpen then
        LSocket.Close(1000, '');
    except
    end;
  end;
end;

procedure TUpstreamWsSession.SendText(const AText: string);
begin
  if not IsConnected then
    raise EHttpError.Create(hekProtocol, 'upstream websocket not connected');
  FSocket.WriteText(AText);
end;

procedure TUpstreamWsSession.SendBinary(const AData: TBytes);
begin
  if not IsConnected then
    raise EHttpError.Create(hekProtocol, 'upstream websocket not connected');
  FSocket.WriteBinary(AData);
end;

end.
