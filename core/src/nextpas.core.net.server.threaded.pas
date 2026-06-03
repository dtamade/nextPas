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
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.thread,
  nextpas.core.platform.thread;

type
  PConnContext = ^TConnContext;
  TConnContext = record
    Conn: ITcpStream;
    Handler: ITcpServerHandler;
    SessionContext: ITcpServerSessionContext;
  end;

  TTcpThreadedWorkTask = class(TInterfacedObject)
  private
    FWork: ITcpServerWork;
    FCompletion: ITcpServerWorkCompletion;
  public
    constructor Create(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion);
    procedure Run;
  end;

  TTcpThreadedWorkerHandoff = class(TInterfacedObject, ITcpServerWorkerHandoff)
  private
    FPool: IThreadPool;
    FMutex: IMutex;
    FShuttingDown: Boolean;
  public
    constructor Create;
    procedure Shutdown;
    function Submit(const AWork: ITcpServerWork;
      const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
  end;

  TTcpThreadedSessionContext = class(TInterfacedObject, ITcpServerSessionContext)
  private
    FWorkerHandoff: ITcpServerWorkerHandoff;
  public
    constructor Create(const AWorkerHandoff: ITcpServerWorkerHandoff);
    function WorkerHandoff: ITcpServerWorkerHandoff;
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

function ExecuteConnHandler(const AHandler: ITcpServerHandler;
  const AConn: ITcpStream; const AContext: ITcpServerSessionContext): TTcpServerConnOwnership;
var
  LContextFactory: ITcpServerSessionFactoryWithContext;
  LSessionFactory: ITcpServerSessionFactory;
  LSession: ITcpServerSession;
begin
  Result := tscoServer;
  try
    if Supports(AHandler, ITcpServerSessionFactoryWithContext, LContextFactory) then
    begin
      LSession := LContextFactory.NewSession(AConn, AContext);
      if LSession = nil then
        raise EArgumentError.Create('tcp server session factory returned nil');
      Result := LSession.Run;
    end
    else if Supports(AHandler, ITcpServerSessionFactory, LSessionFactory) then
    begin
      LSession := LSessionFactory.NewSession(AConn);
      if LSession = nil then
        raise EArgumentError.Create('tcp server session factory returned nil');
      Result := LSession.Run;
    end
    else
      Result := AHandler.ServeConn(AConn);
  except
    { Keep the accept loop and detached workers alive if a single connection
      handler raises. The runtime falls back to server-owned close semantics. }
    Result := tscoServer;
  end;
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
    LOwnership := ExecuteConnHandler(LCtx^.Handler, LCtx^.Conn,
      LCtx^.SessionContext);
  finally
    if (LCtx^.Conn <> nil) and (LOwnership = tscoServer) then
    begin
      LCtx^.Conn.Shutdown;
      LCtx^.Conn.Close;
    end;
    LCtx^.Conn := nil;
    LCtx^.Handler := nil;
    LCtx^.SessionContext := nil;
    Dispose(LCtx);
  end;
end;

{ TTcpThreadedWorkTask }

constructor TTcpThreadedWorkTask.Create(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion);
begin
  inherited Create;
  FWork := AWork;
  FCompletion := ACompletion;
end;

procedure TTcpThreadedWorkTask.Run;
var
  LOutcome: TTcpServerWorkOutcome;
  LOwnership: TTcpServerConnOwnership;
begin
  LOutcome := tswoCompleted;
  LOwnership := tscoServer;
  try
    LOwnership := FWork.Execute;
  except
    LOutcome := tswoFailed;
    LOwnership := tscoServer;
  end;
  try
    FCompletion.Complete(LOutcome, LOwnership);
  except
  end;
  FCompletion := nil;
  FWork := nil;
end;

{ TTcpThreadedWorkerHandoff }

constructor TTcpThreadedWorkerHandoff.Create;
begin
  inherited Create;
  FPool := ThreadPool(0);
  FMutex := nextpas.core.sync.mutex.TMutex.Create;
  FShuttingDown := False;
end;

procedure TTcpThreadedWorkerHandoff.Shutdown;
var
  LPool: IThreadPool;
begin
  FMutex.Acquire;
  try
    if FShuttingDown then
      Exit;
    FShuttingDown := True;
    LPool := FPool;
    FPool := nil;
  finally
    FMutex.Release;
  end;
  if LPool <> nil then
    LPool.Shutdown;
end;

function TTcpThreadedWorkerHandoff.Submit(const AWork: ITcpServerWork;
  const ACompletion: ITcpServerWorkCompletion): TTcpServerHandoffResult;
var
  LTask: TTcpThreadedWorkTask;
begin
  if AWork = nil then
    raise EArgumentError.Create('tcp server handoff work must not be nil');
  if ACompletion = nil then
    raise EArgumentError.Create('tcp server handoff completion must not be nil');

  FMutex.Acquire;
  try
    if FShuttingDown or (FPool = nil) then
      Exit(tshrShuttingDown);
    LTask := TTcpThreadedWorkTask.Create(AWork, ACompletion);
    try
      FPool.Submit(procedure
      begin
        try
          LTask.Run;
        finally
          LTask.Free;
        end;
      end);
    except
      LTask.Free;
      raise;
    end;
    Result := tshrAccepted;
  finally
    FMutex.Release;
  end;
end;

{ TTcpThreadedSessionContext }

constructor TTcpThreadedSessionContext.Create(
  const AWorkerHandoff: ITcpServerWorkerHandoff);
begin
  inherited Create;
  FWorkerHandoff := AWorkerHandoff;
end;

function TTcpThreadedSessionContext.WorkerHandoff: ITcpServerWorkerHandoff;
begin
  Result := FWorkerHandoff;
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
  begin
    FWorkerHandoff := TTcpThreadedWorkerHandoff.Create;
    FSessionContext := TTcpThreadedSessionContext.Create(FWorkerHandoff);
  end;
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
            LOwnership := ExecuteConnHandler(AHandler, LConn, FSessionContext);
          finally
            if LOwnership = tscoServer then
            begin
              LConn.Shutdown;
              LConn.Close;
            end;
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
