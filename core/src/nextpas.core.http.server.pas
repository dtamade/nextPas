unit nextpas.core.http.server;
{**
 * @desc Thread-per-connection HTTP/1.1 server.
 *       No keep-alive in v1 — each connection handles one request then closes.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.http.base,
  nextpas.core.http.intf;

type
  THttpServerOptions = record
    ReadTimeout: Int64;   // milliseconds, 0 = no timeout
    WriteTimeout: Int64;  // milliseconds, 0 = no timeout
    MaxHeaderSize: Int32; // bytes, default 8192
    class function Default: THttpServerOptions; static;
  end;

  THttpServer = class(TInterfacedObject, IHttpServer)
  private
    FHandler: IHttpHandler;
    FOptions: THttpServerOptions;
    FRunning: Boolean;
    FListener: ITcpListener;
  public
    constructor Create(const AHandler: IHttpHandler; const AOptions: THttpServerOptions);
    destructor Destroy; override;
    procedure ListenAndServe(const AAddr: string; const APort: UInt16);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer; overload;
function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer; overload;

implementation

uses
  nextpas.core.errors,
  nextpas.core.io.intf,
  nextpas.core.net.tcp,
  nextpas.core.time.base,
  nextpas.core.time.deadline,
  nextpas.core.text.conv,
  nextpas.core.http.headers,
  nextpas.core.http.message,
  nextpas.core.http.impl.h1.parser,
  nextpas.core.http.impl.h1.writer,
  nextpas.core.platform.thread;

type
  PConnContext = ^TConnContext;
  TConnContext = record
    Conn: ITcpStream;
    Handler: IHttpHandler;
    Options: THttpServerOptions;
  end;

procedure WriteErrorResponse(const AConn: ITcpStream; const AStatus: THttpStatus);
var
  LW: IHttpResponseWriter;
  LBody: string;
begin
  try
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    LBody := HttpStatusText(AStatus);
    LW.GetHeaders.Set_('content-length', IntToStr(Int64(Length(LBody))));
    LW.GetHeaders.Set_('connection', 'close');
    LW.WriteHeader(AStatus);
    if Length(LBody) > 0 then
      LW.Write(LBody[1], SizeUInt(Length(LBody)));
  except
    { Swallow write errors during error response }
  end;
end;

procedure HandleConnection(const AConn: ITcpStream; const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions);
var
  LParser: IH1Parser;
  LBuf: array[0..4095] of Byte;
  LN: SizeUInt;
  LUrl: TUrl;
  LReq: IHttpRequest;
  LW: IHttpResponseWriter;
begin
  try
    { Set deadlines }
    if AOptions.ReadTimeout > 0 then
      AConn.SetReadDeadline(TDeadline.After(TDuration.FromMilliseconds(AOptions.ReadTimeout)));
    if AOptions.WriteTimeout > 0 then
      AConn.SetWriteDeadline(TDeadline.After(TDuration.FromMilliseconds(AOptions.WriteTimeout)));

    { Parse request }
    LParser := NewH1RequestParser;
    repeat
      LN := AConn.Read(LBuf[0], 4096);
      if LN = 0 then Exit; { EOF — client disconnected }
      LParser.Execute(@LBuf[0], LN);
    until LParser.IsComplete or LParser.HasError;

    if LParser.HasError then
    begin
      WriteErrorResponse(AConn, HTTP_STATUS_BAD_REQUEST);
      Exit;
    end;

    { Build request }
    LUrl := TUrl.Parse(LParser.GetUrl);
    LReq := THttpRequest.Create(LParser.GetMethod, LUrl, LParser.GetHttpVersion,
      LParser.GetHeaders, nil, 0);

    { Dispatch to handler }
    LW := TH1ResponseWriter.Create(AConn as IWriter);
    AHandler.ServeHTTP(LReq, LW);
  except
    on E: Exception do
      WriteErrorResponse(AConn, HTTP_STATUS_INTERNAL_SERVER_ERROR);
  end;
end;

function ConnThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PConnContext;
  LConn: ITcpStream;
  LHandler: IHttpHandler;
  LOptions: THttpServerOptions;
begin
  Result := nil;
  LCtx := PConnContext(AArg);
  LConn := LCtx^.Conn;
  LHandler := LCtx^.Handler;
  LOptions := LCtx^.Options;
  Dispose(LCtx);
  try
    HandleConnection(LConn, LHandler, LOptions);
  finally
    LConn.Shutdown;
    LConn.Close;
    LConn := nil;
    LHandler := nil;
  end;
end;

{ THttpServerOptions }

class function THttpServerOptions.Default: THttpServerOptions;
begin
  Result.ReadTimeout := 0;
  Result.WriteTimeout := 0;
  Result.MaxHeaderSize := 8192;
end;

{ THttpServer }

constructor THttpServer.Create(const AHandler: IHttpHandler; const AOptions: THttpServerOptions);
begin
  inherited Create;
  FHandler := AHandler;
  FOptions := AOptions;
  FRunning := False;
  FListener := nil;
end;

destructor THttpServer.Destroy;
begin
  if FRunning then
    Shutdown;
  FHandler := nil;
  FListener := nil;
  inherited;
end;

procedure THttpServer.ListenAndServe(const AAddr: string; const APort: UInt16);
var
  LConn: ITcpStream;
  LCtx: PConnContext;
  LHandle: TPlatformThreadHandle;
begin
  FListener := NetTcpListen(AAddr, APort);
  FRunning := True;
  while FRunning do
  begin
    try
      LConn := FListener.Accept;
    except
      { Accept fails when listener is closed during Shutdown }
      Break;
    end;
    if (LConn = nil) or (not FRunning) then
      Break;
    New(LCtx);
    LCtx^.Conn := LConn;
    LCtx^.Handler := FHandler;
    LCtx^.Options := FOptions;
    if platform_thread_create(LHandle, @ConnThreadFunc, LCtx) = 0 then
      platform_thread_detach(LHandle)
    else
    begin
      { Thread creation failed — handle inline }
      HandleConnection(LConn, FHandler, FOptions);
      LConn.Close;
      Dispose(LCtx);
    end;
  end;
end;

procedure THttpServer.Shutdown;
var
  LAddr: TNetAddress;
  LWake: ITcpStream;
begin
  FRunning := False;
  if FListener <> nil then
  begin
    { Connect to self to unblock Accept() — closing the listener socket
      does not reliably unblock accept() on Linux }
    LAddr := FListener.LocalAddr;
    try
      LWake := NetTcpConnect(LAddr.IP, LAddr.Port);
      LWake.Close;
    except
      { Ignore — listener may already be closed }
    end;
    FListener.Close;
  end;
end;

function THttpServer.LocalAddr: TNetAddress;
begin
  if FListener <> nil then
    Result := FListener.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function THttpServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

{ Factory functions }

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer;
begin
  Result := THttpServer.Create(AHandler, THttpServerOptions.Default);
end;

function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := THttpServer.Create(AHandler, AOptions);
end;

end.
