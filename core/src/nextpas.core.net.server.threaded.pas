unit nextpas.core.net.server.threaded;
{**
 * @desc Default threaded TCP server runtime.
 *       Owns listen/accept/shutdown and dispatches one connection per worker
 *       thread while protocol-specific handling stays in ITcpServerHandler.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.net.base,
  nextpas.core.net.intf,
  nextpas.core.net.server.base,
  nextpas.core.net.server.intf;

function NewTcpThreadedServer(
  const AOptions: TTcpServerOptions): ITcpServer;

implementation

uses
  SysUtils,
  nextpas.core.errors,
  nextpas.core.net.tcp,
  nextpas.core.net.server.runtime,
  nextpas.core.platform.thread;

type
  PConnContext = ^TConnContext;
  TConnContext = record
    Conn: ITcpStream;
    Handler: ITcpServerHandler;
    SessionContext: ITcpServerSessionContext;
  end;

  TTcpThreadedServer = class(TInterfacedObject, ITcpServer)
  private
    FOptions: TTcpServerOptions;
    FRunning: Boolean;
    FListener: ITcpListener;
    FWorkerHandoff: ITcpServerWorkerHandoff;
    FSessionContext: ITcpServerSessionContext;
    procedure EnsureRuntimeContext;
  public
    constructor Create(const AOptions: TTcpServerOptions);
    destructor Destroy; override;
    procedure ListenAndServe(const AAddr: string; const APort: UInt16;
      const AHandler: ITcpServerHandler);
    procedure Shutdown;
    function LocalAddr: TNetAddress;
    function IsRunning: Boolean;
end;

function ConnThreadFunc(AArg: Pointer): Pointer; cdecl;
var
  LCtx: PConnContext;
  LOwnership: TTcpServerConnOwnership;
begin
  Result := nil;
  LCtx := PConnContext(AArg);
  LOwnership := tscoServer;
  try
    LOwnership := ExecuteTcpServerConnHandler(LCtx^.Handler, LCtx^.Conn,
      LCtx^.SessionContext);
  finally
    if (LCtx^.Conn <> nil) and (LOwnership = tscoServer) then
      CloseServerOwnedTcpConn(LCtx^.Conn);
    LCtx^.Conn := nil;
    LCtx^.Handler := nil;
    LCtx^.SessionContext := nil;
    Dispose(LCtx);
  end;
end;

{ TTcpThreadedServer }

constructor TTcpThreadedServer.Create(const AOptions: TTcpServerOptions);
begin
  inherited Create;
  FOptions := AOptions;
  FRunning := False;
  FListener := nil;
end;

destructor TTcpThreadedServer.Destroy;
begin
  if FRunning then
    Shutdown;
  FSessionContext := nil;
  FWorkerHandoff := nil;
  FListener := nil;
  inherited;
end;

procedure TTcpThreadedServer.EnsureRuntimeContext;
begin
  if FWorkerHandoff = nil then
    CreateTcpServerRuntimeContext(FWorkerHandoff, FSessionContext);
end;

procedure TTcpThreadedServer.ListenAndServe(const AAddr: string;
  const APort: UInt16; const AHandler: ITcpServerHandler);
var
  LConn: ITcpStream;
  LCtx: PConnContext;
  LHandle: TPlatformThreadHandle;
  LOwnership: TTcpServerConnOwnership;
begin
  if AHandler = nil then
    raise EArgumentError.Create('tcp server handler must not be nil');
  EnsureRuntimeContext;
  try
    FListener := NetTcpListen(AAddr, APort);
    FRunning := True;
    try
      while FRunning do
      begin
        try
          LConn := FListener.Accept;
        except
          Break;
        end;
        if LConn = nil then
          Break;
        if not FRunning then
        begin
          LConn.Close;
          Break;
        end;
        New(LCtx);
        LCtx^.Conn := LConn;
        LCtx^.Handler := AHandler;
        LCtx^.SessionContext := FSessionContext;
        if platform_thread_create(LHandle, @ConnThreadFunc, LCtx) = 0 then
          platform_thread_detach(LHandle)
        else
        begin
          LOwnership := tscoServer;
          try
            LOwnership := ExecuteTcpServerConnHandler(AHandler, LConn,
              FSessionContext);
          finally
            if LOwnership = tscoServer then
              CloseServerOwnedTcpConn(LConn);
            Dispose(LCtx);
          end;
        end;
      end;
    finally
      FRunning := False;
      if FWorkerHandoff <> nil then
        FWorkerHandoff.Shutdown;
    end;
  finally
    FSessionContext := nil;
    FWorkerHandoff := nil;
    if not FRunning then
      FListener := nil;
  end;
end;

procedure TTcpThreadedServer.Shutdown;
var
  LAddr: TNetAddress;
  LWake: ITcpStream;
begin
  FRunning := False;
  if FListener <> nil then
  begin
    LAddr := FListener.LocalAddr;
    try
      LWake := NetTcpConnect(LAddr.IP, LAddr.Port);
      LWake.Close;
    except
    end;
    FListener.Close;
  end;
  if FWorkerHandoff <> nil then
    FWorkerHandoff.Shutdown;
end;

function TTcpThreadedServer.LocalAddr: TNetAddress;
begin
  if FListener <> nil then
    Result := FListener.LocalAddr
  else
    Result := TNetAddress.Any(0);
end;

function TTcpThreadedServer.IsRunning: Boolean;
begin
  Result := FRunning;
end;

function NewTcpThreadedServer(
  const AOptions: TTcpServerOptions): ITcpServer;
begin
  Result := TTcpThreadedServer.Create(AOptions);
end;

end.
