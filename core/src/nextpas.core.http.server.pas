unit nextpas.core.http.server;
{**
 * @desc HTTP server facade built on the shared TCP server foundation.
 *       Keeps the public HTTP contract stable while runtime ownership lives
 *       under nextpas.core.net.server.
 *}

{$I nextpas.core.settings.inc}

interface

uses nextpas.core.net.base, nextpas.core.net.intf, nextpas.core.net.server, nextpas.core.http.base, nextpas.core.http.intf;

type
  THttpServerOptions = nextpas.core.http.base.THttpServerOptions;

  THttpServer = class(TInterfacedObject, IHttpServer)
  private
    FHandler: IHttpHandler;
    FOptions: THttpServerOptions;
    FTransport: IHttpServerTransport;
    FTcpServer: ITcpServer;
    FConnHandler: ITcpServerHandler;
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
  nextpas.core.base.utils,
  nextpas.core.errors,
  nextpas.core.http.impl.registry,
  nextpas.core.http.middleware.requestarena;

type
  THttpConnHandler = class(TInterfacedObject, ITcpServerHandler,
    ITcpServerSessionFactory, ITcpServerSessionFactoryWithContext)
  private
    Transport: IHttpServerTransport;
    Handler: IHttpHandler;
  public
    constructor Create(const ATransport: IHttpServerTransport;
      const AHandler: IHttpHandler);
    function ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
    function NewSession(const AConn: ITcpStream): ITcpServerSession; overload;
    function NewSession(const AConn: ITcpStream;
      const AContext: ITcpServerSessionContext): ITcpServerSession; overload;
  end;

  THttpConnSession = class(TInterfacedObject, ITcpServerSession)
  private
    Transport: IHttpServerTransport;
    Handler: IHttpHandler;
    Conn: ITcpStream;
  public
    constructor Create(const ATransport: IHttpServerTransport;
      const AHandler: IHttpHandler; const AConn: ITcpStream);
    function Run: TTcpServerConnOwnership;
  end;

procedure ValidateServerOptions(const AOptions: THttpServerOptions);
begin
  if AOptions.ReadTimeout < 0 then
    raise EHttpError.Create(hekArgument, 'http server read timeout must not be negative');
  if AOptions.WriteTimeout < 0 then
    raise EHttpError.Create(hekArgument, 'http server write timeout must not be negative');
  if AOptions.IdleTimeout < 0 then
    raise EHttpError.Create(hekArgument, 'http server idle timeout must not be negative');
  if AOptions.MaxHeaderSize < 0 then
    raise EHttpError.Create(hekArgument, 'http server max header size must not be negative');
  if AOptions.MaxBodySize < 0 then
    raise EHttpError.Create(hekArgument, 'http server max body size must not be negative');
  if AOptions.ShutdownTimeout < 0 then
    raise EHttpError.Create(hekArgument, 'http server shutdown timeout must not be negative');
  if AOptions.ShutdownTimeout > High(Int64) div 1000000 then
    raise EHttpError.Create(hekArgument, 'http server shutdown timeout too large (would overflow nanoseconds)');
  if AOptions.MaxRequestsPerConnection < 0 then
    raise EHttpError.Create(hekArgument, 'http server max requests per connection must not be negative');
end;

constructor THttpConnHandler.Create(const ATransport: IHttpServerTransport;
  const AHandler: IHttpHandler);
begin
  inherited Create;
  Transport := ATransport;
  Handler := AHandler;
end;

function THttpConnHandler.ServeConn(const AConn: ITcpStream): TTcpServerConnOwnership;
begin
  Result := Transport.ServeConn(AConn, Handler);
end;

function THttpConnHandler.NewSession(
  const AConn: ITcpStream): ITcpServerSession;
var
  LFactory: IHttpServerSessionFactory;
begin
  if Supports(Transport, IHttpServerSessionFactory, LFactory) then
    Result := LFactory.NewSession(AConn, Handler)
  else
    Result := THttpConnSession.Create(Transport, Handler, AConn);
end;

function THttpConnHandler.NewSession(const AConn: ITcpStream;
  const AContext: ITcpServerSessionContext): ITcpServerSession;
var
  LContextFactory: IHttpServerSessionFactoryWithContext;
begin
  if Supports(Transport, IHttpServerSessionFactoryWithContext, LContextFactory) then
    Result := LContextFactory.NewSession(AConn, Handler, AContext)
  else
    Result := NewSession(AConn);
end;

constructor THttpConnSession.Create(const ATransport: IHttpServerTransport;
  const AHandler: IHttpHandler; const AConn: ITcpStream);
begin
  inherited Create;
  Transport := ATransport;
  Handler := AHandler;
  Conn := AConn;
end;

function THttpConnSession.Run: TTcpServerConnOwnership;
begin
  Result := Transport.ServeConn(Conn, Handler);
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
  LTcpOptions: TTcpServerOptions;
  LVersion: THttpVersion;
  LUseNativeArena: Boolean;
begin
  if AHandler = nil then
    raise EHttpError.Create(hekArgument, 'http server handler must not be nil');
  inherited Create;
  ValidateServerOptions(AOptions);
  FOptions := AOptions;
  { RequestArena wire:
    - Default H1 (10/11) / H2 transport: connection-scoped LocalArena inside
      transport (registry copies RequestArena*; no middleware double wrap).
    - Custom transport / H3 / unknown: middleware wrap at root handler. }
  LVersion := AOptions.EffectiveVersion(GetDefaultServerVersion);
  LUseNativeArena := AOptions.RequestArena and (ATransport = nil) and
    ((LVersion = hvHttp10) or (LVersion = hvHttp11) or (LVersion = hvHttp2));
  if AOptions.RequestArena and (not LUseNativeArena) then
    FHandler := HttpWithRequestArena(AHandler, AOptions.RequestArenaCapacity)
  else
    FHandler := AHandler;
  if ATransport <> nil then
    FTransport := ATransport
  else
    FTransport := ResolveServerTransport(LVersion, AOptions);
  LTcpOptions := TTcpServerOptions.Default;
  LTcpOptions.Backend := AOptions.Backend;
  LTcpOptions.ShutdownTimeoutNs := AOptions.ShutdownTimeout * Int64(1000000);
  FTcpServer := NewTcpServer(LTcpOptions);
  FConnHandler := THttpConnHandler.Create(FTransport, FHandler);
end;

destructor THttpServer.Destroy;
begin
  if (FTcpServer <> nil) and IsRunning then
    Shutdown;
  FConnHandler := nil;
  FTcpServer := nil;
  FTransport := nil;
  FHandler := nil;
  inherited;
end;

procedure THttpServer.ListenAndServe(const AAddr: string; const APort: UInt16);
begin
  if IsRunning then
    raise EInvalidOperationError.Create('http server is already running');
  FTcpServer.ListenAndServe(AAddr, APort, FConnHandler);
end;

procedure THttpServer.Shutdown;
begin
  if FTcpServer <> nil then
    FTcpServer.Shutdown;
end;

function THttpServer.LocalAddr: TNetAddress;
begin
  if FTcpServer <> nil then
    Result := FTcpServer.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function THttpServer.IsRunning: Boolean;
begin
  Result := (FTcpServer <> nil) and FTcpServer.IsRunning;
end;

{ Factory functions }

function NewHttpServer(const AHandler: IHttpHandler): IHttpServer;
begin
  { Compat/test default: THttpServerOptions.Default (RW=0). For production,
    pass THttpServerOptions.Production or explicit timeouts. }
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
