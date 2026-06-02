unit nextpas.core.http.server;
{**
 * @desc Thread-per-connection HTTP/1.1 server with keep-alive support.
 *       Loops on each connection handling multiple requests until close.
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
    IdleTimeout: Int64;   // milliseconds between requests, default 30000
    MaxHeaderSize: Int32; // bytes, default 8192
    MaxBodySize: Int64;   // bytes, default 4194304 (4MB), 0 = unlimited
    class function Default: THttpServerOptions; static;
  end;

  THttpServer = class(TInterfacedObject, IHttpServer)
  private
    FHandler: IHttpHandler;
    FOptions: THttpServerOptions;
    FTransport: IHttpServerTransport;
    FRunning: Boolean;
    FListener: ITcpListener;
  public
    constructor Create(const AHandler: IHttpHandler;
      const AOptions: THttpServerOptions); overload;
    constructor Create(const AHandler: IHttpHandler;
      const ATransport: IHttpServerTransport;
      const AOptions: THttpServerOptions); overload;
    destructor Destroy; override;
    procedure ListenAndServe(const AAddr: string; const APort: UInt16);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
  end;

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer; overload;
function NewHttpServer(const AHandler: IHttpHandler; const AOptions: THttpServerOptions): IHttpServer; overload;
function NewHttpServer(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport): IHttpServer; overload;
function NewHttpServer(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport;
  const AOptions: THttpServerOptions): IHttpServer; overload;

implementation

uses
  nextpas.core.net.tcp,
  nextpas.core.http.impl.h1,
  nextpas.core.platform.thread;

type
  PConnContext = ^TConnContext;
  TConnContext = record
    Conn: ITcpStream;
    Handler: IHttpHandler;
    Transport: IHttpServerTransport;
  end;

function ConnThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PConnContext;
begin
  Result := nil;
  LCtx := PConnContext(AArg);
  try
    LCtx^.Transport.ServeConn(LCtx^.Conn, LCtx^.Handler);
  finally
    LCtx^.Conn := nil;
    LCtx^.Handler := nil;
    LCtx^.Transport := nil;
    Dispose(LCtx);
  end;
end;

{ THttpServerOptions }

class function THttpServerOptions.Default: THttpServerOptions;
begin
  Result.ReadTimeout := 0;
  Result.WriteTimeout := 0;
  Result.IdleTimeout := 30000; { 30 seconds between requests }
  Result.MaxHeaderSize := 8192;
  Result.MaxBodySize := 4194304; { 4 MB }
end;

{ THttpServer }

constructor THttpServer.Create(const AHandler: IHttpHandler;
  const AOptions: THttpServerOptions);
begin
  Create(AHandler, nil, AOptions);
end;

constructor THttpServer.Create(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport; const AOptions: THttpServerOptions);
var
  LH1Options: TH1ServerTransportOptions;
begin
  inherited Create;
  FHandler := AHandler;
  FOptions := AOptions;
  if ATransport <> nil then
    FTransport := ATransport
  else
  begin
    LH1Options.ReadTimeout := AOptions.ReadTimeout;
    LH1Options.WriteTimeout := AOptions.WriteTimeout;
    LH1Options.IdleTimeout := AOptions.IdleTimeout;
    LH1Options.MaxHeaderSize := AOptions.MaxHeaderSize;
    LH1Options.MaxBodySize := AOptions.MaxBodySize;
    FTransport := NewH1ServerTransport(LH1Options);
  end;
  FRunning := False;
  FListener := nil;
end;

destructor THttpServer.Destroy;
begin
  if FRunning then
    Shutdown;
  FTransport := nil;
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
    LCtx^.Transport := FTransport;
    if platform_thread_create(LHandle, @ConnThreadFunc, LCtx) = 0 then
      platform_thread_detach(LHandle)
    else
    begin
      { Thread creation failed — handle inline }
      try
        FTransport.ServeConn(LConn, FHandler);
      finally
        Dispose(LCtx);
      end;
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

function NewHttpServer(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport): IHttpServer;
begin
  Result := THttpServer.Create(AHandler, ATransport, THttpServerOptions.Default);
end;

function NewHttpServer(const AHandler: IHttpHandler;
  const ATransport: IHttpServerTransport;
  const AOptions: THttpServerOptions): IHttpServer;
begin
  Result := THttpServer.Create(AHandler, ATransport, AOptions);
end;

end.
